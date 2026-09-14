class StationFacilities {
  const StationFacilities({
    required this.wheelchairAccessible,
    required this.toilet,
    required this.surau,
    required this.parkAndRide,
    required this.feederBus,
  });

  final bool wheelchairAccessible;

  final bool? toilet;
  final bool? surau;
  final bool? parkAndRide;
  final bool? feederBus;

  factory StationFacilities.fromJson(Map<String, dynamic> json) {
    return StationFacilities(
      wheelchairAccessible: json['wheelchairAccessible'] as bool? ?? true,
      toilet: json['toilet'] as bool?,
      surau: json['surau'] as bool?,
      parkAndRide: json['parkAndRide'] as bool?,
      feederBus: json['feederBus'] as bool?,
    );
  }
}

class StationInterchange {
  const StationInterchange({
    required this.code,
    required this.name,
    required this.line,
    required this.transferType,
  });

  final String code;
  final String name;
  final String line;

  final String transferType;

  factory StationInterchange.fromJson(Map<String, dynamic> json) {
    return StationInterchange(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      line: json['line'] as String? ?? '',
      transferType: json['transferType'] as String? ?? '',
    );
  }
}

class StationReference {
  const StationReference({
    required this.code,
    required this.name,
    required this.line,
    required this.facilities,
    required this.interchange,
    this.facilitiesNote,
  });

  final String code;
  final String name;
  final String line;
  final StationFacilities facilities;

  final List<StationInterchange> interchange;

  final String? facilitiesNote;

  factory StationReference.fromJson(Map<String, dynamic> json) {
    return StationReference(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      line: json['line'] as String? ?? '',
      facilities: StationFacilities.fromJson(
        (json['facilities'] as Map<String, dynamic>?) ?? const {},
      ),
      interchange: (json['interchange'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(StationInterchange.fromJson)
          .toList(),
      facilitiesNote: json['facilitiesNote'] as String?,
    );
  }
}
