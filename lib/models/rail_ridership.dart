class RailRidership {
  const RailRidership({
    required this.date,
    required this.lrtAmpang,
    required this.lrtKelanaJaya,
    required this.mrtKajang,
    required this.mrtPutrajaya,
    required this.monorail,
    required this.komuter,
    required this.komuterUtara,
    required this.ets,
    required this.intercity,
  });

  final DateTime date;
  final int lrtAmpang;
  final int lrtKelanaJaya;
  final int mrtKajang;
  final int mrtPutrajaya;
  final int monorail;
  final int komuter;
  final int komuterUtara;
  final int ets;
  final int intercity;

  factory RailRidership.fromJson(Map<String, dynamic> json) {
    return RailRidership(
      date: DateTime.parse(json['date'] as String),

      lrtAmpang: _toInt(json['rail_lrt_ampang']),
      lrtKelanaJaya: _toInt(json['rail_lrt_kj']),
      mrtKajang: _toInt(json['rail_mrt_kajang']),
      mrtPutrajaya: _toInt(json['rail_mrt_pjy']),
      monorail: _toInt(json['rail_monorail']),
      komuter: _toInt(json['rail_komuter']),
      komuterUtara: _toInt(json['rail_komuter_utara']),
      ets: _toInt(json['rail_ets']),
      intercity: _toInt(json['rail_intercity']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  int get totalRailRidership =>
      lrtAmpang +
      lrtKelanaJaya +
      mrtKajang +
      mrtPutrajaya +
      monorail +
      komuter +
      komuterUtara +
      ets +
      intercity;
}
