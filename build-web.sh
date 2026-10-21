#!/bin/zsh
# Build the offline Ketcher bundle (needs Node >= 24.14): clones EPAM's Ketcher at $KETCHER_TAG into vendor/,
# builds the standalone example (Indigo as WebAssembly, no server) and copies it to web/. Run once, and again to
# change the Ketcher version. ./build.sh then packs web/ into the app.
set -e
cd "$(dirname "$0")"
KETCHER_TAG=v3.18.0

if [[ ! -d vendor/ketcher ]]; then
    mkdir -p vendor
    git clone --depth 1 --branch "$KETCHER_TAG" https://github.com/epam/ketcher.git vendor/ketcher
fi
cd vendor/ketcher
[[ "$(git describe --tags --exact-match 2>/dev/null)" == "$KETCHER_TAG" ]] || {
    echo "vendor/ketcher is not at $KETCHER_TAG: remove vendor/ketcher and re-run" >&2; exit 1; }
[[ -d node_modules ]] || npm ci
npm run build:packages
npm run build:example:standalone
cd ../..

rm -r web 2>/dev/null || true
cp -R vendor/ketcher/example/dist/standalone web
# Only index.html (the plain editor) is used; the popup/duo/closable/iframe demos each carry their own 29 MB copy.
find web -type f \( -name 'popup*' -o -name 'duo*' -o -name 'closable*' -o -name 'iframe*' \) -delete
cp vendor/ketcher/LICENSE web/LICENSE-ketcher.txt
cp vendor/ketcher/NOTICE web/NOTICE-ketcher.txt
echo "${KETCHER_TAG#v}" > web/ketcher-version.txt
echo "web/ ready (Ketcher ${KETCHER_TAG#v}, $(du -sh web | cut -f1))"
