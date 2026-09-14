class KtmbRidership {
  const KtmbRidership({
    required this.date,
    required this.service,
    required this.ridership,
  });

  final DateTime date;
  final String service;
  final int ridership;

  factory KtmbRidership.fromJson(Map<String, dynamic> json) {
    return KtmbRidership(
      date: DateTime.parse(json['date'] as String),
      service: (json['service'] as String? ?? '').trim().toLowerCase(),
      ridership: _toInt(json['ridership']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
