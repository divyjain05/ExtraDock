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

## 2026-08-18 — Panel settles centered over the Dock, not at the corner

**Decision:** The expanded panel's resting position is horizontally centered on screen (`screen.midX`), matching where the real Dock sits by default, rather than tucked into the bottom-right corner. The hover trigger stays a thin strip on the right edge; only the panel's *destination* changed. It still slides in from the right, so the motion is unchanged — just the endpoint.

**Why:** checked this Mac's actual Dock settings (`defaults read com.apple.dock orientation` → `bottom`, not `right`). A bottom-right-corner panel wouldn't visually overlap a bottom-centered Dock at all, which breaks "comes out on top of the main dock." Centering the target position is what actually satisfies that requirement for the default Dock position. If the Dock's position/size preference changes later, this should read the live Dock geometry instead of assuming center — flagged as a known simplification, not a permanent decision.

---

## 2026-08-18 — Drag-and-drop onto the panel, in addition to Settings

**Decision:** The expanded panel itself is a drop target (`Dock/DockDropView.swift`, an `NSView` implementing `NSDraggingDestination`) — dragging a `.app` bundle onto it while it's open adds it to the dock immediately, on top of the existing Settings-window "Add App…" flow.

**Why:** dragging an app onto a dock is the expected macOS interaction (it's how the real Dock works) and is faster than opening Settings each time. Kept the Settings-window flow too since it's the only way to *remove* apps or toggle login-item behavior, and works even when the panel isn't currently visible.

---

## 2026-08-22 — Reversal: show a real Dock icon after all

**Decision:** Dropped `LSUIElement` from `Info.plist` and changed the activation policy in `AppDelegate.swift` from `.accessory` to `.regular`. ExtraDock now shows a normal icon in the real Dock and in Cmd+Tab, in addition to the existing menu bar item.

**Why:** explicitly requested — replaces the "App shape: background agent + menu bar icon" decision above (background agent, menu-bar-only, no Dock presence). The menu bar icon stays; it's not removed, just no longer the only way to see the app is running.

---

## 2026-08-22 — App icon generated as code, not designed in an image editor

**Decision:** The Dock/Finder icon is produced by `Scripts/IconGen/generate-icon.swift`, a small AppKit program that draws the artwork directly with Core Graphics/`NSBezierPath` (gradient squircle background, a translucent dock pill holding three colored app squares, one white square elevated above it with a "+" mark) and rasterizes it to PNG. `Scripts/IconGen/build-icns.sh` resizes that master into the full macOS iconset and packs it into `Resources/AppIcon.icns` via `iconutil`. `build-app.sh` copies it into the bundle; `Info.plist` points at it via `CFBundleIconFile`.

**Why:** no image-editing tool was available in this environment, but a precise vector-style icon is easy to describe in drawing code and trivial to re-render at every required resolution deterministically. It also means the icon's source lives in the repo as text and can be tweaked (colors, layout) by editing the script and re-running `build-icns.sh`, rather than depending on a binary design file.

**Note:** `Resources/AppIcon.icns` is committed (it's a build output, but there's no separate asset pipeline to regenerate it automatically); the intermediate `AppIcon.iconset/` PNGs and the 1024px master render are gitignored since `build-icns.sh` recreates them on demand.

---

## 2026-08-22 — Reversal: hover trigger is the app's own Dock icon, requires Accessibility permission

**Decision:** Replaced the screen-right-edge hover trigger with one anchored to ExtraDock's own icon in the real Dock. `Dock/DockIconLocator.swift` walks the Dock process's accessibility tree (`AXUIElementCreateApplication` on `com.apple.dock`'s PID → its `AXList` child → the `AXDockItem` whose title matches our app name → its `AXPosition`/`AXSize`) to get that icon's live on-screen frame. `DockPanelController` caches that frame, refreshes it on a timer plus on `NSWorkspace` launch/terminate notifications (the Dock reflows icon positions as other apps launch/quit), and uses it as the hover-trigger zone and as the horizontal anchor for where the panel appears. The panel now slides up from behind the Dock rather than in from the right edge, since it's anchored to a variable icon position instead of a fixed screen edge.

**Why:** explicitly requested — "hover over the app icon" only. There's no public API for "where is my own Dock icon"; inspecting another process's UI tree via Accessibility is the standard (if unofficial) way apps like Bartender-style Dock utilities do this.

**Consequence — reverses the "Hover detection: global NSEvent monitor, no Accessibility permission" decision above:** this app now requires Accessibility permission (`System Settings → Privacy & Security → Accessibility`) to work as designed. The app requests it once on first launch via `AXIsProcessTrustedWithOptions`, and there's a "Grant Accessibility Access…" item in the menu-bar menu (hidden once granted) that deep-links to that settings pane. This raises first-run friction for anyone this is shared with — flagged as a real tradeoff, not a decision to gloss over.

**Graceful degradation:** if permission isn't granted (or the Dock hasn't registered the icon yet), `DockPanelController` falls back to the old right-edge hover zone and centers the panel on screen, so the app still functions — just not anchored to the icon — rather than doing nothing until permission is granted.

**Dev-time caveat:** ad-hoc code signing (`codesign --sign -`) produces a new signature hash on every rebuild, and TCC (which tracks Accessibility grants) is keyed off that. Expect to re-grant Accessibility after every `Scripts/build-app.sh` run during development. This is a non-issue for an end user who builds once and doesn't touch the binary again.

---

## 2026-08-22 — Reveal animation: grow out of the icon, not slide from the screen edge

**Decision:** The panel's reveal animation changed from translating in from fully off-screen below the display, to expanding directly out of the Dock icon: `DockPanelController` now animates between a `collapsedFrame()` (pinned to the icon's own bottom edge, `height: 1`) and `expandedFrame()` (the full-size resting frame), via `NSWindow.setFrame(_:display:animate:)` on both size and position at once.

**Why:** requested — the original version slid up from the bottom of the screen generically, not visibly connected to the icon that triggered it. Anchoring the collapsed frame to `dockIconFrame.minY` makes the reveal read as rising directly out of that specific icon.

**Bug found along the way:** the original animation used `NSAnimationContext.runAnimationGroup` with `panel.animator().setFrameOrigin(...)`. Diagnostic logging showed its completion handler firing in the same millisecond as the call, with the frame never actually changing — that code path was a silent no-op for this nonactivating panel. Switched to the older `setFrame(_:display:animate:)` API, which reliably animates both size and origin together (a prerequisite for the grow effect, since `setFrameOrigin` alone can't animate size).

**Known simplification:** the SwiftUI content view is a fixed size and gets compressed/stretched along with the window during the ~0.15–0.2s animation (there's no separate clip mask), so the reveal has a slight "squish" to it rather than a clean crop-reveal. Not addressed since it's brief and reads fine at that duration — worth revisiting only if it becomes visually distracting.

---

## Naming

**Decision:** Product name `ExtraDock`, bundle identifier `com.divyjain.extradock`. No source folder, target, or scheme is named after Claude/the assistant — project structure is a plain, ordinary Swift package (`Sources/ExtraDock/...`) as if hand-authored.

---

## 2026-08-23 — Reveal animation, take 3: fixed baseline at the icon's top edge

**Decision:** `collapsedFrame()` and `expandedFrame()` in `DockPanelController` now share the exact same bottom edge — `dockIconFrame.maxY`, the top of the Dock icon. Only the height animates, from `1pt` up to the full panel height; the Y origin never moves. The panel grows straight up from a fixed line sitting on top of the icon.

**Why (third iteration on this):** the first version (full frame sliding from off-screen below) read as coming from the bottom of the screen, not the icon. The second version (constant-size slide, collapsed frame's top edge pinned to the icon's *bottom*) still didn't read as coming from the icon convincingly. This version anchors to the icon's *top* edge specifically, per explicit request, and removes any Y-translation ambiguity by holding the baseline fixed and only growing height — the least ambiguous way to make "emerges from the icon" literally true.

**Consequence:** the panel's resting position moved — it no longer dips down to overlap the Dock's own icon row (previously anchored near `screen.minY`); it now sits entirely above the triggering icon. `bottomInset` was removed as dead code.

**Known tradeoff (carried over, unresolved):** the SwiftUI content view still gets compressed with the window during the height animation (no separate clip mask) — same simplification noted in the first grow-based attempt. Revisit if the ~150ms squish reads as glitchy rather than a smooth reveal.
