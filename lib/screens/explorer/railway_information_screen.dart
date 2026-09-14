import 'package:flutter/material.dart';

import '../../models/railway_system.dart';
import '../../models/route_ridership.dart';
import '../../services/government_data_service.dart';
import 'railway_system_detail_screen.dart';

class RailwayInformationScreen extends StatefulWidget {
  const RailwayInformationScreen({super.key});

  @override
  State<RailwayInformationScreen> createState() =>
      _RailwayInformationScreenState();
}

class _RailwayInformationScreenState extends State<RailwayInformationScreen> {
  final GovernmentDataService _dataService = const GovernmentDataService();
  late Future<List<RouteRidership>> _routesFuture;

  String? _expandedSystemId = RailwaySystem.all.first.id;

  @override
  void initState() {
    super.initState();
    _routesFuture = _dataService.loadRapidRailOdRidership();
  }

  Future<void> _refresh() async {
    setState(() {
      _routesFuture = _dataService.loadRapidRailOdRidership();
    });
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
                  'Railway Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'MRT, LRT, and Monorail systems',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
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
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: FutureBuilder<List<RouteRidership>>(
        future: _routesFuture,
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
                      'Unable to load railway data\n${snapshot.error}',
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

          final routes = snapshot.data ?? [];
          if (routes.isEmpty) {
            return const Center(child: Text('No route information found'));
          }

          final stats = RailwaySystemStats.fromRoutes(routes);
          final maxAverage = stats.fold<double>(
            0,
            (max, s) => s.averageRidership > max ? s.averageRidership : max,
          );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated from historical Government Open Data. '
                        'Not real-time train occupancy.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ...stats.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SystemCard(
                            stats: s,
                            maxAverage: maxAverage,
                            primary: primary,
                            expanded: _expandedSystemId == s.system.id,
                            onToggle: () => setState(() {
                              _expandedSystemId =
                                  _expandedSystemId == s.system.id
                                  ? null
                                  : s.system.id;
                            }),
                          ),
                        ),
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
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({
    required this.stats,
    required this.maxAverage,
    required this.primary,
    required this.expanded,
    required this.onToggle,
  });

  final RailwaySystemStats stats;
  final double maxAverage;
  final Color primary;
  final bool expanded;
  final VoidCallback onToggle;

  Color get _levelColor {
    switch (stats.crowdLevel) {
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
    switch (stats.crowdLevel) {
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

  IconData get _systemIcon {
    switch (stats.system.id) {
      case 'mrt':
        return Icons.directions_railway_rounded;
      case 'lrt':
        return Icons.subway_rounded;
      case 'monorail':
        return Icons.tram_rounded;
      default:
        return Icons.train_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = stats.system;
    final relativePercent = maxAverage <= 0
        ? 0.0
        : (stats.averageRidership / maxAverage).clamp(0.0, 1.0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _levelColor.withValues(alpha: 0.35), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _levelColor.withValues(alpha: 0.12),
                    child: Icon(_systemIcon, color: _levelColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              system.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _LevelBadge(label: _levelLabel, color: _levelColor),
                            if (stats.legCount > 0) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'avg ${stats.averageRidership.round()} per OD record',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          system.fullName,
                          style: TextStyle(color: _levelColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${system.lines.length} lines · '
                '${stats.stationCount} listed stations',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 4),
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
              if (expanded) ...[
                const Divider(height: 24),
                const Text(
                  'ESTIMATED SYSTEM CROWD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Based on ${stats.legCount} OD records from Government Open Data',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _IntensityBar(percent: relativePercent, color: _levelColor),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: _levelColor),
                    const SizedBox(width: 4),
                    Text(
                      'Estimated: $_levelLabel',
                      style: TextStyle(
                        color: _levelColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (stats.legCount > 0) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '· avg ${stats.averageRidership.round()} per OD record '
                          '(${stats.legCount} records)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
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
                        Icon(Icons.circle, size: 8, color: primary),
                        const SizedBox(width: 8),
                        Text(line),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RailwaySystemDetailScreen(stats: stats),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('View Full Details'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IntensityBar extends StatelessWidget {
  const _IntensityBar({required this.percent, required this.color});

  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const segmentCount = 10;
    final filledSegments = (percent * segmentCount).round().clamp(
      0,
      segmentCount,
    );

    return Row(
      children: List.generate(segmentCount, (index) {
        final isFilled = index < filledSegments;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == segmentCount - 1 ? 0 : 3),
            height: 8,
            decoration: BoxDecoration(
              color: isFilled ? color : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
