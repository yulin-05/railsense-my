import 'package:flutter/material.dart';

import '../../models/railway_system.dart';
import '../../models/station_facilities.dart';
import '../../services/government_data_service.dart';

class RailwaySystemDetailScreen extends StatefulWidget {
  const RailwaySystemDetailScreen({super.key, required this.stats});

  final RailwaySystemStats stats;

  @override
  State<RailwaySystemDetailScreen> createState() =>
      _RailwaySystemDetailScreenState();
}

class _RailwaySystemDetailScreenState extends State<RailwaySystemDetailScreen> {
  final GovernmentDataService _dataService = const GovernmentDataService();
  late Future<List<StationReference>> _stationsFuture;

  String? _selectedStationCode;

  bool _sortAscending = true;

  final Set<_StationFilter> _selectedFilters = {};

  @override
  void initState() {
    super.initState();
    _stationsFuture = _dataService.loadStationFacilities();
  }

  Future<void> _refresh() async {
    setState(() {
      _stationsFuture = _dataService.loadStationFacilities();
    });
  }

  void _toggleStation(String code) {
    setState(() {
      _selectedStationCode = _selectedStationCode == code ? null : code;
    });
  }

  void _toggleFilter(_StationFilter filter) {
    setState(() {
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }
    });
  }

  bool _matchesFilters(StationReference station) {
    for (final filter in _selectedFilters) {
      switch (filter) {
        case _StationFilter.wheelchairAccessible:
          if (!station.facilities.wheelchairAccessible) return false;
          break;
        case _StationFilter.toilet:
          if (station.facilities.toilet != true) return false;
          break;
        case _StationFilter.surau:
          if (station.facilities.surau != true) return false;
          break;
        case _StationFilter.parkAndRide:
          if (station.facilities.parkAndRide != true) return false;
          break;
        case _StationFilter.feederBus:
          if (station.facilities.feederBus != true) return false;
          break;
        case _StationFilter.hasInterchange:
          if (station.interchange.isEmpty) return false;
          break;
      }
    }
    return true;
  }

  Color get _levelColor {
    switch (widget.stats.crowdLevel) {
      case SystemCrowdLevel.crowded:
        return Colors.red;
      case SystemCrowdLevel.moderate:
        return Colors.orange;
      case SystemCrowdLevel.light:
        return Colors.green;
      case SystemCrowdLevel.noData:
        return Colors.grey;
    }
  }

  String get _levelLabel {
    switch (widget.stats.crowdLevel) {
      case SystemCrowdLevel.crowded:
        return 'Crowded';
      case SystemCrowdLevel.moderate:
        return 'Moderate';
      case SystemCrowdLevel.light:
        return 'Light';
      case SystemCrowdLevel.noData:
        return 'No data';
    }
  }

  Widget _buildHeader(BuildContext context, RailwaySystem system) {
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
              Icons.train_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  system.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  system.fullName,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final system = widget.stats.system;
    final primary = Theme.of(context).colorScheme.primary;

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

          final allStations = snapshot.data ?? [];
          final systemStations =
              allStations
                  .where((s) => system.lines.contains(s.line))
                  .where(_matchesFilters)
                  .toList()
                ..sort(
                  (a, b) => _sortAscending
                      ? a.name.compareTo(b.name)
                      : b.name.compareTo(a.name),
                );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(context, system),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(system),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'STATIONS (${systemStations.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(
                              () => _sortAscending = !_sortAscending,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _sortAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Name',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final filter in _StationFilter.values)
                            FilterChip(
                              avatar: Icon(_filterIcon(filter), size: 16),
                              label: Text(
                                _filterLabel(filter),
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: _selectedFilters.contains(filter),
                              onSelected: (_) => _toggleFilter(filter),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          if (_selectedFilters.isNotEmpty)
                            ActionChip(
                              avatar: const Icon(Icons.clear, size: 16),
                              label: const Text(
                                'Clear',
                                style: TextStyle(fontSize: 11),
                              ),
                              onPressed: () =>
                                  setState(() => _selectedFilters.clear()),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (systemStations.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _selectedFilters.isEmpty
                                ? 'No stations from this system appear in the '
                                      'current OD dataset.'
                                : 'No stations match the selected filters.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        ...systemStations.map(
                          (s) => _buildStationTile(s, primary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(RailwaySystem system) {
    final stats = widget.stats;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _levelColor.withValues(alpha: 0.12),
                  child: Icon(Icons.train_rounded, color: _levelColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        system.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${system.lines.length} lines · '
                        '${widget.stats.stationCount} listed stations',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _levelColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Estimated: $_levelLabel',
                        style: TextStyle(
                          color: _levelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (stats.legCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'avg ${stats.averageRidership.round()} per OD record',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  system.operatingHours,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'LINES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...system.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: _levelColor),
                    const SizedBox(width: 8),
                    Text(line),
                  ],
                ),
              ),
            ),
            if (stats.legCount > 0) ...[
              const Divider(height: 24),
              Text(
                'Based on ${stats.legCount} OD records from Government Open Data: '
                'average ${stats.averageRidership.round()} passengers per OD record.',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStationTile(StationReference station, Color primary) {
    final hasInterchange = station.interchange.isNotEmpty;
    final isSelected = _selectedStationCode == station.code;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? primary : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _toggleStation(station.code),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : hasInterchange
                        ? Colors.indigo.withValues(alpha: 0.12)
                        : Colors.blueGrey.withValues(alpha: 0.08),
                    child: Icon(
                      hasInterchange
                          ? Icons.transfer_within_a_station
                          : Icons.train,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : hasInterchange
                          ? Colors.indigo
                          : Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : onSurface,
                          ),
                        ),
                        Text(
                          hasInterchange
                              ? 'Interchange · ${station.interchange.map((i) => i.line).join(', ')}'
                              : station.code,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.white70
                                : hasInterchange
                                ? Colors.indigo
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected ? Icons.expand_less : Icons.expand_more,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ],
              ),
              if (isSelected) ...[
                Divider(height: 20, color: Colors.white.withValues(alpha: 0.3)),
                Text(
                  'FACILITIES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 6),
                _buildFacilities(station, isSelected: true),
                const SizedBox(height: 12),
                Text(
                  'INTERCHANGE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 6),
                _buildInterchange(station, isSelected: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacilities(StationReference station, {bool isSelected = false}) {
    final f = station.facilities;
    final chips = <Widget>[
      if (f.wheelchairAccessible)
        _facilityChip(Icons.accessible, 'Wheelchair accessible', isSelected),
      if (f.parkAndRide == true)
        _facilityChip(Icons.local_parking, 'Park & Ride', isSelected),
      if (f.feederBus == true)
        _facilityChip(Icons.directions_bus, 'Feeder Bus', isSelected),
      if (f.toilet == true) _facilityChip(Icons.wc, 'Toilet', isSelected),
      if (f.surau == true) _facilityChip(Icons.mosque, 'Surau', isSelected),
    ];

    if (chips.isEmpty) {
      return Text(
        'Not available yet',
        style: TextStyle(
          color: isSelected ? Colors.white70 : Colors.grey,
          fontSize: 12,
        ),
      );
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _facilityChip(IconData icon, String label, bool isSelected) {
    final foreground = isSelected ? Colors.white : Colors.blueGrey.shade700;
    final background = isSelected
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.blueGrey.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: Colors.white.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterchange(
    StationReference station, {
    bool isSelected = false,
  }) {
    if (station.interchange.isEmpty) {
      return Text(
        'No interchange · single line station',
        style: TextStyle(
          color: isSelected ? Colors.white70 : Colors.grey,
          fontSize: 12,
        ),
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
                  Icon(
                    Icons.transfer_within_a_station,
                    size: 14,
                    color: isSelected ? Colors.white : Colors.indigo,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ic.line} (${ic.name})',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          ic.transferType,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white70 : Colors.grey,
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
}

enum _StationFilter {
  wheelchairAccessible,
  toilet,
  surau,
  parkAndRide,
  feederBus,
  hasInterchange,
}

String _filterLabel(_StationFilter filter) {
  switch (filter) {
    case _StationFilter.wheelchairAccessible:
      return 'Wheelchair accessible';
    case _StationFilter.toilet:
      return 'Toilet';
    case _StationFilter.surau:
      return 'Surau';
    case _StationFilter.parkAndRide:
      return 'Park & Ride';
    case _StationFilter.feederBus:
      return 'Feeder Bus';
    case _StationFilter.hasInterchange:
      return 'Interchange';
  }
}

IconData _filterIcon(_StationFilter filter) {
  switch (filter) {
    case _StationFilter.wheelchairAccessible:
      return Icons.accessible;
    case _StationFilter.toilet:
      return Icons.wc;
    case _StationFilter.surau:
      return Icons.mosque;
    case _StationFilter.parkAndRide:
      return Icons.local_parking;
    case _StationFilter.feederBus:
      return Icons.directions_bus;
    case _StationFilter.hasInterchange:
      return Icons.transfer_within_a_station;
  }
}
