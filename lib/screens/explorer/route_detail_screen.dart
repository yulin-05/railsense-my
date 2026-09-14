import 'package:flutter/material.dart';

import '../../models/route_ridership.dart';
import '../../models/station_facilities.dart';
import '../../services/government_data_service.dart';
import '../../models/route_reference.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    super.key,
    required this.route,
    this.isFavourite = false,
    this.onToggleFavourite,
  });

  final RouteRidership route;

  final bool isFavourite;

  final ValueChanged<RouteRidership>? onToggleFavourite;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final GovernmentDataService _dataService = const GovernmentDataService();
  late bool _isFavourite;
  late Future<List<StationReference>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    _isFavourite = widget.isFavourite;
    _stationsFuture = _dataService.loadStationFacilities();
  }

  Future<void> _refresh() async {
    setState(() {
      _stationsFuture = _dataService.loadStationFacilities();
    });
  }

  _CrowdLevel _estimateCrowdLevel(int ridership) {
    if (ridership >= 1500) return _CrowdLevel.crowded;
    if (ridership >= 500) return _CrowdLevel.moderate;
    return _CrowdLevel.light;
  }

  String _codeOf(String raw) => raw.split(':').first.trim();

  void _toggleFavourite() {
    setState(() => _isFavourite = !_isFavourite);
    widget.onToggleFavourite?.call(widget.route);
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 16,
        20,
        24,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.route_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Route Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: _toggleFavourite,
            icon: Icon(
              _isFavourite ? Icons.bookmark : Icons.bookmark_border,
              color: colorScheme.primary,
            ),
            tooltip: _isFavourite
                ? 'Remove from favourites'
                : 'Save to favourites',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final primary = Theme.of(context).colorScheme.primary;
    final crowd = _estimateCrowdLevel(route.ridership);
    final sameLine = route.originLine == route.destinationLine;

    return Scaffold(
      body: FutureBuilder<List<StationReference>>(
        future: _stationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load station data\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final stations = snapshot.data ?? [];
          final stationByCode = <String, StationReference>{
            for (final s in stations) s.code: s,
          };
          final originStation = stationByCode[_codeOf(route.origin)];
          final destStation = stationByCode[_codeOf(route.destination)];
          final reference = RouteReference.estimate(route, stations);

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildRouteHeaderCard(route, primary, crowd, sameLine),
                    const SizedBox(height: 16),
                    _buildEstimatesCard(reference),
                    const SizedBox(height: 16),
                    _buildStationCard(
                      'FROM',
                      route.originName,
                      route.originLine,
                      primary,
                      originStation,
                    ),
                    const SizedBox(height: 12),
                    _buildStationCard(
                      'TO',
                      route.destinationName,
                      route.destinationLine,
                      primary,
                      destStation,
                    ),
                    const SizedBox(height: 16),
                    _buildSourceFooter(route),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRouteHeaderCard(
    RouteRidership route,
    Color primary,
    _CrowdLevel crowd,
    bool sameLine,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.directions_railway, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sameLine
                              ? route.originLine
                              : '${route.originLine} → '
                                    '${route.destinationLine}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCrowdTag(crowd),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FROM',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        route.originName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: primary),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TO',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        route.destinationName,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${route.ridership}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                        color: primary,
                      ),
                    ),
                    const Text(
                      'passengers',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      route.date.toLocal().toString().split(' ').first,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Text(
                      'data date',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrowdTag(_CrowdLevel level) {
    late Color color;
    late String label;
    switch (level) {
      case _CrowdLevel.light:
        color = Colors.green;
        label = 'Light';
        break;
      case _CrowdLevel.moderate:
        color = Colors.orange;
        label = 'Moderate';
        break;
      case _CrowdLevel.crowded:
        color = Colors.red;
        label = 'Crowded';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 4),
          Text(
            'Estimated: $label',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimatesCard(RouteReference? reference) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.info_outline, size: 16, color: Colors.grey),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Estimated from station sequence + verified interchanges — '
                    'not official RapidKL fare/timetable data',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatChip(
                    Icons.alt_route,
                    reference != null
                        ? '${reference.stops} ${reference.stops == 1 ? 'stop' : 'stops'}'
                        : 'N/A',
                    Colors.indigo,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatChip(
                    Icons.schedule,
                    reference != null
                        ? '${reference.expectedDuration} min'
                        : 'N/A',
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatChip(
                    Icons.payments,
                    reference != null
                        ? 'RM ${reference.fee.toStringAsFixed(2)}'
                        : 'N/A',
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _buildStationCard(
    String label,
    String stationName,
    String line,
    Color primary,
    StationReference? station,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        stationName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        line,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text(
              'FACILITIES',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            _buildFacilities(station),
            const SizedBox(height: 12),
            const Text(
              'INTERCHANGE',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            _buildInterchange(station),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilities(StationReference? station) {
    if (station == null) {
      return const Text(
        'Not available yet',
        style: TextStyle(color: Colors.grey),
      );
    }

    final f = station.facilities;
    final chips = <Widget>[
      if (f.wheelchairAccessible)
        _facilityChip(Icons.accessible, 'Wheelchair accessible'),
      if (f.parkAndRide == true)
        _facilityChip(Icons.local_parking, 'Park & Ride'),
      if (f.feederBus == true)
        _facilityChip(Icons.directions_bus, 'Feeder Bus'),
      if (f.toilet == true) _facilityChip(Icons.wc, 'Toilet'),
      if (f.surau == true) _facilityChip(Icons.mosque, 'Surau'),
    ];

    if (chips.isEmpty) {
      return const Text(
        'Not available yet',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _facilityChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 14, color: Colors.blueGrey),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      backgroundColor: Colors.blueGrey.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildInterchange(StationReference? station) {
    if (station == null) {
      return const Text(
        'Not available yet',
        style: TextStyle(color: Colors.grey),
      );
    }

    if (station.interchange.isEmpty) {
      return const Text(
        'No interchange · single line station',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: station.interchange
          .map(
            (ic) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.transfer_within_a_station,
                    size: 14,
                    color: Colors.indigo,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ic.line} (${ic.name})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          ic.transferType,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSourceFooter(RouteRidership route) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 12, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'ridership_od_rapidrail_daily · data.gov.my · '
            '${route.date.toLocal().toString().split(' ').first}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

enum _CrowdLevel { light, moderate, crowded }
