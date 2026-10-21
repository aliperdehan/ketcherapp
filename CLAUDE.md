# KetcherApp

A macOS app that wraps EPAM's Ketcher (standalone build) in a WKWebView, offline. Swift, SwiftPM, no Xcode. The
README lists the features; this file is only process.

## Layout

- `Sources/KetcherApp/Scheme.swift`: serves `web/` from the bundle as `ketcher://app/`; the CSP lives here.
- `Sources/KetcherApp/Host.swift`: WKWebView, navigation policy, downloads, file picker, JS dialogs.
- `Sources/KetcherApp/main.swift`: app delegate, menus, `appVersion`. `SelfTest.swift`: `--selftest`.
- `build-web.sh` pins the Ketcher tag (`KETCHER_TAG`) and builds `web/` from `vendor/ketcher/`; `vendor/` and `web/`
  are ignored. `build.sh` packs `web/` into `build/Ketcher.app`.

## Process

- Test headless first: `./build.sh && build/Ketcher.app/Contents/MacOS/KetcherApp --selftest`. It loads Ketcher in a
  window that is never shown and checks the bundle loads, Indigo's WASM parses a molecule, an external `fetch` is
  blocked, and a blob download reaches disk.
- **Do not launch the window while the author may be typing** (a launched app takes the keyboard focus).
  `--selftest` does not take focus; `open build/Ketcher.app` does.
- Keystrokes and gestures cannot be sent from here: the menu shortcuts (⌘C/⌘V, ⌘A and ⌘Z reaching Ketcher), the
  save and open panels and the missing swipe/pinch are checked by the author.
- Edit menu: leave Select All and Undo/Redo out; with them ⌘A/⌘Z would hit WebKit instead of Ketcher.
- Upgrading Ketcher: change `KETCHER_TAG`, remove `vendor/ketcher` and `web/`, run `./build-web.sh`, then the
  self-test. Its example build uses Vite and React; the clone has case-colliding autotest screenshots, a harmless git
  warning on a case-insensitive disk.

## Icon

`design/logo.swift` draws the committed icon, a Kekulé benzene ring (`swift design/logo.swift design/out`, which also
writes a contact sheet `design/out/sheet.png`); `design/make-icns.sh design/out/icon.png design/KetcherApp.icns` turns
it into the `.icns` that `build.sh` copies into the app. It is drawn in code, in the teal of Ketcher's toolbar (`#387580`): do not put EPAM's Ketcher
logo (their trademark) or any other third-party artwork in the repository. `design/out/` is ignored by git.
