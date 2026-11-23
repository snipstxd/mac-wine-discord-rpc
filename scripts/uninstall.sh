#!/bin/bash
# Stops and removes the background relay.
#   curl -fsSL https://raw.githubusercontent.com/snipstxd/mac-wine-discord-rpc/main/scripts/uninstall.sh | bash
set -uo pipefail
LABEL="com.github.snipstxd.mac-wine-discord-rpc"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist" "$HOME/Library/Logs/mac-wine-discord-rpc.log"
rm -rf "$HOME/Library/Application Support/mac-wine-discord-rpc"
printf '\033[1;35m==>\033[0m %s\n' "Relay removed. (Games you added keep pipebridge.exe until you run remove-from-wrapper.sh on them.)"
