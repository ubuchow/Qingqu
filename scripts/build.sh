#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Bundle Chinese fonts from local machine (not committed to git).
FONT_DIR="$ROOT/Qingqu/Resources/Fonts"
mkdir -p "$FONT_DIR"
copy_font() {
  local dest="$1"; shift
  for src in "$@"; do
    if [[ -f "$src" ]]; then
      cp -f "$src" "$dest"
      return 0
    fi
  done
  return 1
}
copy_font "$FONT_DIR/华文中宋.ttf" \
  "$HOME/Library/Fonts/华文中宋.ttf" \
  "$HOME/Library/Fonts/STZhongsong.ttf" \
  "$HOME/tachikoma-ui/static/assets/fonts/STZhongsong.ttf" \
  || echo "warning: 华文中宋 not found; UI will fall back to system font" >&2
copy_font "$FONT_DIR/方正公文小标宋.ttf" \
  "$HOME/Library/Containers/com.kingsoft.wpsoffice.mac/Data/.kingsoft/office6/docerFonts/方正公文小标宋.TTF" \
  "$HOME/Library/Fonts/方正公文小标宋.ttf" \
  "$HOME/Library/Fonts/方正公文小标宋.TTF" \
  || echo "warning: 方正公文小标宋 not found" >&2
copy_font "$FONT_DIR/方正小标宋简体.ttf" \
  "$HOME/tachikoma-ui/static/assets/fonts/FZXiaoBiaoSong.ttf" \
  "$HOME/Library/Fonts/方正小标宋简体.ttf" \
  "$HOME/Library/Fonts/FZXiaoBiaoSong.ttf" \
  || echo "warning: 方正小标宋简体 not found; title will fall back" >&2

ICONSET="$ROOT/Qingqu/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICONSET"
swift "$ROOT/scripts/make-app-icon.swift" "$ICONSET/icon_1024.png"

for pair in 16:16 32:32 64:64 128:128 256:256 512:512; do
  size="${pair%%:*}"
  sips -z "$size" "$size" "$ICONSET/icon_1024.png" --out "$ICONSET/icon_${size}.png" >/dev/null
done

xcodegen generate

DEST="$ROOT/build"
rm -rf "$DEST"
xcodebuild \
  -project "$ROOT/Qingqu.xcodeproj" \
  -scheme Qingqu \
  -configuration Release \
  -derivedDataPath "$DEST" \
  -destination 'platform=macOS' \
  build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO

APP="$(find "$DEST/Build/Products" -name '轻取.app' -maxdepth 3 | head -n 1)"
if [[ -z "$APP" ]]; then
  echo "build failed: app not found" >&2
  exit 1
fi

# Strip symbols for a smaller binary
BIN="$APP/Contents/MacOS/轻取"
if [[ -f "$BIN" ]]; then
  strip -x "$BIN" || true
fi

INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/轻取.app"
cp -R "$APP" "$INSTALL_DIR/轻取.app"
codesign --force --deep --sign - "$INSTALL_DIR/轻取.app" >/dev/null 2>&1 || true

echo "APP=$INSTALL_DIR/轻取.app"
du -sh "$INSTALL_DIR/轻取.app"
ls -lh "$INSTALL_DIR/轻取.app/Contents/MacOS/"
