#!/bin/bash
# Builds both programs into dist/.
#   discord-relay   - macOS universal binary (Apple Silicon + Intel), needs Xcode Command Line Tools
#   pipebridge.exe  - Windows x64, cross-compiled with Zig (brew install zig)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist

clang -O2 -Wall -arch arm64 -arch x86_64 -o dist/discord-relay src/discord-relay.c
zig cc -target x86_64-windows-gnu -O2 -Wl,--subsystem,windows \
    -o dist/pipebridge.exe src/pipebridge.c -lws2_32
rm -f dist/*.pdb

echo "Built:"
ls -la dist
