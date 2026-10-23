# Changelog

The app version is `appVersion` in `Sources/KetcherApp/main.swift`. Commit a change, its entry here and the bump
together.

## 0.1.1

- Fix ⌘C / ⌘V doing nothing: WebKit refused Ketcher's clipboard write once the user gesture was gone, so the
  copy never reached the pasteboard. `navigator.clipboard` now goes through a bridge to `NSPasteboard`; the
  self-test checks the Edit menu's copy and paste.

## 0.1.0

- First version: Ketcher 3.18.0 standalone in a WKWebView, served from the bundle, offline, without browser
  gestures; save and open through native panels; `--selftest`; benzene-ring icon.
