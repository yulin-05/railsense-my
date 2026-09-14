import 'package:flutter/material.dart';

import '../../models/route_ridership.dart';
import '../../models/station_facilities.dart';
import '../../models/railway_system.dart';
import '../../services/government_data_service.dart';
import '../../services/favourite_route_service.dart';
import '../../models/route_reference.dart';
import 'route_detail_screen.dart';

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  final GovernmentDataService _dataService = const GovernmentDataService();
  final FavouriteRouteService _favouriteService = FavouriteRouteService();
  late Future<_ExplorerData> _dataFuture;

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  List<RouteRidership> _resultsToShow = [];
  bool _hasSearched = false;
  final Set<String> _favouriteRouteKeys = {};

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _loadFavouriteKeys();
  }

  Future<_ExplorerData> _loadData() async {
    final results = await Future.wait([
      _dataService.loadRapidRailOdRidership(),
      _dataService.loadStationFacilities(),
    ]);
    return _ExplorerData(
      routes: results[0] as List<RouteRidership>,
      stationFacilities: results[1] as List<StationReference>,
    );
  }

  Future<void> _loadFavouriteKeys() async {
    try {
      final favourites = await _favouriteService.getFavourites();
      if (!mounted) return;
      setState(() {
        _favouriteRouteKeys
          ..clear()
          ..addAll(favourites.map((f) => '${f.origin}->${f.destination}'));
      });
    } catch (e) {
      debugPrint('Failed to load favourite routes: $e');
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _loadData();
      _resultsToShow = [];
      _hasSearched = false;
    });
    await _loadFavouriteKeys();
  }

  void _swapOriginDestination() {
    setState(() {
      final temp = _originController.text;
      _originController.text = _destinationController.text;
      _destinationController.text = temp;

      _hasSearched = false;
      _resultsToShow = [];
    });
  }

  List<RouteRidership> _filterRoutes(
    List<RouteRidership> routes,
    Map<String, String> codeByLabel,
  ) {
    final originQuery = _originController.text.trim();
    final destinationQuery = _destinationController.text.trim();

    if (originQuery.isEmpty && destinationQuery.isEmpty) {
      return routes;
    }

    final originCode = codeByLabel[originQuery];
    final destinationCode = codeByLabel[destinationQuery];

    return routes.where((route) {
      final matchesOrigin =
          originQuery.isEmpty ||
          (originCode != null
              ? _codeOf(route.origin) == originCode
              : route.originName.toLowerCase() == originQuery.toLowerCase());
      final matchesDestination =
          destinationQuery.isEmpty ||
          (destinationCode != null
              ? _codeOf(route.destination) == destinationCode
              : route.destinationName.toLowerCase() ==
                    destinationQuery.toLowerCase());
      return matchesOrigin && matchesDestination;
    }).toList();
  }

  void _onSearch(
    List<RouteRidership> allRoutes,
    Map<String, String> codeByLabel,
  ) {
    if (_originController.text.trim().isEmpty &&
        _destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an origin and/or destination first'),
        ),
      );
      return;
    }

    final results = _filterRoutes(allRoutes, codeByLabel)
      ..sort((a, b) => b.ridership.compareTo(a.ridership));

    setState(() {
      _hasSearched = true;
      _resultsToShow = results;
    });
  }

  String _lineFor(RouteRidership route) {
    return route.originLine == route.destinationLine
        ? route.originLine
        : '${route.originLine} → ${route.destinationLine}';
  }

  Future<void> _toggleFavourite(RouteRidership route) async {
    final key = route.routeKey;
    final wasFavourite = _favouriteRouteKeys.contains(key);

    setState(() {
      if (wasFavourite) {
        _favouriteRouteKeys.remove(key);
      } else {
        _favouriteRouteKeys.add(key);
      }
    });

    try {
      if (wasFavourite) {
        await _favouriteService.removeFavouriteByRoute(
          origin: route.origin,
          destination: route.destination,
          line: _lineFor(route),
        );
      } else {
        await _favouriteService.addFavourite(
          origin: route.origin,
          destination: route.destination,
          line: _lineFor(route),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasFavourite ? 'Removed from favourites' : 'Saved to favourites',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasFavourite) {
          _favouriteRouteKeys.add(key);
        } else {
          _favouriteRouteKeys.remove(key);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update favourite: $e')));
    }
  }

  void _openRouteDetails(RouteRidership route) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RouteDetailScreen(
          route: route,
          isFavourite: _favouriteRouteKeys.contains(route.routeKey),
          onToggleFavourite: _toggleFavourite,
        ),
      ),
    );
  }

  _CrowdLevel _estimateCrowdLevel(int ridership) {
    if (ridership >= 1500) return _CrowdLevel.crowded;
    if (ridership >= 500) return _CrowdLevel.moderate;
    return _CrowdLevel.light;
  }

  String _codeOf(String raw) {
    final value = raw.trim().toUpperCase();

    if (RegExp(r'^[A-Z]{2,4}\d+$').hasMatch(value)) {
      return value;
    }

    if (value.contains(':')) {
      return value.split(':').first.trim();
    }

    return value;
  }

  String _operatingHoursFor(String rawStationCode) {
    final prefix =
        RegExp(
          r'^([A-Za-z]+)',
        ).firstMatch(rawStationCode.trim())?.group(1)?.toUpperCase() ??
        '';
    for (final system in RailwaySystem.all) {
      if (system.stationCodePrefixes.contains(prefix)) {
        return system.operatingHours;
      }
    }
    return '6:00 AM – 12:00 AM';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: FutureBuilder<_ExplorerData>(
          future: _dataFuture,
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
                        'Unable to load route data\n${snapshot.error}',
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

            final allRoutes = snapshot.data?.routes ?? [];
            final stationFacilities = snapshot.data?.stationFacilities ?? [];

            final stationRefByCode = <String, StationReference>{
              for (final s in stationFacilities) s.code: s,
            };

            if (allRoutes.isEmpty) {
              return const Center(child: Text('No route information found'));
            }

            final popularRoutes = [...allRoutes]
              ..sort((a, b) => b.ridership.compareTo(a.ridership));
            final topPopular = popularRoutes.take(4).toList();

            final codesByName = <String, List<StationReference>>{};
            for (final s in stationFacilities) {
              codesByName.putIfAbsent(s.name, () => []).add(s);
            }

            final codeByLabel = <String, String>{};
            for (final entry in codesByName.entries) {
              final matches = entry.value;
              if (matches.length == 1) {
                codeByLabel[entry.key] = matches.first.code;
              } else {
                for (final s in matches) {
                  codeByLabel['${s.name} (${s.line})'] = s.code;
                }
              }
            }
            final sortedStationLabels = codeByLabel.keys.toList()..sort();

            final resultsForDisplay = _hasSearched
                ? _resultsToShow
                : <RouteRidership>[];
            final searchedButNoResults = _hasSearched && _resultsToShow.isEmpty;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(primary),
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildFindRouteCard(
                        primary,
                        allRoutes,
                        sortedStationLabels,
                        codeByLabel,
                      ),
                    ),
                  ),
                  if (searchedButNoResults)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Text(
                        'No route matching your criteria found.\nPlease try other station names.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (resultsForDisplay.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        '${resultsForDisplay.length} matching routes',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ...resultsForDisplay.map(
                    (route) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildResultCard(
                        route,
                        primary,
                        stationFacilities,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      'Popular Routes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...topPopular.asMap().entries.map(
                    (entry) => _buildPopularRouteTile(
                      rank: entry.key + 1,
                      route: entry.value,
                      primary: primary,
                    ),
                  ),
                  if (resultsForDisplay.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: _buildStationInfoCard(
                        resultsForDisplay.first,
                        primary,
                        stationRefByCode,
                        focusOnDestination:
                            _destinationController.text.trim().isNotEmpty &&
                            _originController.text.trim().isEmpty,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primary.withValues(alpha: 0.8)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route Explorer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Find less crowded routes · Malaysia Open Data',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFindRouteCard(
    Color primary,
    List<RouteRidership> allRoutes,
    List<String> stationOptions,
    Map<String, String> codeByLabel,
  ) {
    return Card(
      margin: const EdgeInsets.only(top: 50),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Find Route',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.centerRight,
              children: [
                Column(
                  children: [
                    _buildPillField(
                      label: 'FROM',
                      controller: _originController,
                      focusNode: _originFocusNode,
                      stationOptions: stationOptions,
                    ),
                    const SizedBox(height: 10),
                    _buildPillField(
                      label: 'TO',
                      controller: _destinationController,
                      focusNode: _destinationFocusNode,
                      stationOptions: stationOptions,
                    ),
                  ],
                ),
                Positioned(
                  right: 4,
                  child: CircleAvatar(
                    backgroundColor: primary,
                    child: IconButton(
                      icon: const Icon(Icons.swap_vert, color: Colors.white),
                      tooltip: 'Swap origin and destination',
                      onPressed: _swapOriginDestination,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _onSearch(allRoutes, codeByLabel),
                child: const Text(
                  'Search Route',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required List<String> stationOptions,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 18,
            color: Colors.blueGrey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Autocomplete<String>(
                  textEditingController: controller,
                  focusNode: focusNode,
                  optionsBuilder: (TextEditingValue value) {
                    if (value.text.isEmpty) {
                      return stationOptions;
                    }
                    return stationOptions.where(
                      (station) => station.toLowerCase().contains(
                        value.text.toLowerCase(),
                      ),
                    );
                  },
                  onSelected: (String selection) {
                    setState(() {
                      _hasSearched = false;
                      _resultsToShow = [];
                    });
                  },
                  fieldViewBuilder:
                      (context, fieldController, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: fieldController,
                          focusNode: focusNode,
                          onChanged: (_) {
                            setState(() {
                              _hasSearched = false;
                              _resultsToShow = [];
                            });
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Select station',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 220,
                            minWidth: 260,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.train, size: 18),
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
    RouteRidership route,
    Color primary,
    List<StationReference> stationFacilities,
  ) {
    final crowd = _estimateCrowdLevel(route.ridership);
    final reference = RouteReference.estimate(route, stationFacilities);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.directions_railway,
                      size: 18,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        route.originLine == route.destinationLine
                            ? route.originLine
                            : '${route.originLine} → ${route.destinationLine}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildCrowdTag(crowd),
              ],
            ),
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FROM',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        route.originName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'TO',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        route.destinationName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${route.ridership}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: primary,
                      ),
                    ),
                    const Text(
                      'passengers/day',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openRouteDetails(route),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('View Route Details'),
              ),
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final isFavourite = _favouriteRouteKeys.contains(
                  route.routeKey,
                );
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleFavourite(route),
                    icon: Icon(
                      isFavourite ? Icons.bookmark : Icons.bookmark_border,
                      color: isFavourite ? primary : null,
                    ),
                    label: Text(
                      isFavourite
                          ? 'Saved to Favourites'
                          : 'Save to Favourites',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  Widget _buildPopularRouteTile({
    required int rank,
    required RouteRidership route,
    required Color primary,
  }) {
    final crowd = _estimateCrowdLevel(route.ridership);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          onTap: () => setState(() {
            _hasSearched = true;
            _resultsToShow = [route];
          }),
          leading: CircleAvatar(
            backgroundColor: primary,
            child: Text('$rank', style: const TextStyle(color: Colors.white)),
          ),
          title: Text(
            '${route.originName} → ${route.destinationName}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Align(
            alignment: Alignment.centerLeft,
            child: _buildCrowdTag(crowd),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${route.ridership}',
                style: TextStyle(fontWeight: FontWeight.bold, color: primary),
              ),
              const Text(
                'pax/day',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationInfoCard(
    RouteRidership route,
    Color primary,
    Map<String, StationReference> stationRefByCode, {
    bool focusOnDestination = false,
  }) {
    final stationName = focusOnDestination
        ? route.destinationName
        : route.originName;
    final stationLine = focusOnDestination
        ? route.destinationLine
        : route.originLine;
    final stationRaw = focusOnDestination ? route.destination : route.origin;
    final station = stationRefByCode[_codeOf(stationRaw)];
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
                Icon(Icons.location_on, color: primary),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Station Info',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(stationName, style: TextStyle(color: onSurface)),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            _stationInfoRow('Railway', stationLine),
            _stationInfoRow('Hours', _operatingHoursFor(stationRaw)),
            const SizedBox(height: 10),
            const Text(
              'FACILITIES',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            _buildFacilities(station),
            const SizedBox(height: 14),
            const Text(
              'INTERCHANGE',
              style: TextStyle(
                fontSize: 10,
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

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _facilityChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.blueGrey),
      label: Text(label, style: const TextStyle(fontSize: 11)),
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
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: station.interchange
          .map(
            (ic) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.transfer_within_a_station,
                    size: 16,
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
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          ic.transferType,
                          style: const TextStyle(
                            fontSize: 11,
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

  Widget _stationInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey)),
          Text(
            value,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _ExplorerData {
  const _ExplorerData({required this.routes, required this.stationFacilities});

  final List<RouteRidership> routes;
  final List<StationReference> stationFacilities;
}

enum _CrowdLevel { light, moderate, crowded }
