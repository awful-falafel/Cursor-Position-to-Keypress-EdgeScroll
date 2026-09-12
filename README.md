# Cursor Position to Mimic In-Game EdgeScrolling

Lightweight background app (AHK or EXE) that sends keypresses (default **WASD**) when the mouse cursor touches the extreme edges of the **primary monitor**.

This app is intended to support those who desire more accessibility options when replicating "edge scrolling" in games that offer it via keypresses alone.

## How to run it

**Option A — prebuilt EXE:** grab `EdgeScroll.exe` from the [Releases](../../releases) page and run it. No AutoHotkey install needed.

**Note:** Windows may throw up a _"Windows protected your PC; Microsoft Defender SmartScreen prevented an unrecognized app from starting. Running this app might put your PC at risk."_ message. It's just because I refuse to pay for a certificate to prove to Microsoft I'm not a criminal. This project's open-code, there's nothing sketchy going on.

Hit 'More info' and run anyway.

You'll then see the app's ⭐ tray icon in your taskbar. If it's disabled by default it'll by a 🚫 icon.

**Option B — from source:**
1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Double-click `EdgeScroll.ahk`. It also lives in the tray, identical to the EXE version.

## How it works

- A timer polls the cursor position (negligible CPU; can be further relaxed).
- Dragging your cursor to the top, left, bottom or right edge of your primary monitor holds down the `W`, `A`, `S` or `D` key respectively (can be changed); moving the cursor away releases it.
- The trigger zones can be increased to your preference.
- Keys are sent with scancode-based `keybd_event` injection, which most games accept.

## Tray menu

- **Enable/Disable** — toggles detection (default tray action).
- **Game Mode** — same injection path today; the toggle exists so elevated games can be supported by simply running the script *as Administrator* when playing. If a game ignores input, restart EdgeScroll elevated.
- **Settings...** — opens a window with the trigger zone (pixels from the edge), poll/repeat intervals, the edge→key assignments, Start-with-Windows, and the focus-process picker.
- **Focus process** — have this app only trigger while a chosen program (e.g. `game.exe`) is the foreground window.
- **Exit** — releases all held keys and quits the app.

Double-left-clicking the tray icon toggles EdgeScroll on/off (it's the menu's default action).

## Settings...

- **Edge keys** — Works with any key (letters, arrows, numpad, F-keys) but modifiers are ignored. Defaults are WASD.
- **Start with Windows** — adds a `HKCU` Run entry so EdgeScroll launches at login. Off by default.

## Config (`EdgeScroll.ini`, created on first toggle; can be completely ignored if you're not a nerd)

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

## Notes / limitations

- **Multi-monitor:** only the primary monitor triggers. There is an 'ignore other monitors' setting for games that refuse to bind the mouse cursor. I don't recommend using this without a focused app set first.
- **Elevated games:** Windows blocks input injection into admin processes; run the script as Administrator to cover that case.
- Fullscreen-exclusive titles that use raw input exclusively may still ignore injected scancodes; borderless windowed is the most compatible.
