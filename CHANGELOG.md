# Changelog

The app version is `appVersion` in `Sources/KetcherApp/main.swift`. Commit a change, its entry here and the bump
together.

## 0.1.2

- Fix *Save as*: the Mac save panel offered "Unknown" and then failed. Ketcher's FileSaver.js took the WebView for an
  embedded browser and navigated the page to a nameless `data:` URL; the app now supplies `window.saveAs` as a
  named `<a download>`, as in Safari. (A "Safari" user agent would also fix it but breaks ⌘C.)
- No second save panel: the file goes straight into a remembered folder, with the name and format from Ketcher's
  Save dialog, and " 2", " 3"… instead of overwriting. The first save asks for the folder; *File ▸ Save Folder…*
  changes it. The self-test now saves through `saveAs` and checks the file name.

## 0.1.1

- Fix ⌘C / ⌘V doing nothing: WebKit refused Ketcher's clipboard write once the user gesture was gone, so the
  copy never reached the pasteboard. `navigator.clipboard` now goes through a bridge to `NSPasteboard`; the
  self-test checks the Edit menu's copy and paste.

## 0.1.0

- First version: Ketcher 3.18.0 standalone in a WKWebView, served from the bundle, offline, without browser
  gestures; save and open through native panels; `--selftest`; benzene-ring icon.
