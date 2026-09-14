import 'route_ridership.dart';
import 'station_facilities.dart';

class RouteReference {
  const RouteReference({
    required this.stops,
    required this.expectedDuration,
    required this.fee,
    required this.transfers,
  });

  final int stops;

  final int expectedDuration;

  final double fee;

  final int transfers;

  static const double _minutesPerStop = 2.0;
  static const double _minutesPerTransfer = 6.0;
  static const double _baseFare = 1.20;
  static const double _farePerStop = 0.20;
  static const double _maxFare = 6.00;

  static RouteReference _fromPath(int stops, int transfers) {
    final duration =
        (stops * _minutesPerStop + transfers * _minutesPerTransfer + 2).round();
    final fee = (_baseFare + stops * _farePerStop).clamp(_baseFare, _maxFare);
    return RouteReference(
      stops: stops,
      expectedDuration: duration,
      fee: fee,
      transfers: transfers,
    );
  }

  static RouteReference? estimate(
    RouteRidership route,
    List<StationReference> stations,
  ) {
    final originCode = route.origin.split(':').first.trim();
    final destCode = route.destination.split(':').first.trim();

    if (originCode == destCode) {
      return const RouteReference(
        stops: 0,
        expectedDuration: 3,
        fee: 1.20,
        transfers: 0,
      );
    }

    final byCode = {for (final s in stations) s.code: s};
    if (!byCode.containsKey(originCode) || !byCode.containsKey(destCode)) {
      return null;
    }

    final byLine = <String, List<StationReference>>{};
    for (final s in stations) {
      byLine.putIfAbsent(s.line, () => []).add(s);
    }
    for (final list in byLine.values) {
      list.sort((a, b) => _numberOf(a.code).compareTo(_numberOf(b.code)));
    }

    final adjacency = <String, List<_Edge>>{};
    void addEdge(String a, String b, bool isTransfer) {
      adjacency.putIfAbsent(a, () => []).add(_Edge(b, isTransfer));
      adjacency.putIfAbsent(b, () => []).add(_Edge(a, isTransfer));
    }

    for (final list in byLine.values) {
      for (var i = 0; i < list.length - 1; i++) {
        addEdge(list[i].code, list[i + 1].code, false);
      }
    }
    for (final s in stations) {
      for (final ic in s.interchange) {
        addEdge(s.code, ic.code, true);
      }
    }

    final dist = <String, int>{originCode: 0};
    final stopsAt = <String, int>{originCode: 0};
    final transfersAt = <String, int>{originCode: 0};
    final visited = <String>{};
    final frontier = <String>{originCode};

    while (frontier.isNotEmpty) {
      final current = frontier.reduce((a, b) => dist[a]! <= dist[b]! ? a : b);
      frontier.remove(current);
      if (!visited.add(current)) continue;
      if (current == destCode) break;

      for (final edge in adjacency[current] ?? const <_Edge>[]) {
        if (visited.contains(edge.to)) continue;
        final weight = edge.isTransfer ? 4 : 1;
        final newDist = dist[current]! + weight;
        if (newDist < (dist[edge.to] ?? 1 << 30)) {
          dist[edge.to] = newDist;
          stopsAt[edge.to] = stopsAt[current]! + (edge.isTransfer ? 0 : 1);
          transfersAt[edge.to] =
              transfersAt[current]! + (edge.isTransfer ? 1 : 0);
          frontier.add(edge.to);
        }
      }
    }

    if (!stopsAt.containsKey(destCode)) return null;
    return _fromPath(stopsAt[destCode]!, transfersAt[destCode]!);
  }

  static int _numberOf(String code) {
    final match = RegExp(r'(\d+)').firstMatch(code);
    return match != null ? int.parse(match.group(1)!) : 0;
  }
}

class _Edge {
  const _Edge(this.to, this.isTransfer);
  final String to;
  final bool isTransfer;
}
