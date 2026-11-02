#!/usr/bin/env bash
# 重建并部署品牌图标 / 启动画面资源。
#
# 用法（项目根目录）：
#   1) 编辑 lib/presentation/widgets/common/brand_icon.dart 调整图形
#   2) 运行  ./tool/deploy_brand_assets.sh
#
# Flow:
#   1. flutter test --update-goldens  生成大图（见 test/icon_golden_test.dart）
#   2. PowerShell 高保真缩放出各密度 PNG 到 android/app/src/main/res
#
# Depends on: flutter, PowerShell (Windows)

set -e
cd "$(dirname "$0")/.."

echo "==> 1/3 render golden PNGs (BrandIcon)"
flutter test --update-goldens test/icon_golden_test.dart

GOLDEN="test/goldens"
RES="android/app/src/main/res"

echo "==> 2/3 resize per-density PNG"
powershell -NoProfile -Command "
Add-Type -AssemblyName System.Drawing
function Resize-To(\$src, \$dst, \$px) {
  \$img = [System.Drawing.Image]::FromFile(\$src)
  \$bmp = New-Object System.Drawing.Bitmap(\$px, \$px)
  \$g = [System.Drawing.Graphics]::FromImage(\$bmp)
  \$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  \$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  \$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  \$g.DrawImage(\$img, 0, 0, \$px, \$px)
  \$g.Dispose(); \$bmp.Save(\$dst, [System.Drawing.Imaging.ImageFormat]::Png); \$bmp.Dispose(); \$img.Dispose()
}
\$r = '$RES'
\$g = '$GOLDEN'
# 启动器图标各密度
Resize-To \"\$g/ic_launcher.png\" \"\$r/mipmap-mdpi/ic_launcher.png\" 48
Resize-To \"\$g/ic_launcher.png\" \"\$r/mipmap-hdpi/ic_launcher.png\" 72
Resize-To \"\$g/ic_launcher.png\" \"\$r/mipmap-xhdpi/ic_launcher.png\" 96
Resize-To \"\$g/ic_launcher.png\" \"\$r/mipmap-xxhdpi/ic_launcher.png\" 144
Resize-To \"\$g/ic_launcher.png\" \"\$r/mipmap-xxxhdpi/ic_launcher.png\" 192
# 自适应前景各密度（108dp 基准）
Resize-To \"\$g/ic_launcher_fg.png\" \"\$r/drawable-mdpi/ic_launcher_foreground.png\" 108
Resize-To \"\$g/ic_launcher_fg.png\" \"\$r/drawable-hdpi/ic_launcher_foreground.png\" 162
Resize-To \"\$g/ic_launcher_fg.png\" \"\$r/drawable-xhdpi/ic_launcher_foreground.png\" 216
Resize-To \"\$g/ic_launcher_fg.png\" \"\$r/drawable-xxhdpi/ic_launcher_foreground.png\" 324
Resize-To \"\$g/ic_launcher_fg.png\" \"\$r/drawable-xxxhdpi/ic_launcher_foreground.png\" 432
# 启动 logo（透明底）：层列表 gravity=center 按 200dp 绘制（与 BrandSplash 同尺寸），
# xxhdpi 下 200dp≈600px，出 768px 留余量
Resize-To \"\$g/splash_logo.png\" \"\$r/drawable-xxhdpi/splash_logo.png\" 768
Write-Output "  PNG deployed"
"

echo "==> 3/3 verify"
flutter analyze --no-pub 2>&1 | tail -2
echo "Done. Install on emulator to verify; edit brand_icon.dart then rerun this script."
