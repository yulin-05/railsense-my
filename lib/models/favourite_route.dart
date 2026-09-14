class FavouriteRoute {
  final int id;
  final String userId;
  final String origin;
  final String destination;
  final String line;
  final DateTime createdAt;

  FavouriteRoute({
    required this.id,
    required this.userId,
    required this.origin,
    required this.destination,
    required this.line,
    required this.createdAt,
  });

  factory FavouriteRoute.fromJson(Map<String, dynamic> json) {
    return FavouriteRoute(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      line: json['line'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'origin': origin,
      'destination': destination,
      'line': line,
    };
  }
}
