#!/bin/zsh
set -euo pipefail
setopt null_glob

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/Assets/logo-sources"
OUTPUT_DIR="$ROOT_DIR/Sources/TickerKit/Resources/logo-raster"
TMP_DIR="$(mktemp -d)"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.png

for svg in "$SOURCE_DIR"/*.svg; do
  qlmanage -t -s 128 -o "$TMP_DIR" "$svg" >/dev/null
  base="$(basename "$svg" .svg)"
  mv "$TMP_DIR/$base.svg.png" "$OUTPUT_DIR/$base.png"
done

rm -rf "$TMP_DIR"
