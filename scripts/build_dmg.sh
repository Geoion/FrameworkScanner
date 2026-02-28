#!/bin/bash
set -e

VERSION="${1:-1.0.0}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/Build/Products/Release/FrameworkScanner.app"
DMG_NAME="FrameworkScanner-${VERSION}.dmg"

echo "==> Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

echo "==> Building Release (signing disabled, will sign manually)..."
xcodebuild \
  -scheme FrameworkScanner \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=NO \
  clean build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" || true

if [ ! -d "$APP_PATH" ]; then
  echo "✗ Build failed, .app not found"
  exit 1
fi

echo "==> Stripping extended attributes..."
find "$APP_PATH" -exec xattr -c {} \; 2>/dev/null || true

echo "==> Signing with ad-hoc identity..."
codesign --force --deep --sign - \
  --entitlements "$PROJECT_DIR/Resources/FrameworkScanner.entitlements" \
  "$APP_PATH"

echo "==> Creating DMG..."
rm -f "$PROJECT_DIR/$DMG_NAME"
hdiutil create \
  -volname "FrameworkScanner" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "$PROJECT_DIR/$DMG_NAME"

SHA=$(shasum -a 256 "$PROJECT_DIR/$DMG_NAME" | awk '{print $1}')
echo ""
echo "✓ Done: $DMG_NAME"
echo "  SHA256: $SHA"
echo ""
echo "Next steps:"
echo "  1. gh release create v${VERSION} '$PROJECT_DIR/$DMG_NAME' --generate-notes"
echo "  2. Update homebrew-tap sha256 to: $SHA"
