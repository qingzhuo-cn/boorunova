// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

class BooruTag {
  const BooruTag({
    this.serverId = '',
    this.name = '',
  });

  factory BooruTag.fromJson(Map<String, dynamic> json) => BooruTag(
        serverId: json['serverId'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  final String serverId;
  final String name;

  BooruTag copyWith({String? serverId, String? name}) => BooruTag(
        serverId: serverId ?? this.serverId,
        name: name ?? this.name,
      );

  Map<String, dynamic> toJson() => {
        'serverId': serverId,
        'name': name,
      };
}
