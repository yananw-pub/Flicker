#!/bin/zsh
# 打包 Flicker.dmg
# 用法: ./scripts/build_dmg.sh [suffix]
# 产物: dist/Flicker-<version>.dmg
#       dist/Flicker-<version>-<suffix>.dmg  （传入 suffix 时）
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/Flicker.xcodeproj"
SCHEME="Flicker"
CONFIG="Release"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/Flicker.app"
VERSION_SUFFIX="${1:-}"
LOG_FILE="$BUILD_DIR/xcodebuild.log"

echo "==> Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "==> Release 构建"
# 手动清理 build 目录（xcodebuild clean 无法删除自定义 CONFIGURATION_BUILD_DIR）
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

set +e
# Prefer current Mac arch for CI/local speed; universal not required for testing.
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM="" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build 2>&1 | tee "$LOG_FILE"
XCODE_STATUS=${pipestatus[1]}
set -e

if [[ "$XCODE_STATUS" -ne 0 ]]; then
  echo "==> xcodebuild failed ($XCODE_STATUS). Relevant lines:" >&2
  grep -E 'error:|fatal error:|CODE_SIGN|Provisioning|errSec|entitlement|BUILD FAILED' "$LOG_FILE" | tail -80 >&2 || true
  exit "$XCODE_STATUS"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "构建产物未找到: $APP_PATH" >&2
  # Sometimes Xcode nests under Release/
  if [[ -d "$BUILD_DIR/Release/Flicker.app" ]]; then
    APP_PATH="$BUILD_DIR/Release/Flicker.app"
  else
    find "$BUILD_DIR" -name 'Flicker.app' -maxdepth 3 2>/dev/null >&2 || true
    exit 1
  fi
fi

# Ad-hoc re-sign app + appex so Finder Sync can load (CI uses CODE_SIGNING_REQUIRED=NO).
# Must re-apply entitlements + hardened runtime — signing without them drops the extension sandbox.
echo "==> Ad-hoc codesign"
EXT_ENTITLEMENTS="$PROJECT_DIR/FlickerExtension/FlickerExtension.entitlements"
APP_ENTITLEMENTS="$PROJECT_DIR/Flicker/Resources/Flicker.entitlements"
xattr -cr "$APP_PATH" 2>/dev/null || true
codesign --force --sign - --options runtime --entitlements "$EXT_ENTITLEMENTS" --timestamp=none \
  "$APP_PATH/Contents/PlugIns/FlickerExtension.appex"
codesign --force --sign - --options runtime --entitlements "$APP_ENTITLEMENTS" --timestamp=none \
  "$APP_PATH"

# 从构建产物中提取版本号
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
echo "==> 应用版本: $APP_VERSION"

if [[ -n "$VERSION_SUFFIX" ]]; then
  DMG_NAME="Flicker-${APP_VERSION}-${VERSION_SUFFIX}.dmg"
else
  DMG_NAME="Flicker-${APP_VERSION}.dmg"
fi
DMG_PATH="$PROJECT_DIR/dist/$DMG_NAME"

echo "==> 准备 DMG 暂存目录"
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> 生成 DMG"
mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"
hdiutil create -volname "Flicker" -srcfolder "$STAGING" \
  -fs "HFS+" -format "UDZO" -imagekey "zlib-level=9" "$DMG_PATH"

echo "==> 完成: $DMG_PATH"
rm -rf "$STAGING"
