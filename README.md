# KetcherApp

[Ketcher](https://github.com/epam/ketcher) (EPAM's open-source chemical structure editor, Apache 2.0) as a native
macOS app that works fully offline. A thin Swift/WebKit shell around Ketcher's *standalone* build, where the Indigo
engine runs as WebAssembly inside the page, so there is no server and no network.

What the shell adds over a browser tab:

- no swipe-back/forward, no pinch-zoom of the page, no rubber-band scrolling;
- nothing leaves the machine: the page is served from the app bundle under `ketcher://app/` with a content security
  policy that blocks every other origin; links open in the default browser;
- *Save as* and *Open* use the normal macOS save and open panels.

## Download

Grab `ketcherapp-X.Y.Z-macos-arm64.zip` from the [Releases](https://github.com/aliperdehan/ketcherapp/releases)
page, unzip it and drag `Ketcher.app` to `/Applications`. Apple Silicon only (an Intel Mac has to build it, below).

The app is ad-hoc signed, not notarized, so macOS blocks the first launch of a downloaded copy. Open it once anyway:
try to open it, then System Settings → Privacy & Security → scroll down → **Open Anyway**. Or, in Terminal, once:
`xattr -dr com.apple.quarantine /Applications/Ketcher.app`.

## Build and install

You can also build it yourself, which takes a few minutes the first time.

Needs the Command Line Tools (`xcode-select --install`, no Xcode), git, and Node ≥ 24.14 (only for the web bundle).

```sh
./build-web.sh          # once: clones Ketcher (pinned tag) into vendor/, builds it, copies the result to web/
./build.sh --install    # builds build/Ketcher.app, copies it to ~/Applications and starts it
```

`./build.sh` alone only makes `build/Ketcher.app`; drag it to `/Applications` yourself if you prefer that folder.
A copy you built yourself is not quarantined and opens normally.

- **Architecture:** the app is built for the Mac that builds it (Apple Silicon or Intel).
- **Update:** `git pull`, then `./build.sh --install`. Ketcher itself is pinned by `KETCHER_TAG` in `build-web.sh`;
  `CLAUDE.md` says how to move it.
- **Save before updating:** `--install` quits a running copy without asking, and the app has no autosave.
- **Uninstall:** delete `Ketcher.app`. What it leaves behind is the window position and Ketcher's own settings:
  `defaults delete io.github.aliperdehan.ketcher-app` and `~/Library/WebKit/io.github.aliperdehan.ketcher-app`.

## Check

```sh
build/Ketcher.app/Contents/MacOS/KetcherApp --selftest   # headless: bundle loads, Indigo works, network is cut, save works
```

`KETCHER_DEBUG=1 open build/Ketcher.app` makes the page inspectable in Safari's Develop menu.

The icon is a benzene ring drawn in code (`design/logo.swift`); it is not Ketcher's logo.

## Licence

The wrapper is MIT (see `LICENSE`). Ketcher is © EPAM Systems under the Apache License 2.0; its `LICENSE` and `NOTICE`
are copied into the app (`Contents/Resources/web/`). This is an unofficial community wrapper, not an EPAM product.
