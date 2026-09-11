# EdgeScroll (AutoHotkey v2)

Lightweight background app for Windows that sends **WASD** keypresses when the
mouse cursor touches the extreme edge of the **primary monitor** — replicating
"edge scrolling" from RTS/MOBA games, built as an accessibility option for
players who can't comfortably use WASD.

## Run it

**Option A — prebuilt EXE:** grab `EdgeScroll.exe` from the
[Releases](../../releases) page and run it. No AutoHotkey install needed.

**Option B — from source:**
1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Double-click `EdgeScroll.ahk`. It lives in the tray.
3. (Optional) Put a shortcut in `shell:startup` to autostart with Windows.

### Building the EXE yourself

Push a `v*` tag (or run the workflow manually from the Actions tab) and
GitHub Actions compiles `EdgeScroll.exe` and attaches it to the release.
Locally, with AutoHotkey v2 installed:

```
Ahk2Exe /in EdgeScroll.ahk /out EdgeScroll.exe /base AutoHotkey64.exe
```

## How it works

- A 10 ms timer polls the cursor position (negligible CPU).
- Touching the **leftmost / rightmost / top / bottom pixel** of the primary
  monitor holds `A` / `D` / `W` / `S` down; moving the cursor away releases it.
- Keys are sent with scancode-based `keybd_event` injection, which most games
  accept (unlike `Send`-mode synthetic keys in some engines).

## Tray menu

- **Enable/Disable** — toggles detection (default tray action).
- **Game Mode** — same injection path today; the toggle exists so elevated
  games can be supported by simply running the script *as Administrator* when
  playing. If a game ignores input, restart EdgeScroll elevated.
- **Settings...** — opens a window with the trigger zone (pixels from the
  edge), poll/repeat intervals, the edge→key assignments, Start-with-Windows,
  and the focus-process picker.
- **Focus process** — only trigger while a chosen program (e.g. `game.exe`)
  is the foreground window.
- **Exit** — releases all held keys and quits.

Double-left-clicking the tray icon toggles EdgeScroll on/off (it's the
menu's default action).

## Settings

- **Edge keys** — remap what each screen edge presses. Any single letter or
  AHK key name works (`Left`, `Space`, `Up`, ...). Defaults are WASD.
- **Start with Windows** — adds a `HKCU` Run entry so EdgeScroll launches at
  login. Off by default.

## Config (`EdgeScroll.ini`, created on first toggle)

```ini
[Settings]
EdgeThreshold=1   ; pixels from the physical edge that trigger
PollInterval=10   ; ms between cursor checks
RepeatInterval=30 ; ms between key-down re-sends while held

[Keys]
left=a
right=d
top=w
bottom=s

[State]
Enabled=1
GameMode=0
TargetProcess=   ; empty = any process
Autostart=0
```

See `EdgeScroll.ini.example` for a starting point. The Settings window edits
all of these at runtime — no need to touch the file by hand.

## Notes / limitations

- **Multi-monitor:** only the primary monitor triggers. The cursor is also
  stopped by the physical monitor edge, which is exactly the interaction.
- **Elevated games:** Windows blocks input injection into admin processes;
  run the script as Administrator to cover that case.
- Fullscreen-exclusive titles that use raw input exclusively may still ignore
  injected scancodes; borderless windowed is the most compatible.
