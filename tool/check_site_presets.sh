#!/usr/bin/env bash
#
# 出厂站点预置必须只存在于一处：lib/boorus/engine/site_presets.dart。
#
# 为什么需要这条断言：预置数据散在「模板列表 / 引导默认勾选 / 探测域名捷径 /
# 引擎默认域名 / 解析器默认站点」五个地方时，Play 版要清零就必须五处都改对，
# 漏一处等于没删干净——而「没删干净」在审核语境下是致命的（隐藏预置 = 蓄意规避）。
# 这条断言把「单一数据面」变成 CI 能拦下来的硬约束。
set -euo pipefail

cd "$(dirname "$0")/.."

PATTERN='(donmai\.us|e621\.net|sankakucomplex|yande\.re|konachan|zerochan\.net|gelbooru\.com|xbooru\.com|realbooru\.com|tbib\.org|safebooru\.org|paheal\.net|rule34video\.com|rule34\.(xxx|us|paheal)|anime-pictures\.net|e-shuushuu\.net)'
ALLOWED='lib/boorus/engine/site_presets.dart'

# 注释可以提到站点（解释「为什么」是必要的），代码里不行。
HITS=$(grep -rInE "$PATTERN" lib --include='*.dart' \
  | grep -v "^${ALLOWED}:" \
  | grep -vE ':[0-9]+:[[:space:]]*(///|//|\*)' \
  || true)

if [ -n "$HITS" ]; then
  echo "$HITS"
  echo "::error::站点预置出现在 ${ALLOWED} 之外（上面的行）"
  exit 1
fi

echo "预置单一数据面断言通过（仅 ${ALLOWED} 持有站点字面量）"
