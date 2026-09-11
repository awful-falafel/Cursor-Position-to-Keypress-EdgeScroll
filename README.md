# EdgeScroll (AutoHotkey v2)

Lightweight background app for Windows that sends **WASD** keypresses when the
mouse cursor touches the extreme edge of the **primary monitor** — replicating
"edge scrolling" from RTS/MOBA games, built as an accessibility option for
players who can't comfortably use WASD.

## Run it

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Double-click `EdgeScroll.ahk`. It lives in the tray.
3. (Optional) Put a shortcut in `shell:startup` to autostart with Windows.

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
- **Edge zone** — cycles how many pixels from the edge count as "at the edge"
  (1 px = literally right up against the edge).
- **Exit** — releases all held keys and quits.

## Config (`EdgeScroll.ini`, created on first toggle)

```ini
[Settings]
EdgeThreshold=1   ; pixels from the physical edge that trigger
PollInterval=10   ; ms between cursor checks

[State]
Enabled=1
GameMode=0
```

To remap edges to other keys, edit the `edgeKeys` map at the top of the script
(e.g. `"left", "Left"` for arrow keys).

## Notes / limitations

- **Multi-monitor:** only the primary monitor triggers. The cursor is also
  stopped by the physical monitor edge, which is exactly the interaction.
- **Elevated games:** Windows blocks input injection into admin processes;
  run the script as Administrator to cover that case.
- Fullscreen-exclusive titles that use raw input exclusively may still ignore
  injected scancodes; borderless windowed is the most compatible.
