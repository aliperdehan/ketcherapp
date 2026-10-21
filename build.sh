#!/bin/zsh
# Build Ketcher.app (needs only the Command Line Tools and web/ from ./build-web.sh). Output: build/Ketcher.app
# ./build.sh --install  also quits a running copy, copies the app to ~/Applications and starts it there.
set -e
cd "$(dirname "$0")"
[[ -f web/index.html ]] || { echo "web/ is missing: run ./build-web.sh first" >&2; exit 1; }
VERSION=$(sed -n 's/^let appVersion = "\(.*\)"/\1/p' Sources/KetcherApp/main.swift)
KETCHER=$(cat web/ketcher-version.txt)
swift build -c release
APP=build/Ketcher.app
rm -r "$APP" 2>/dev/null || true
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/KetcherApp "$APP/Contents/MacOS/KetcherApp"
cp -R web "$APP/Contents/Resources/web"
cp design/KetcherApp.icns "$APP/Contents/Resources/KetcherApp.icns"
cat > "$APP/Contents/Resources/Credits.html" <<HTML
<p>Offline wrapper around <b>Ketcher $KETCHER</b>, the open-source chemical structure editor by EPAM Systems
(Apache License 2.0, see web/LICENSE-ketcher.txt).</p>
HTML
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Ketcher</string>
<key>CFBundleIdentifier</key><string>io.github.aliperdehan.ketcher-app</string>
<key>CFBundleIconFile</key><string>KetcherApp</string>
<key>CFBundleExecutable</key><string>KetcherApp</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.education</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "built $APP ($VERSION, Ketcher $KETCHER)"

if [[ "$1" == "--install" ]]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
    osascript -e 'tell application id "io.github.aliperdehan.ketcher-app" to quit' >/dev/null 2>&1 || true
    pkill -x KetcherApp 2>/dev/null || true
    sleep 0.5
    rm -r "$DEST/Ketcher.app" 2>/dev/null || true
    cp -R "$APP" "$DEST/Ketcher.app"
    open "$DEST/Ketcher.app"
    echo "installed $DEST/Ketcher.app"
fi
