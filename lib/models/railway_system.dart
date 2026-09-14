import 'route_ridership.dart';

class RailwaySystem {
  const RailwaySystem({
    required this.id,
    required this.name,
    required this.fullName,
    required this.lines,
    required this.operatingHours,
    required this.stationCodePrefixes,
  });

  final String id;
  final String name;
  final String fullName;
  final List<String> lines;
  final String operatingHours;
  final List<String> stationCodePrefixes;

  static const List<RailwaySystem> all = [
    RailwaySystem(
      id: 'mrt',
      name: 'MRT',
      fullName: 'Mass Rapid Transit',
      lines: ['Kajang Line', 'Putrajaya Line'],
      operatingHours: '6:00 AM – 12:00 AM',
      stationCodePrefixes: ['KG', 'PYL'],
    ),
    RailwaySystem(
      id: 'lrt',
      name: 'LRT',
      fullName: 'Light Rail Transit',
      lines: ['Kelana Jaya Line', 'Ampang Line', 'Sri Petaling Line'],
      operatingHours: '6:00 AM – 12:00 AM',
      stationCodePrefixes: ['KJ', 'AG', 'SP'],
    ),
    RailwaySystem(
      id: 'monorail',
      name: 'Monorail',
      fullName: 'KL Monorail',
      lines: ['KL Monorail Line'],
      operatingHours: '6:00 AM – 11:30 PM',
      stationCodePrefixes: ['MR'],
    ),
  ];
}

enum SystemCrowdLevel { light, moderate, crowded, noData }

class RailwaySystemStats {
  const RailwaySystemStats({
    required this.system,
    required this.averageRidership,
    required this.legCount,
    required this.stationCount,
    required this.crowdLevel,
  });

  final RailwaySystem system;
  final double averageRidership;
  final int legCount;

  final int stationCount;

  final SystemCrowdLevel crowdLevel;

  static List<RailwaySystemStats> fromRoutes(List<RouteRidership> routes) {
    return RailwaySystem.all.map((system) {
      final legs = routes.where((route) {
        return system.stationCodePrefixes.contains(_prefixOf(route.origin));
      }).toList();

      final stationCodes = <String>{};

      for (final route in routes) {
        for (final station in [route.origin, route.destination]) {
          if (system.stationCodePrefixes.contains(_prefixOf(station))) {
            stationCodes.add(_codeOf(station));
          }
        }
      }

      if (legs.isEmpty) {
        return RailwaySystemStats(
          system: system,
          averageRidership: 0,
          legCount: 0,
          stationCount: stationCodes.length,
          crowdLevel: SystemCrowdLevel.noData,
        );
      }

      final total = legs.fold<int>(0, (sum, route) => sum + route.ridership);

      final average = total / legs.length;

      return RailwaySystemStats(
        system: system,
        averageRidership: average,
        legCount: legs.length,
        stationCount: stationCodes.length,
        crowdLevel: _levelFor(average.roundToDouble()),
      );
    }).toList();
  }

  static String _prefixOf(String raw) {
    final match = RegExp(r'^([A-Za-z]+)').firstMatch(raw.trim());
    return match?.group(1)?.toUpperCase() ?? '';
  }

  static String _codeOf(String raw) {
    return raw.split(':').first.trim().toUpperCase();
  }

  static SystemCrowdLevel _levelFor(double averageRidership) {
    if (averageRidership >= 50) {
      return SystemCrowdLevel.crowded;
    }

    if (averageRidership >= 33) {
      return SystemCrowdLevel.moderate;
    }

    return SystemCrowdLevel.light;
  }
}
