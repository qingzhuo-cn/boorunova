import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:flutter/material.dart';

class BooruSiteTemplate {
  const BooruSiteTemplate({
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.icon,
    required this.color,
    this.description,
  });

  final String name;
  final BooruType type;
  final String baseUrl;
  final IconData icon;
  final MaterialColor color;
  final String? description;

  static const List<BooruSiteTemplate> all = [
    BooruSiteTemplate(
      name: 'Danbooru',
      type: BooruType.danbooru,
      baseUrl: 'https://danbooru.donmai.us',
      icon: Icons.photo_library,
      color: Colors.blue,
      description: 'danbooru.donmai.us',
    ),
    BooruSiteTemplate(
      name: 'Gelbooru',
      type: BooruType.gelbooruV2,
      baseUrl: 'https://gelbooru.com',
      icon: Icons.image,
      color: Colors.orange,
      description: 'gelbooru.com',
    ),
    BooruSiteTemplate(
      name: 'Safebooru',
      type: BooruType.safebooru,
      baseUrl: 'https://safebooru.org',
      icon: Icons.shield,
      color: Colors.green,
      description: 'safebooru.org',
    ),
    BooruSiteTemplate(
      name: 'yande.re',
      type: BooruType.moebooru,
      baseUrl: 'https://yande.re',
      icon: Icons.auto_awesome,
      color: Colors.pink,
      description: 'yande.re / konachan.com',
    ),
    BooruSiteTemplate(
      name: 'Konachan',
      type: BooruType.moebooru,
      baseUrl: 'https://konachan.com',
      icon: Icons.auto_awesome,
      color: Colors.purple,
      description: 'konachan.com',
    ),
    BooruSiteTemplate(
      name: 'e621',
      type: BooruType.e621,
      baseUrl: 'https://e621.net',
      icon: Icons.pets,
      color: Colors.brown,
      description: 'e621.net',
    ),
    BooruSiteTemplate(
      name: 'Sankaku',
      type: BooruType.sankaku,
      baseUrl: 'https://chan.sankakucomplex.com',
      icon: Icons.lens_blur,
      color: Colors.red,
      description: 'chan.sankakucomplex.com',
    ),
    BooruSiteTemplate(
      name: 'Zerochan',
      type: BooruType.zerochan,
      baseUrl: 'https://www.zerochan.net',
      icon: Icons.filter_vintage,
      color: Colors.teal,
      description: 'zerochan.net',
    ),
    BooruSiteTemplate(
      name: 'Rule 34',
      type: BooruType.rule34,
      baseUrl: 'https://api.rule34.xxx',
      icon: Icons.warning_amber,
      color: Colors.deepOrange,
      description: 'api.rule34.xxx',
    ),
    BooruSiteTemplate(
      name: 'Anime-Pictures',
      type: BooruType.animePictures,
      baseUrl: 'https://anime-pictures.net',
      icon: Icons.palette,
      color: Colors.indigo,
      description: 'anime-pictures.net',
    ),
    BooruSiteTemplate(
      name: 'E-Shuushuu',
      type: BooruType.eshuushuu,
      baseUrl: 'https://e-shuushuu.net',
      icon: Icons.collections,
      color: Colors.cyan,
      description: 'e-shuushuu.net',
    ),
  ];

  static BooruSiteTemplate? findByType(BooruType type) {
    try {
      return all.firstWhere((t) => t.type == type);
    } catch (_) {
      return null;
    }
  }
}
