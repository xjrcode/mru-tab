const windowHistory = {};
const session = {};

// Clean up tabs that are no longer open
async function cleanHistory(windowId) {
  const tabs = await chrome.tabs.query({ windowId });
  const validIds = new Set(tabs.map(t => t.id));
  windowHistory[windowId] = (windowHistory[windowId] || []).filter(id => validIds.has(id));
  return windowHistory[windowId];
}

// Track tab activation when not cycling through MRU
chrome.tabs.onActivated.addListener(({ tabId, windowId }) => {
  if (session[windowId]?.isCycling) return;

  if (!windowHistory[windowId]) windowHistory[windowId] = [];
  windowHistory[windowId] = windowHistory[windowId].filter(id => id !== tabId);
  windowHistory[windowId].unshift(tabId);
});

chrome.tabs.onRemoved.addListener((tabId, { windowId }) => {
  if (windowHistory[windowId]) {
    windowHistory[windowId] = windowHistory[windowId].filter(id => id !== tabId);
  }
});

chrome.commands.onCommand.addListener(async (command) => {
  const [currentTab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!currentTab) return;
  const winId = currentTab.windowId;

  if (!session[winId]) session[winId] = { isCycling: false, index: 0 };
  const history = await cleanHistory(winId);

  if (command === "mru-step") {
    if (history.length < 2) return;

    if (!session[winId].isCycling) {
      session[winId].isCycling = true;
      session[winId].index = 1; // First step jumps to the previous tab
    } else {
      session[winId].index = (session[winId].index + 1) % history.length;
    }

    const targetTabId = history[session[winId].index];
    if (targetTabId) {
      await chrome.tabs.update(targetTabId, { active: true });
    }
  } else if (command === "mru-commit") {
    if (session[winId].isCycling) {
      const chosenTabId = history[session[winId].index];
      session[winId].isCycling = false;
      session[winId].index = 0;

      // Bring selected tab to the top of the stack
      if (chosenTabId) {
        windowHistory[winId] = history.filter(id => id !== chosenTabId);
        windowHistory[winId].unshift(chosenTabId);
      }
    }
  }
});