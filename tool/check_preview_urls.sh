#!/usr/bin/env bash
# 「预览用哪张图」只能有一个决定点：booru_repository 的 previewUrlOf()。
#
# 背景：查看器、详情页头图、收藏弹层大图此前各写一遍「sample 优先，没有就
# original」。OPT §6.4 把「预览画质」变成可配置项后，这三处必须同时改——事实
# 上它们就是在三次不同的改动里各自被发现的。把这条规则做成关卡，比指望每次
# 都记得搜一遍可靠。
#
# 判定：presentation 层任何**同一行**同时出现 sampleUrl 与 originalUrl 的地方，
# 都是在手写选择逻辑（合法的构造/透传写法里两者各占一行）。
set -euo pipefail

hits=$(grep -rn --include='*.dart' -E 'sampleUrl.*originalUrl|originalUrl.*sampleUrl' lib/presentation || true)

if [ -n "$hits" ]; then
  echo "发现手写的「预览图选择」逻辑（应改用 previewUrlOf）：" >&2
  echo "$hits" >&2
  exit 1
fi

echo "预览图选择唯一化断言通过（presentation 层无 sampleUrl/originalUrl 手写选择）"
