# create personal bin
mkdir -p "$HOME/.local/bin"

# build
swiftc -O MRUTabBridge.swift -o "$HOME/.local/bin/MRUTabBridge"
codesign --force --deep --sign - "$HOME/.local/bin/MRUTabBridge"

# create launch agents folder
mkdir -p "$HOME/Library/LaunchAgents"

# remove previous install
killall -9 MRUTabBridge 2>/dev/null
launchctl bootout gui/$(id -u) "$HOME/Library/LaunchAgents/com.local.mrutabbridge.plist" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.local.mrutabbridge.plist"

# add mru bridge
cat <<EOF > "$HOME/Library/LaunchAgents/com.local.mrutabbridge.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local.mrutabbridge</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/.local/bin/MRUTabBridge</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/mrutabbridge.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/mrutabbridge.err</string>
</dict>
</plist>
EOF

# add to startup
launchctl load "$HOME/Library/LaunchAgents/com.local.mrutabbridge.plist"