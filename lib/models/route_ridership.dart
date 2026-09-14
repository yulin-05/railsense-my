class RouteRidership {
  final String origin;
  final String destination;
  final DateTime date;
  final int ridership;

  RouteRidership({
    required this.origin,
    required this.destination,
    required this.date,
    required this.ridership,
  });

  factory RouteRidership.fromJson(Map<String, dynamic> json) {
    return RouteRidership(
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      ridership: (json['ridership'] as num?)?.toInt() ?? 0,
    );
  }

  String get originName => _nameFrom(origin);
  String get destinationName => _nameFrom(destination);

  static String _nameFrom(String raw) {
    final parts = raw.split(':');
    return parts.length > 1 ? parts[1].trim() : raw;
  }

  static const Map<String, String> _lineCodeMap = {
    'KJ': 'Kelana Jaya Line',
    'AG': 'Ampang Line',
    'SP': 'Sri Petaling Line',
    'KG': 'Kajang Line',
    'PY': 'Putrajaya Line',
    'PYL': 'Putrajaya Line',
    'MR': 'Monorail Line',
  };

  String get originLine => _lineFrom(origin);
  String get destinationLine => _lineFrom(destination);

  static String _lineFrom(String raw) {
    final match = RegExp(r'^([A-Za-z]+)').firstMatch(raw.trim());
    final code = match?.group(1)?.toUpperCase();
    return _lineCodeMap[code] ?? 'Unknown Line';
  }

  String get routeKey => '$origin->$destination';
}
