#!/bin/zsh
set -euo pipefail
setopt null_glob

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/Assets/logo-sources"
OUTPUT_DIR="$ROOT_DIR/Sources/TickerKit/Resources/logo-svg"
mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.svg

cp "$SOURCE_DIR"/*.svg "$OUTPUT_DIR"/
