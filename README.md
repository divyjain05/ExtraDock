# ExtraDock

A second, hidden Dock for macOS apps you use occasionally but don't want cluttering your main Dock. Lives as an invisible trigger on the right edge of the screen; hover it and a horizontal row of app icons slides out on top of the real Dock.

See [decisions.md](decisions.md) for the reasoning behind the architecture.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ / Swift 5.10 toolchain

## Development

```bash
swift build              # build
swift run                # run from source (menu bar icon appears)
open Package.swift        # open in Xcode for debugging/breakpoints
```

## Building a shareable .app

```bash
Scripts/build-app.sh release
```

Produces `build/ExtraDock.app`, ad-hoc signed. Zip it to share:

```bash
ditto -c -k --sequesterRsrc --keepParent build/ExtraDock.app ExtraDock.zip
```

Recipients will hit a Gatekeeper warning on first launch since the build isn't notarized — right-click the app → Open once to bypass it.

## Usage

- Menu bar icon → **Settings…** to add/remove apps and toggle "Launch at Login"
- Menu bar icon → **Show Extra Dock** to preview the panel without hovering the screen edge
- Hover the bottom-right edge of the screen to reveal the dock during normal use
