# NotchPrompter

A minimalist teleprompter for MacBooks with a notch. A translucent text panel
floats just under the camera/notch, scrolls at your chosen speed, and fades
text gracefully into the background so your eyes stay locked on the lens.

- Markdown-aware script rendering
- Scroll speed, font size and window height all adjustable on the fly
- Typography controls: family, weight, size, line/letter spacing, alignment, color
- Background color, opacity, corner radius, and top/bottom fade height
- Quick-load `.txt` / `.md` / `.rtf` scripts
- Mirror text mode for optical teleprompter rigs
- Floats above every other window, including full-screen apps

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.7+ (ships with Xcode 14 and newer)
- A MacBook with or without a notch — it works on any Mac, but looks nicest
  tucked under the notch of a MacBook Pro/Air (M1 Pro/Max, M2, M3 and beyond)

## Install

Clone the repo:

```bash
git clone https://github.com/rtatay/notch-prompter.git
cd notch-prompter
```

No extra dependencies. Everything is Swift Package Manager + SwiftUI.

## Run

### Quick start — from the terminal

```bash
swift run NotchPrompter
```

The first build takes a moment while SwiftPM compiles. Subsequent launches are
fast. The app launches a floating window that snaps just below the menu
bar/notch.

To quit, use `⌘Q` or `Ctrl+C` in the terminal.

### Run from Xcode (nicer debugging)

```bash
open Package.swift
```

Xcode will open the package as a project. Pick the `NotchPrompter` scheme and
hit `⌘R` to run.

### Build a release binary

```bash
swift build -c release
./.build/release/NotchPrompter
```

## Using it

### The basics

1. Launch the app. A translucent bar appears just below the notch with a short
   welcome script already loaded.
2. Press **Space** to start scrolling. Press **Space** again to pause.
3. Hover your mouse over the teleprompter to reveal the **HUD** at the bottom —
   play/pause, restart, speed, font size, window height, open file, and
   appearance settings.
4. Press **⌘O** to load your own script (`.txt`, `.md`, `.rtf`).

### Keyboard shortcuts

| Shortcut          | Action                          |
| ----------------- | ------------------------------- |
| `Space`           | Play / Pause                    |
| `⌘⏎`              | Play / Pause (menu equivalent)  |
| `⌘R`              | Restart from the top            |
| `⌘O`              | Open script…                    |
| `⌘⇧O`             | Reload the current script       |
| `⌘↑` / `⌘↓`       | Faster / Slower                 |
| `⌘]` / `⌘[`       | Taller / Shorter window         |
| `⌘⇧=` / `⌘⇧-`     | Bigger / Smaller text           |
| `⌘⇧N`             | Snap back under the notch       |
| `⌘M`              | Toggle mirror text              |
| `⌘Q`              | Quit                            |

### The HUD (hover to reveal)

| Control       | What it does                                       |
| ------------- | -------------------------------------------------- |
| ▶ / ⏸         | Play or pause the scroll                           |
| ↺             | Jump back to the top of the script                 |
| Speedometer   | Scroll speed in points/second                      |
| `Aa`          | Font size                                          |
| ↕             | Window height                                      |
| 📁            | Open a script file                                 |
| Sliders icon  | Open the Appearance window                         |

### Appearance window

Open via the sliders icon in the HUD. Everything is live — changes apply
immediately.

**Typography**
- Font family (curated list of system-installed families)
- Weight (Ultralight → Black)
- Size, line spacing, letter spacing
- Alignment (left / center / right)
- Text color
- Mirror toggle (flip horizontally for an optical teleprompter rig)

**Background**
- Color and opacity
- Corner radius
- Fade height — how tall the top/bottom gradient masks are. Larger = softer
  text entry/exit

**Window**
- Height (in pixels)
- Width (as a fraction of the screen)
- **Snap Under Notch** — recenters and re-positions the window below the
  notch. Useful after moving displays or resizing.

**Playback**
- Scroll speed in points/second

### Writing scripts

Plain text works fine. Markdown support includes:

```markdown
# Heading 1
## Heading 2
### Heading 3

Regular paragraph with **bold**, *italic*, `inline code`
and [links](https://example.com).

- Bullet item
- Another bullet

> Blockquote with a subtle accent bar for emphasis.

---
```

Blank lines separate paragraphs. Horizontal rules (`---`, `***`, `___`) render
as a thin line.

### Tips for recording

- Drop the **opacity** below 1.0 to peek through to slides or a browser behind
  the teleprompter.
- Increase the **fade height** if hard edges around the scrolling text feel
  distracting.
- Use **⌘⇧N** (Snap Under Notch) after plugging in an external display —
  screen geometry changes, and the shortcut re-snaps the window into place.
- For actual optical-teleprompter rigs (glass in front of the lens), turn on
  **Mirror Text**.
- Start with a speed around **60 pt/s** and tweak with **⌘↑ / ⌘↓** until it
  matches your pace.

## Troubleshooting

**The window doesn't land under the notch.**
Press `⌘⇧N` or click *Snap Under Notch* in the Appearance window. If you have
multiple displays, make sure the notched one is the main display under
System Settings → Displays.

**Space bar doesn't toggle play/pause.**
The global space shortcut is ignored while a text field has focus — click
somewhere that isn't an input to regain the shortcut.

**A font I chose renders in a default face.**
`Font.custom` resolves by PostScript family name. The curated font list only
includes families that ship with macOS and resolve reliably; if you pick one
that isn't installed, SwiftUI falls back to the system font.

## Project layout

```
Package.swift
Sources/
  NotchPrompter/
    NotchPrompterApp.swift   App entry + menu commands + scenes
    PrompterState.swift      ObservableObject holding all app state
    ContentView.swift        Root view (teleprompter + hover HUD)
    TeleprompterView.swift   Scrolling surface + fade gradients
    MarkdownContent.swift    Lightweight markdown renderer
    NotchWindow.swift        NSWindow configuration + notch positioning
    ControlsOverlay.swift    HUD with play/speed/size/height/etc.
    SettingsPanel.swift      Appearance/preferences window
    DefaultScript.swift      Placeholder welcome text
```

## License

MIT — do whatever you like, attribution appreciated.
