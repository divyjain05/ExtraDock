# Auto-updates (Sparkle)

ExtraDock uses [Sparkle 2](https://sparkle-project.org) so installed copies
update themselves. When you publish a new version, existing users get a
"new version available" prompt (or a silent background download, their choice)
and update in place — no reinstall, no re-download from a browser.

## How it works

1. The app embeds `Sparkle.framework` (see `Scripts/build-app.sh`) and starts
   `SPUStandardUpdaterController` at launch (`AppDelegate.swift`).
2. On a schedule (`SUScheduledCheckInterval`, daily) — and when the user picks
   **Check for Updates…** — Sparkle fetches the **appcast**, an XML feed at
   `SUFeedURL` listing the latest version, its download URL, and a signature.
3. If the appcast's `sparkle:version` (your `CFBundleVersion`) is higher than
   the running app's, Sparkle offers the update.
4. Sparkle downloads the `.zip`, verifies its **EdDSA signature** against
   `SUPublicEDKey` in the app's Info.plist (this is the security boundary — a
   tampered or unsigned build is refused), swaps the app bundle in place, and
   relaunches. Because Sparkle installs it (not a browser download), the update
   is **not** quarantined, so there's no Gatekeeper re-prompt.

Hosting: the `.zip` lives as a GitHub **Release asset**; `appcast.xml` lives at
the repo root and is served raw (the `SUFeedURL` above). The feed must be
publicly reachable — keep the repo/releases public.

## One-time setup (do this once, ever)

Generate your signing key. The **private** key is saved to your login keychain;
the **public** key is printed for Info.plist.

```sh
swift build                                     # so SPM fetches Sparkle's tools
.build/artifacts/sparkle/Sparkle/bin/generate_keys
```

Copy the printed public key into `Resources/Info.plist`, replacing
`REPLACE_WITH_generate_keys_PUBLIC_KEY` in the `SUPublicEDKey` value. Commit it.

⚠️ **Back up the private key.** Export it with `generate_keys -x key.txt` and
store it somewhere safe. If you lose it you can never sign an update again —
every installed copy would be permanently stuck (they only trust that key).

## Cutting a release

1. Bump the version in `Resources/Info.plist`:
   - `CFBundleVersion` — must **increase every release** (Sparkle compares this).
   - `CFBundleShortVersionString` — the human version shown in the prompt.
2. Run:
   ```sh
   Scripts/release.sh
   ```
   This builds + signs the app, zips it to `build/releases/ExtraDock-<v>.zip`,
   and writes/updates `build/releases/appcast.xml` with the EdDSA signature.
3. Publish:
   - Create a GitHub Release tagged `v<version>` and upload the `.zip`.
   - Copy `build/releases/appcast.xml` to the repo root, commit, push to `main`.

That's it — installed apps pick it up on their next check.

## Notes

- **Apple Silicon only.** The build is an arm64 binary, so the appcast tags
  updates `arm64` and Sparkle skips Intel Macs. Build universal
  (`swift build --arch arm64 --arch x86_64` in `build-app.sh`) if you need Intel.
- **Keep old zips** in `build/releases/` so `generate_appcast` can keep listing
  prior versions; Sparkle always jumps users to the newest regardless.
- **Not notarized.** First install is still a right-click → Open (unchanged).
  Sparkle-delivered *updates* are not quarantined, so they don't re-prompt.
