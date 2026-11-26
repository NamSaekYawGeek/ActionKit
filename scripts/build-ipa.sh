#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "错误：真机 IPA 必须在安装 Xcode 的 macOS 上构建。" >&2
  exit 1
fi
for tool in xcodegen xcodebuild xcrun python3 zip; do
  command -v "$tool" >/dev/null || { echo "缺少工具：$tool" >&2; exit 1; }
done

mkdir -p build dist
rm -f dist/ActionKit.ipa dist/ActionKit.ipa.sha256
xcodebuild -version
xcodegen --version
xcodegen generate --spec project.yml

# App Intents metadata extraction is a normal Xcode build phase. Do not skip it,
# strip its output, or rebuild an .app manually from only the executable.
xcodebuild \
  -project ActionKit.xcodeproj \
  -scheme ActionKit \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$project_root/build/DerivedData" \
  -resultBundlePath "$project_root/build/ActionKit-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  build 2>&1 | tee build/xcodebuild.log

app_path="$project_root/build/DerivedData/Build/Products/Release-iphoneos/ActionKit.app"
[[ -d "$app_path" ]] || { echo "未找到编译产物：$app_path" >&2; exit 1; }
[[ "$(xcrun lipo -archs "$app_path/ActionKit")" == arm64 ]] || {
  echo "编译产物必须仅包含 arm64 真机架构。" >&2
  exit 1
}

staging_dir="$(mktemp -d "$project_root/build/ipa-stage.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
mkdir -p "$staging_dir/Payload"
# ditto preserves the COMPLETE compiled app, including Metadata.appintents,
# resources, framework/runtime files, permissions and symlinks.
ditto "$app_path" "$staging_dir/Payload/ActionKit.app"
(
  cd "$staging_dir"
  /usr/bin/zip -qry "$project_root/dist/ActionKit.ipa" Payload
)
python3 scripts/verify-ipa.py dist/ActionKit.ipa
(
  cd dist
  shasum -a 256 ActionKit.ipa > ActionKit.ipa.sha256
)
echo "已生成未签名 IPA：$project_root/dist/ActionKit.ipa"
