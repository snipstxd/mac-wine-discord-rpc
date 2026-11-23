#!/bin/bash
# Installs the Discord relay as a background helper that starts when you log in.
#   curl -fsSL https://raw.githubusercontent.com/snipstxd/mac-wine-discord-rpc/main/scripts/install.sh | bash
set -euo pipefail

REPO="snipstxd/mac-wine-discord-rpc"
DIR="$HOME/Library/Application Support/mac-wine-discord-rpc"
LABEL="com.github.snipstxd.mac-wine-discord-rpc"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/mac-wine-discord-rpc.log"

say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || die "This only works on macOS."

mkdir -p "$DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

# Use files from a local copy of the repo if we're running from one,
# otherwise download the latest release.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [ -n "$HERE" ] && [ -f "$HERE/../dist/discord-relay" ] && [ -f "$HERE/../dist/pipebridge.exe" ]; then
    say "Using files from this folder"
    cp "$HERE/../dist/discord-relay" "$HERE/../dist/pipebridge.exe" "$DIR/"
else
    say "Downloading the latest release"
    for f in discord-relay pipebridge.exe; do
        curl -fsSL "https://github.com/$REPO/releases/latest/download/$f" -o "$DIR/$f" \
            || die "Could not download $f. Check your internet connection."
    done
fi
chmod +x "$DIR/discord-relay"
xattr -d com.apple.quarantine "$DIR/discord-relay" 2>/dev/null || true

say "Setting up the background helper"
cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$DIR/discord-relay</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
    <key>StandardOutPath</key>
    <string>$LOG</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT"
sleep 1

if launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null | grep -q "state = running"; then
    say "Done! The relay is running and will start automatically every time you log in."
else
    die "The relay did not start. Look at $LOG for details."
fi
echo
echo "Next step: add the bridge to a game. See \"Step 2\" in the README:"
echo "  https://github.com/$REPO#step-2-add-the-bridge-to-a-game"
