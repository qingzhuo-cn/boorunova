import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「跟随系统」语言的解析（OPT §5.1）。
///
/// 口径必须与启动降级页一致——两处不一致的话，英文系统用户会在降级页和
/// 正常页面看到不同语言。
void main() {
  test('显式选择优先，与系统语言无关', () {
    expect(resolveLanguage('zh', 'en'), 'zh');
    expect(resolveLanguage('en', 'zh'), 'en');
  });

  test('跟随时：系统是英文才用英文', () {
    expect(resolveLanguage(kLanguageSystem, 'en'), 'en');
    expect(resolveLanguage(kLanguageSystem, 'en-US'), 'en',
        reason: '带地区的系统语言也要认');
    expect(resolveLanguage(kLanguageSystem, 'EN'), 'en',
        reason: '大小写不敏感');
  });

  test('跟随时：其他语言（含不支持的语言）回落中文', () {
    expect(resolveLanguage(kLanguageSystem, 'zh'), 'zh');
    expect(resolveLanguage(kLanguageSystem, 'ja'), 'zh');
    expect(resolveLanguage(kLanguageSystem, 'fr-CA'), 'zh');
    expect(resolveLanguage(kLanguageSystem, ''), 'zh',
        reason: '读不到系统语言时也要有个确定结果');
  });

  test('未知设置值按「跟随系统」处理（不崩、不返回空）', () {
    expect(resolveLanguage('', 'en'), 'en');
    expect(resolveLanguage('de', 'zh'), 'zh');
  });
}
