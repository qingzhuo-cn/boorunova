#!/usr/bin/env bash
# 界面文案必须走 T（app_strings.dart）：README 对外宣称「界面与提示完整双语」，
# 而硬编码中文会让英文用户看到半截中文——这条断言把宣称变成 CI 能拦下来的约束。
#
# 用 python3 而不是 grep：中文字符区间的正则在各平台 grep 里表现不一（Git Bash
# 会直接报 Invalid collation character 并**扫不到任何东西**，关卡变成永远通过的空壳）。
set -euo pipefail

python3 - <<'PY'
import pathlib, re, sys

root = pathlib.Path('lib/presentation')
pattern = re.compile(r"['\"][\u4e00-\u9fa5]")
hits = []
for path in sorted(root.rglob('*.dart')):
    if path.name == 'app_strings.dart':
        continue
    for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith('//'):
            continue  # 注释本来就是中文
        if pattern.search(line):
            hits.append(str(path) + ':' + str(number) + ': ' + stripped[:100])
if hits:
    print('发现未走 T 的中文字面量（界面文案必须进 app_strings.dart）：', file=sys.stderr)
    print('\n'.join(hits), file=sys.stderr)
    sys.exit(1)
print('i18n 收口断言通过（界面层无硬编码中文文案）')
PY
