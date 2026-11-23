#!/bin/bash
# Adds Discord Rich Presence to a Wineskin / Porting Kit game app.
#   curl -fsSL https://raw.githubusercontent.com/snipstxd/mac-wine-discord-rpc/main/scripts/add-to-wrapper.sh | bash -s -- "/path/to/Game.app"
#
# What it does:
#   1. Copies pipebridge.exe into the game's C: drive.
#   2. Creates C:\discord-rpc-launch.bat, which starts pipebridge.exe and then the game.
#   3. Points the app at that .bat file (your original setting is saved so it can be undone).
set -euo pipefail

DIR="$HOME/Library/Application Support/mac-wine-discord-rpc"
BAT_NAME="discord-rpc-launch.bat"
SAVE_NAME="discord-rpc-original.txt"

say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }
PB=/usr/libexec/PlistBuddy

APP="${1:-}"
APP="${APP%/}"
[ -n "$APP" ] || die "Tell me which game app to change, e.g.:  add-to-wrapper.sh \"$HOME/Applications/My Game.app\""
[ -d "$APP" ] || die "\"$APP\" does not exist."
[ -f "$DIR/pipebridge.exe" ] || die "Run the installer first (Step 1 in the README)."

# Find the Wineskin settings file and the game's C: drive.
PLIST=""
for p in "$APP/Contents/Info.plist" "$APP/Contents/Resources/Info.plist"; do
    if [ -f "$p" ] && $PB -c "Print :'Program Name and Path'" "$p" >/dev/null 2>&1; then PLIST="$p"; break; fi
done
[ -n "$PLIST" ] || die "This doesn't look like a Wineskin / Porting Kit app (no 'Program Name and Path' setting found)."

DRIVE_C=""
for d in "$APP/Contents/SharedSupport/prefix/drive_c" "$APP/Contents/Resources/drive_c" "$APP/Contents/drive_c"; do
    if [ -d "$d" ]; then DRIVE_C="$d"; break; fi
done
[ -n "$DRIVE_C" ] || die "Could not find the game's C: drive inside the app."

if pgrep -f "$APP/Contents/.*wineserver" >/dev/null 2>&1; then
    die "The game is running. Quit it first, then run this again."
fi

PROG="$($PB -c "Print :'Program Name and Path'" "$PLIST")"
FLAGS="$($PB -c "Print :'Program Flags'" "$PLIST" 2>/dev/null || true)"

cp "$DIR/pipebridge.exe" "$DRIVE_C/pipebridge.exe"

ALREADY=0
if [ "$PROG" = "/$BAT_NAME" ]; then
    # Already set up: rebuild the .bat from the saved original settings.
    [ -f "$DRIVE_C/$SAVE_NAME" ] || die "This app points at $BAT_NAME but the saved original settings are missing."
    PROG="$(sed -n 1p "$DRIVE_C/$SAVE_NAME")"
    FLAGS="$(sed -n 2p "$DRIVE_C/$SAVE_NAME")"
    ALREADY=1
else
    # Save the original settings so remove-from-wrapper.sh can restore them.
    printf '%s\n%s\n' "$PROG" "$FLAGS" > "$DRIVE_C/$SAVE_NAME"
fi

# Wineskin paths are relative to C:\ and use forward slashes.
WINPATH="C:$(printf '%s' "$PROG" | tr '/' '\\')"
WINDIR="${WINPATH%\\*}"
[ -n "$WINDIR" ] && [ "$WINDIR" != "C:" ] || WINDIR='C:\'

{
    printf '@echo off\r\n'
    printf 'rem Made by mac-wine-discord-rpc. Starts the Discord bridge, then the game.\r\n'
    printf 'start "" /b "C:\\pipebridge.exe"\r\n'
    case "$(printf '%s' "$PROG" | tr '[:upper:]' '[:lower:]')" in
        *.bat|*.cmd) printf 'call "%s" %s\r\n' "$WINPATH" "$FLAGS" ;;
        *)           printf 'cd /d "%s"\r\nstart "" /wait "%s" %s\r\n' "$WINDIR" "$WINPATH" "$FLAGS" ;;
    esac
    printf 'rem The game has closed - stop the bridge so Wine can shut down.\r\n'
    printf 'taskkill /f /im pipebridge.exe >nul 2>&1\r\n'
} > "$DRIVE_C/$BAT_NAME"

if [ "$ALREADY" = 1 ]; then
    say "Already set up - updated pipebridge.exe and the launch file."
    exit 0
fi

cp "$PLIST" "$PLIST.before-discord-rpc"
$PB -c "Set :'Program Name and Path' /$BAT_NAME" "$PLIST"
$PB -c "Set :'Program Flags' \"\"" "$PLIST" 2>/dev/null || true

say "Done! Launch \"$(basename "$APP" .app)\" like normal - with the Discord app open - and your status should appear."
