#!/bin/zsh
# design/make-icns.sh <icon.png> <out.icns>: a square PNG of at least 1024 px -> an .icns
# The committed icon:  swift design/logo.swift design/out && design/make-icns.sh design/out/icon.png design/KetcherApp.icns
set -e
[[ $# == 2 ]] || { echo "usage: $0 icon.png out.icns" >&2; exit 2; }
SRC=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
OUT=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
SET=$(mktemp -d)/icon.iconset
mkdir -p "$SET"
for n in 16 32 128 256 512; do
    sips -z $n $n "$SRC" --out "$SET/icon_${n}x${n}.png" >/dev/null
    sips -z $((n*2)) $((n*2)) "$SRC" --out "$SET/icon_${n}x${n}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$OUT"
echo "wrote $2"
