# ExtraDock — Decisions Log

This file tracks major decisions made on this project, in the order they were made. Append new entries at the bottom; don't rewrite history — if a decision is reversed, add a new entry that says so and links back to the one it replaces.

---

## 2026-08-18 — Goal

Build a macOS utility that adds a second "dock" of apps living on the right edge of the screen, next to the real Dock. It stays hidden until you hover the edge, at which point it slides out horizontally, layered on top of the real Dock. It holds apps you use occasionally but don't want cluttering the main Dock. It runs continuously in the background (survives logout/login), and should be shareable with friends as a standalone app, not just something that runs from source.

---

## Tech stack: Native Swift + AppKit

**Decision:** Build as a native macOS app in Swift, using AppKit for the dock overlay window and SwiftUI for the settings UI.

**Alternatives considered:**
- **Electron + TypeScript/React** — matches the stack used in other projects on this machine, fastest to write. Rejected because the core feature (a borderless, always-on-top panel that detects global cursor position at the screen edge and renders *above* the real Dock's window layer) requires native window-level and event-tap APIs that Electron doesn't expose cleanly — it would mean bridging native modules anyway, while also paying for a Chromium process (~150–250MB idle RAM) sitting in the background permanently.
- **Tauri + TypeScript/React** — lighter runtime than Electron, but the same macOS-specific window-layering and global-hover tricks still require native Rust/Swift glue underneath. No real advantage over going straight to native for this particular app.

**Why native wins here:** the entire value of the app is deep, precise OS integration (window layering relative to the real Dock, global edge-hover detection, launching apps via NSWorkspace, login-item registration). That's exactly what AppKit is for, and it's the lightest possible footprint for something meant to run forever in the background.

---

## Build system: Swift Package Manager, not a raw .xcodeproj

**Decision:** Structure the app as an SPM executable target (`Package.swift` + `Sources/ExtraDock/...`), not a hand-authored Xcode project file.

**Why:** `.pbxproj` files are opaque, hard to review in diffs, and awkward to edit programmatically. SPM's manifest and source layout are plain text and easy to reason about. Xcode can still open an SPM package directly (`open Package.swift`) for anyone who wants the GUI/debugger/Interface Builder-style tools.

**Tradeoff accepted:** no visual Interface Builder — all UI is built in code (AppKit view code / SwiftUI views). No automatic Info.plist management — it's authored by hand in `Resources/Info.plist` and merged in during the app-bundling step (see below), since SPM executables don't produce `.app` bundles on their own. A build script (`Scripts/build-app.sh`) handles turning the built executable into a real `ExtraDock.app`.

---

## App shape: background agent + menu bar icon (not fully headless)

**Decision:** `LSUIElement = true` (no Dock icon, no app switcher entry) plus a small `NSStatusItem` in the menu bar for quitting, opening settings, and adding/removing apps from the dock.

**Why not fully headless:** a background process with literally no UI surface is nearly impossible to configure, update, or quit without `killall`. A single menu bar icon is the accepted macOS convention for "always-running utility" (see Bartender, Rectangle, etc.) and costs almost nothing.

---

## Window layering: custom NSWindow level above the real Dock

**Decision:** The slide-out dock panel is an `NSPanel` (`.nonactivatingPanel`, borderless, transparent background) with an explicit window level placed above the Dock's own window level, so it visually sits on top of it when expanded.

**Note:** the real Dock's window level isn't one of the standard `NSWindow.Level` cases — it has to be derived (`CGWindowLevelForKey` family) and pinned just above it. This is an implementation detail to get right in `Dock/DockPanelController.swift`, not a settled decision — flagging it here so it isn't lost.

---

## Hover detection: global NSEvent monitor, no Accessibility permission

**Decision:** Use `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` to watch cursor position and trigger the slide-out when it nears the right screen edge.

**Why:** this is a read-only, passive monitor and does not require the Accessibility permission prompt that event-tapping/synthesizing (`CGEventTap`) would need. Keeps first-run friction low — important since this will be shared with friends who won't want to grant deep system permissions to a hobby app.

---

## Persistence: flat JSON file, not UserDefaults/Core Data

**Decision:** The list of apps pinned to the extra dock is stored as a small JSON file in `~/Library/Application Support/ExtraDock/`, holding security-scoped bookmarks + display metadata per app.

**Why:** the data is a small ordered list, inspectable/editable by hand is a nice property for a personal tool, and it avoids pulling in Core Data for something this simple.

---

## Launch at login: SMAppService, macOS 13+ minimum

**Decision:** Use `SMAppService.mainApp` (or an agent variant) to register as a login item, rather than the legacy `SMLoginItemSetEnabled` or a LaunchAgent plist.

**Consequence:** minimum deployment target is macOS 13 Ventura. Acceptable — this is a personal/friends tool, not something needing to support old OS versions.

---

## Sandbox: App Sandbox disabled

**Decision:** Ship without App Sandbox entitlements.

**Why:** the app's entire job is launching arbitrary other apps (`NSWorkspace.open`) and reading their icons/bundle info from anywhere on disk. That's fighting the sandbox at every turn, and there's no intent to distribute through the Mac App Store, so there's no requirement to sandbox it.

---

## Distribution to friends: ad-hoc signing first, Developer ID later if needed

**Decision:** Initial builds are signed ad-hoc (free, tied to a local identity) and shared as a zipped `.app`. Recipients will see a Gatekeeper warning on first launch and need to right-click → Open (or clear the quarantine flag) once.

**Why not notarize now:** notarization requires a paid Apple Developer account ($99/yr) and a distribution pipeline. Not worth setting up before the app itself is proven out. Revisit if this is going to be shared beyond a handful of friends — a real Developer ID + notarization removes the warning entirely.

---

## Naming

**Decision:** Product name `ExtraDock`, bundle identifier `com.divyjain.extradock`. No source folder, target, or scheme is named after Claude/the assistant — project structure is a plain, ordinary Swift package (`Sources/ExtraDock/...`) as if hand-authored.
