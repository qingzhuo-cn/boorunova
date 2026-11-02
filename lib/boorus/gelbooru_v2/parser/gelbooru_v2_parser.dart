// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/base_booru_repository.dart';
import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:flutter/foundation.dart';

class GelbooruV2Parser {
  GelbooruV2Parser._();

  static const String searchEndpoint =
      '/index.php?page=dapi&s=post&q=index';
  static const String suggestEndpoint =
      '/index.php?page=dapi&s=tag&q=index';

  /// 根元素上的 `count`：该查询命中的总条数。
  ///
  /// 实测响应形如 `<posts count="6960037" offset="0">`。分页必须靠它，
  /// 用「本页条数」推断会在解析过滤掉一条时误判为末页。
  static int? parseCount(String xml) {
    final match =
        RegExp(r'''<posts[^>]*\bcount=["'](\d+)["']''').firstMatch(xml);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// 根元素上的 `offset`：本页起始下标（`pid` 是 0 基页号，offset = pid × limit）。
  static int? parseOffset(String xml) {
    final match =
        RegExp(r'''<posts[^>]*\boffset=["'](\d+)["']''').firstMatch(xml);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static List<BooruPost> parsePosts(
    String serverId,
    String baseUrl,
    String xml,
  ) {
    final posts = <BooruPost>[];
    // 跨行（[\s\S]*?）并兼容单引号属性：变体站会把 <post> 的属性折行，
    // 也有站点用单引号包属性值。此前 (.*?) 不跨行 + 只认双引号，这类
    // 响应会静默解析出 0 条。
    final postPattern = RegExp(r'<post\s+([\s\S]*?)\s*/>');
    final matches = postPattern.allMatches(xml);
    if (matches.isEmpty) {
      // 修复前 0 条无任何提示，用户只看到「没有找到帖子」。
      debugPrint('GelbooruV2Parser.parsePosts: 帖子正则匹配 0 条'
          '（响应 ${xml.length} 字符）：${_preview(xml)}');
    }

    for (final match in matches) {
      final attrs = _parseAttributes(match.group(1)!);
      if (attrs.isEmpty) {
        // 属性全没解出来（引号变体/结构异常）时以前直接 continue，整段
        // 静默丢弃；记日志便于定位变体站。
        debugPrint('GelbooruV2Parser.parsePosts: 属性解析为空，跳过：'
            '${_preview(match.group(1)!)}');
        continue;
      }

      final id = attrs['id'] ?? '';
      final fileUrl = _decodeXml(attrs['file_url'] ?? '');
      final sampleUrl = _decodeXml(attrs['sample_url'] ?? '');
      final previewUrl = _decodeXml(attrs['preview_url'] ?? '');
      final tags = _decodeXml(attrs['tags'] ?? '');
      final width = int.tryParse(attrs['width'] ?? '0') ?? 0;
      final height = int.tryParse(attrs['height'] ?? '0') ?? 0;
      final rating = normalizeRating(attrs['rating']);
      final score = int.tryParse(attrs['score'] ?? '0') ?? 0;
      final source = _decodeXml(attrs['source'] ?? '');

      if (id.isEmpty || fileUrl.isEmpty || width <= 0 || height <= 0) continue;

      posts.add(BooruPost(
        id: id,
        serverId: serverId,
        thumbnailUrl: previewUrl,
        sampleUrl: sampleUrl,
        originalUrl: fileUrl,
        tags: tags.split(' ').where((t) => t.isNotEmpty).toList(),
        aspectRatio: width / height,
        width: width,
        height: height,
        rating: rating,
        score: score,
        source: source.isEmpty ? null : source,
        postUrl: '$baseUrl/index.php?page=post&s=view&id=$id',
      ));
    }

    return posts;
  }

  static List<String> parseSuggestions(String xml) {
    final tags = <String>[];
    // 与帖子正则同款：跨行 + 单/双引号属性。
    final tagPattern = RegExp(r'<tag\s+([\s\S]*?)\s*/>');
    final matches = tagPattern.allMatches(xml);

    for (final match in matches) {
      final attrs = _parseAttributes(match.group(1)!);
      final name = _decodeXml(attrs['name'] ?? '');
      final count = int.tryParse(attrs['count'] ?? '0') ?? 0;
      if (name.isNotEmpty && count > 0) {
        tags.add(name);
      }
    }

    return tags;
  }

  static Map<String, String> _parseAttributes(String raw) {
    final attrs = <String, String>{};
    // 值两侧的引号用反向引用 \2 要求成对出现，单/双引号都能解；
    // 此前只认双引号，单引号属性的变体站会整条属性都解不出来。
    final attrPattern =
        RegExp(r'''([\w:-]+)\s*=\s*(["'])([\s\S]*?)\2''');
    for (final m in attrPattern.allMatches(raw)) {
      attrs[m.group(1)!] = m.group(3)!;
    }
    return attrs;
  }

  /// 日志用的单行预览：折成一行并截断，避免把整页响应打进控制台。
  static String _preview(String text) {
    final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return oneLine.length > 120 ? '${oneLine.substring(0, 120)}…' : oneLine;
  }

  /// 解码 XML 实体。
  ///
  /// 修复前的两个故障：
  /// 1. `&amp;` 排在最前，于是 `&amp;lt;` 会先变成 `&lt;` 再被解成 `<`
  ///    （过度解码），而它的语义应当是字面量 `&lt;`。正确顺序是先解具名/
  ///    数字实体，最后才解 `&amp;`。
  /// 2. 表里缺 `&apos;` 与十进制数字实体（只覆盖了 `&#39;`/`&#x27;`/
  ///    `&#x2F;`），标签与来源里会原样残留实体。
  static String _decodeXml(String text) {
    var out = text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&#x2F;', '/');
    // 十进制数字实体（原实现完全没处理，如 `&#8217;`）。
    out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return (code == null || code <= 0 || code > 0x10FFFF)
          ? m.group(0)!
          : String.fromCharCode(code);
    });
    // 十六进制数字实体（原实现只硬编码了三个）。
    out = out.replaceAllMapped(RegExp(r'&#[xX]([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return (code == null || code <= 0 || code > 0x10FFFF)
          ? m.group(0)!
          : String.fromCharCode(code);
    });
    // `&amp;` 必须放最后：它解出的 `&` 不再参与任何一次实体判定。
    return out.replaceAll('&amp;', '&');
  }
}
