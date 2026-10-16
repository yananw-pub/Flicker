#!/bin/zsh
# 重新注册本机 Flicker Finder Sync 扩展（清理多副本冲突后的手动修复）。
# 用法:
#   ./scripts/register_finder_extension.sh
#   ./scripts/register_finder_extension.sh /Applications/Flicker.app
set -euo pipefail

APP_PATH="${1:-/Applications/Flicker.app}"
APPEX="$APP_PATH/Contents/PlugIns/FlickerExtension.appex"
BUNDLE_ID="com.wangyanan.flicker.extension"

if [[ ! -d "$APPEX" ]]; then
  echo "找不到扩展: $APPEX" >&2
  exit 1
fi

echo "==> 忽略旧选举并注册: $APPEX"
pluginkit -e ignore -i "$BUNDLE_ID" 2>/dev/null || true
pluginkit -a "$APPEX"
pluginkit -e use -i "$BUNDLE_ID"

echo "==> 重启 Finder / 扩展进程"
killall FlickerExtension 2>/dev/null || true
killall Finder 2>/dev/null || true

echo "==> 当前状态:"
pluginkit -m -v -p com.apple.FinderSync 2>/dev/null | grep -i flicker || true
echo "完成。请在 Finder 中右键验证菜单。"
