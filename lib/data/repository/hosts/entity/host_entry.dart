class HostEntry {
  const HostEntry({
    required this.domain,
    required this.ip,
  });

  factory HostEntry.fromJson(Map<String, dynamic> json) => HostEntry(
        domain: json['domain'] as String,
        ip: json['ip'] as String,
      );

  final String domain;
  final String ip;

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'ip': ip,
      };
}
