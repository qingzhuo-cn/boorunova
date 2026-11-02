#!/usr/bin/env bash
#
# Play 版零预置：**字节级**断言（权威口径，与 docs/OPTIMIZATION_AND_PLUS.md §1.2 一致）。
#
# 源码检查只能证明「字面量只有一处」，证明不了「它没进产物」——而审核看的是产物。
# 这里对**已经构建好的 release 产物**（APK / AAB / libapp.so / classes.dex）做断言：
# AOT 会把常量折叠后的死分支连同字符串一起摇掉，所以 release 产物里
# 不应出现任何站点域名。
#
# 注意：不要拿 debug 的 kernel_blob.bin 当替身。debug kernel 为了堆栈可读会嵌
# **整份源码文本**（连注释都在），必然命中，等于没测。
#
# 用法：
#   tool/check_play_bytecode.sh build/app/outputs/flutter-apk/app-release.apk
#   tool/check_play_bytecode.sh build/app/outputs/bundle/release/app-release.aab
set -euo pipefail

cd "$(dirname "$0")/.."

PATTERN='(donmai\.us|e621\.net|sankakucomplex|yande\.re|konachan|zerochan\.net|gelbooru\.com|xbooru\.com|realbooru\.com|tbib\.org|safebooru\.org|paheal\.net|rule34video\.com|rule34\.(xxx|us|paheal)|anime-pictures\.net|e-shuushuu\.net)'

ARTIFACT="${1:-}"
if [ -z "$ARTIFACT" ]; then
  echo '用法：tool/check_play_bytecode.sh <release 产物路径>' >&2
  echo '  例：flutter build apk --release --dart-define=boorunova.play=true' >&2
  echo '     tool/check_play_bytecode.sh build/app/outputs/flutter-apk/app-release.apk' >&2
  exit 2
fi

if [ ! -e "$ARTIFACT" ]; then
  echo "::error::找不到产物：$ARTIFACT"
  exit 1
fi

TARGET="$ARTIFACT"
case "$ARTIFACT" in
  *.apk|*.aab|*.zip)
    # 压缩条目里 grep 不到明文，必须先解包。
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    # unzip 并非处处都有（最小镜像 / 某些本地环境），python3 的 zipfile 是可靠兜底。
    if command -v unzip > /dev/null 2>&1; then
      unzip -o -q "$ARTIFACT" -d "$TMP"
    else
      python3 - "$ARTIFACT" "$TMP" <<'PY'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
PY
    fi
    TARGET="$TMP"
    ;;
esac

echo "检查产物：$ARTIFACT"

# 只打印**命中的字面量**，不打印整行：libapp.so 是二进制，`grep` 的整行输出
# 是几十 KB 的乱码，把真正有用的信息（哪个域名漏了）淹没掉。
HITS=$(grep -raoE "$PATTERN" "$TARGET" | sort -u || true)
if [ -n "$HITS" ]; then
  echo '::error::Play 构建产物里发现站点字面量残留：'
  echo "$HITS"
  exit 1
fi

echo 'Play 版零预置字节级断言通过'
