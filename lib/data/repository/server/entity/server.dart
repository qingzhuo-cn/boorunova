import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:uuid/uuid.dart';

class BooruServer {
  const BooruServer({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.type,
    this.apiKey,
    this.login,
    required this.createdAt,
  });

  factory BooruServer.fromJson(Map<String, dynamic> json) => BooruServer(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        type: BooruType.fromValue(json['type'] as String),
        apiKey: json['apiKey'] as String?,
        login: json['login'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String name;
  final String baseUrl;
  final BooruType type;
  final String? apiKey;
  final String? login;
  final DateTime createdAt;

  BooruServer copyWith({
    String? id,
    String? name,
    String? baseUrl,
    BooruType? type,
    String? apiKey,
    String? login,
    DateTime? createdAt,
  }) {
    return BooruServer(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      type: type ?? this.type,
      apiKey: apiKey ?? this.apiKey,
      login: login ?? this.login,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'type': type.value,
        'apiKey': apiKey,
        'login': login,
        'createdAt': createdAt.toIso8601String(),
      };

  static BooruServer create({
    required String name,
    required String baseUrl,
    required BooruType type,
    String? apiKey,
    String? login,
  }) {
    return BooruServer(
      id: const Uuid().v4(),
      name: name,
      baseUrl: baseUrl,
      type: type,
      apiKey: apiKey,
      login: login,
      createdAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BooruServer && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
