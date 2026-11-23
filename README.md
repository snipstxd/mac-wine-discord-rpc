# mac-wine-discord-rpc

**Discord Rich Presence for Windows games running on a Mac through Wine** (Porting Kit, Wineskin, CrossOver, plain Wine).

Normally when you play a Windows game on a Mac, Discord has no idea you're playing it. With this installed, your Discord profile shows the game's full Rich Presence, exactly like on Windows: the game name, what you're doing in it, how long you've been playing, and so on.

```
 ┌─────────── Wine ───────────┐        ┌──────────── your Mac ────────────┐
 │  Game  ──►  pipebridge.exe │ ─────► │  discord-relay  ──►  Discord app │
 └────────────────────────────┘ local  └──────────────────────────────────┘
                              connection
```

- Works on **Apple Silicon (M1/M2/M3/M4)** and **Intel** Macs.
- Works with **old Wine versions** too. Other bridges need Wine 11.5+ on Apple Silicon. This one doesn't.
- Nothing leaves your computer. The connection is local only (`127.0.0.1`).

---

## Before you start

You need:

1. **A Mac** with the **Discord app** installed (the normal Mac app from [discord.com](https://discord.com/download)). Using Discord in a browser doesn't work.
2. **A Windows game** that already runs on your Mac through **Porting Kit**, **Wineskin**, **CrossOver** or **Wine**.
3. **The game must support Discord Rich Presence on Windows.** If it doesn't show anything on a Windows PC either, it won't here.

You'll type a few commands into **Terminal**. You don't need to understand them. Just copy and paste.

> **How to open Terminal:** press **⌘ Command + Space**, type **Terminal**, and press **Return**. A window with text appears. That's it.
>
> **How to paste a command:** click the copy button on the right side of the grey box below, click inside the Terminal window, press **⌘ Command + V**, then press **Return**.

---

## Step 1: Install the relay (one time only)

Paste this into Terminal and press **Return**:

```bash
curl -fsSL https://raw.githubusercontent.com/snipstxd/mac-wine-discord-rpc/main/scripts/install.sh | bash
```

You should see:

```
==> Done! The relay is running and will start automatically every time you log in.
```

This installs a tiny background helper. It uses almost no memory or battery, and it starts by itself whenever you log in, so you never have to think about it again.

> **"Background item added" notification?** That's macOS telling you about the helper you just installed. That's expected.

---

## Step 2: Add the bridge to a game

### Porting Kit or Wineskin games (most people)

Porting Kit games are apps called something like `My Game.app`. You can usually find them in the **Applications** folder inside your home folder (in Finder: **Go → Home → Applications**).

1. **Quit the game** if it's open.
2. Copy this command, paste it into Terminal, **but don't press Return yet**. Note the space at the end:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/snipstxd/mac-wine-discord-rpc/main/scripts/add-to-wrapper.sh | bash -s -- 
   ```

3. Open Finder and **drag your game's app onto the Terminal window**. Its location gets typed in for you, and the line will end with something like `'/Users/you/Applications/My Game.app'`.
4. Now press **Return**. You should see:

   ```
   ==> Done! Launch "My Game" like normal - with the Discord app open - and your status should appear.
   ```

Repeat step 2 for every game you want Rich Presence for.

<details>
<summary><b>What did that just change?</b></summary>

Inside the game app it:

- copied `pipebridge.exe` to the game's `C:\` drive,
- created `C:\discord-rpc-launch.bat`, which starts `pipebridge.exe`, starts your game, and stops the bridge when you quit,
- pointed the app at that `.bat` file. Your original setting is saved, and a backup of the settings file is kept as `Info.plist.before-discord-rpc`.

It can all be undone. See [Uninstalling](#uninstalling).
</details>

### CrossOver, Whisky, Kegworks or plain Wine

These don't use the automatic script. You just need `pipebridge.exe` running **in the same bottle/prefix, before the game starts**.

1. Get `pipebridge.exe` by running this in Terminal. It opens the folder that contains it:

   ```bash
   open ~/Library/Application\ Support/mac-wine-discord-rpc
   ```

2. Run it inside the game's bottle:
   - **CrossOver:** select the game's bottle, click **Run Command…**, browse to `pipebridge.exe`, and click **Run**. Then start your game.
   - **Plain Wine:** `WINEPREFIX=/path/to/prefix wine ~/Library/Application\ Support/mac-wine-discord-rpc/pipebridge.exe &` and then start your game in the same prefix.

You need to run it each time you play, before the game. It has no window. It just runs quietly in the background.

---

## Step 3: Play

1. Open the **Discord** app on your Mac and make sure you're logged in.
2. Start your game like you normally would.
3. Look at your Discord profile. Your game's Rich Presence should appear once the game reaches its menu, which can take 1-2 minutes while it loads. Be patient on the first launch.

Also check that Discord is allowed to show it: **Discord → User Settings → Activity Privacy → Share your detected activities with others** must be **on**.

---

## Troubleshooting

**Nothing shows on my profile.**

1. Is the Discord **app** open (not the website)? It must be open **before** you start the game.
2. Did you run [Step 2](#step-2-add-the-bridge-to-a-game) for this game, while the game was closed?
3. Does the game support Rich Presence on Windows? Not every game does.
4. Check the relay's log. Paste this into Terminal:

   ```bash
   tail ~/Library/Logs/mac-wine-discord-rpc.log
   ```

   | What the log says | What it means |
   |---|---|
   | `listening on 127.0.0.1:6473` only | The relay works, but the game never connected. Re-run Step 2, or the game doesn't use Rich Presence. |
   | `game connected, bridging to …` | Everything is connected. If nothing shows, check Discord's **Activity Privacy** setting. |
   | `Discord socket not found` | The Discord app isn't open. Open it and restart the game. |
   | `port 6473 is busy` | Another copy is already running. Restart your Mac. |

**"This doesn't look like a Wineskin / Porting Kit app".** The app you dragged in isn't a Wineskin wrapper. If it's CrossOver or Whisky, follow the [CrossOver/Wine instructions](#crossover-whisky-kegworks-or-plain-wine).

**"The game is running. Quit it first".** Quit the game completely and try again.

**Porting Kit updated/reinstalled my game and it stopped working.** Run Step 2 again for that game.

---

## Updating

Run the Step 1 command again. To give a game the new `pipebridge.exe`, run Step 2 on it again too.

## Uninstalling

**Remove it from one game.** Paste the command, drag the game's app onto Terminal, then press Return:

```bash
curl -fsSL https://raw.githubusercontent.com/snipstxd/mac-wine-discord-rpc/main/scripts/remove-from-wrapper.sh | bash -s -- 
```

**Remove the relay completely:**

```bash
curl -fsSL https://raw.githubusercontent.com/snipstxd/mac-wine-discord-rpc/main/scripts/uninstall.sh | bash
```

---

## How it works (for the curious)

Windows games talk to Discord through a Windows *named pipe* called `\\.\pipe\discord-ipc-0`. Mac Discord listens on a Unix socket (`$TMPDIR/discord-ipc-0`) instead. Wine can't connect the two by itself.

Other bridges ([wine-discord-ipc-bridge](https://github.com/0e4ef622/wine-discord-ipc-bridge), [rpc-bridge](https://github.com/EnderIce2/rpc-bridge)) connect to that Unix socket directly from inside Wine. That needs either Linux-only system calls or the `AF_UNIX` support in newer Wine (11.5+). Many Mac Wine builds, including Porting Kit's, don't have it, especially on Apple Silicon.

This project avoids the problem by using plain TCP, which every Wine version supports:

1. **`pipebridge.exe`** (Windows, runs in Wine) creates `\\.\pipe\discord-ipc-0`. When the game connects, it opens a TCP connection to `127.0.0.1:6473` and copies data both ways.
2. **`discord-relay`** (native macOS, universal binary) listens on `127.0.0.1:6473`, opens Discord's Unix socket for each connection, and copies data both ways.

Both are short, readable C programs in [`src/`](src).

## Building from source

You need Xcode Command Line Tools (`xcode-select --install`) and [Zig](https://ziglang.org) (`brew install zig`) to cross-compile the Windows part.

```bash
git clone https://github.com/snipstxd/mac-wine-discord-rpc.git
cd mac-wine-discord-rpc
./build.sh                 # builds dist/discord-relay and dist/pipebridge.exe
./scripts/install.sh       # installs using your local build
```

## License

[MIT](LICENSE)
