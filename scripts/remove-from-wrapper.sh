#!/bin/bash
# Undoes add-to-wrapper.sh for one game app.
#   curl -fsSL https://raw.githubusercontent.com/snipstxd/mac-wine-discord-rpc/main/scripts/remove-from-wrapper.sh | bash -s -- "/path/to/Game.app"
set -euo pipefail

say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }
PB=/usr/libexec/PlistBuddy

APP="${1:-}"
APP="${APP%/}"
[ -d "$APP" ] || die "Tell me which game app to restore, e.g.:  remove-from-wrapper.sh \"$HOME/Applications/My Game.app\""

PLIST=""
for p in "$APP/Contents/Info.plist" "$APP/Contents/Resources/Info.plist"; do
    if [ -f "$p" ] && $PB -c "Print :'Program Name and Path'" "$p" >/dev/null 2>&1; then PLIST="$p"; break; fi
done
[ -n "$PLIST" ] || die "This doesn't look like a Wineskin / Porting Kit app."

DRIVE_C=""
for d in "$APP/Contents/SharedSupport/prefix/drive_c" "$APP/Contents/Resources/drive_c" "$APP/Contents/drive_c"; do
    if [ -d "$d" ]; then DRIVE_C="$d"; break; fi
done
[ -n "$DRIVE_C" ] || die "Could not find the game's C: drive inside the app."
[ -f "$DRIVE_C/discord-rpc-original.txt" ] || die "This app was not set up with add-to-wrapper.sh (nothing to undo)."

PROG="$(sed -n 1p "$DRIVE_C/discord-rpc-original.txt")"
FLAGS="$(sed -n 2p "$DRIVE_C/discord-rpc-original.txt")"
$PB -c "Set :'Program Name and Path' \"$PROG\"" "$PLIST"
$PB -c "Set :'Program Flags' \"$FLAGS\"" "$PLIST" 2>/dev/null || true
rm -f "$DRIVE_C/discord-rpc-launch.bat" "$DRIVE_C/discord-rpc-original.txt" "$DRIVE_C/pipebridge.exe" "$PLIST.before-discord-rpc"

say "Restored \"$(basename "$APP" .app)\" to how it was before."
