import Cocoa
import CoreGraphics

let allowedBundleIDs: Set<String> = [
    "org.chromium.Chromium",
    "com.google.Chrome",
    "org.ungoogled-software.ungoogled-chromium"
]

func sendKey(virtualKey: CGKeyCode) {
    let source = CGEventSource(stateID: .hidSystemState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
    keyDown?.flags = [.maskCommand, .maskShift]
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
    keyUp?.flags = [.maskCommand, .maskShift]

    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
}

var globalEventTap: CFMachPort?
var isCurrentlyCycling = false

func eventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = globalEventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // 48 = Tab
        if keyCode == 48 && flags.contains(.maskControl) {
            if let activeApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               allowedBundleIDs.contains(activeApp) {
                isCurrentlyCycling = true
                DispatchQueue.main.async {
                    sendKey(virtualKey: 40) // Keycode 40 = 'K' (mru-step)
                }
                return nil // Suppress default browser tab cycling
            }
        }
    }

    if type == .flagsChanged {
        let flags = event.flags
        // If Control is released while cycling, commit tab selection
        if isCurrentlyCycling && !flags.contains(.maskControl) {
            isCurrentlyCycling = false
            DispatchQueue.main.async {
                sendKey(virtualKey: 32) // Keycode 32 = 'U' (mru-commit)
            }
        }
    }

    return Unmanaged.passUnretained(event)
}

let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(options) {
    NSLog("Accessibility permission required: System Settings -> Privacy & Security -> Accessibility.")
}

let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
guard let eventTap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: eventCallback,
    userInfo: nil
) else {
    NSLog("Failed to create CGEventTap. Check Accessibility permissions.")
    exit(1)
}

globalEventTap = eventTap

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)

NSLog("MRUTabBridge started successfully.")
CFRunLoopRun()