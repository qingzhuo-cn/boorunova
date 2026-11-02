#!/usr/bin/env bash
# 构建 Android 发布包并自检；--publish 追加创建 GitHub Release。
#
# 存在的理由：手工敲发布命令最容易漏两件事——`--target-platform`（漏了通用包
# 会胖到 56MB）和签名校验（漏了可能发出装不上的包）。把这两件写进脚本，
# 漏不掉。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXPECTED_CERT="5687a29420f6e278faae3ff97e420ce1adc5517d8b5a6cf759995f38c681f3cd"
PUBLISH=0
[ "${1:-}" = "--publish" ] && PUBLISH=1

fail() { echo "✗ $*" >&2; exit 1; }
ok()   { echo "✓ $*"; }

# ---- 前置：密钥必须就位（缺了 gradle 也会硬失败，这里提前给出人话提示） ----
[ -f android/key.properties ] || fail "缺少 android/key.properties，见 docs/RELEASING.md"
[ -f android/release.jks ]    || fail "缺少 android/release.jks，见 docs/RELEASING.md"

# ---- 版本号：唯一来源是 pubspec.yaml ----
VERSION_LINE=$(grep -E '^version:' pubspec.yaml | head -n1 | awk '{print $2}')
VERSION_NAME="${VERSION_LINE%%+*}"
VERSION_CODE="${VERSION_LINE##*+}"
TAG="v${VERSION_NAME}"
echo "版本：$VERSION_NAME+$VERSION_CODE（tag $TAG）"

# 工作区必须干净，否则打出来的包对应的代码无法追溯
[ -z "$(git status --porcelain)" ] || fail "工作区有未提交改动，先提交再发布"

# ---- 静态检查与测试 ----
flutter analyze --fatal-infos
flutter test

# ---- 构建（--target-platform 是正确性的一部分，不能省） ----
# --split-debug-info 与 CI 保持一致（实测 19.6 → 18.5MB）：符号单独留存，
# 用户导出的诊断日志要靠它才能还原成可读栈。
flutter build apk --release --target-platform android-arm64,android-x64 \
  --split-debug-info=build/symbols

APK_DIR="build/app/outputs/flutter-apk"
ARM64="$APK_DIR/app-arm64-v8a-release.apk"
UNIVERSAL="$APK_DIR/app-release.apk"
[ -f "$ARM64" ]     || fail "未产出 $ARM64"
[ -f "$UNIVERSAL" ] || fail "未产出 $UNIVERSAL"

# ---- 体积自检：通用包显著超 45MB 说明多打进了一个 ABI ----
uni_mb=$(( $(stat -c%s "$UNIVERSAL") / 1048576 ))
arm_mb=$(( $(stat -c%s "$ARM64") / 1048576 ))
echo "arm64: ${arm_mb}MB  universal: ${uni_mb}MB"
[ "$uni_mb" -le 45 ] || fail "通用包 ${uni_mb}MB 偏大，检查是否漏了 --target-platform"

# ---- 签名自检：指纹必须与台账一致 ----
APKSIGNER=$(command -v apksigner || true)
if [ -n "$APKSIGNER" ]; then
  cert=$("$APKSIGNER" verify --print-certs "$ARM64" \
          | grep 'certificate SHA-256 digest' | head -n1 | awk '{print $NF}' \
          | tr 'A-F' 'a-f')
  [ "$cert" = "$EXPECTED_CERT" ] || fail "签名证书不一致：$cert"
  ok "签名证书一致"
else
  echo "! 未找到 apksigner，跳过签名校验（请手动确认）"
fi

# ---- 校验和 ----
# 只留本地存档（打印在日志里自查）；Release 页面只挂安装包。
( cd "$APK_DIR" && sha256sum app-arm64-v8a-release.apk app-release.apk > SHA256SUMS.txt )
cat "$APK_DIR/SHA256SUMS.txt"

if [ "$PUBLISH" = "1" ]; then
  # 有手写发布说明就用它，没有就让 GitHub 自动生成——不因为缺一个文档而卡住发布
  NOTES_ARGS=(--generate-notes)
  if [ -f "docs/release_notes/$TAG.md" ]; then
    NOTES_ARGS=(--notes-file "docs/release_notes/$TAG.md")
  fi
  # Release 只挂安装包；符号留在 build/symbols.tar.gz，需要时再单独上传
  gh release create "$TAG" \
    --title "BooruNova $TAG" \
    --latest \
    "${NOTES_ARGS[@]}" \
    "$ARM64" "$UNIVERSAL"
  ok "已发布 $TAG"
else
  echo "（未加 --publish，仅构建。上传：gh release create $TAG --title \"BooruNova $TAG\" --latest $ARM64 $UNIVERSAL）"
fi
