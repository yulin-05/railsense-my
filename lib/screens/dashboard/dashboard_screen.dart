import 'package:flutter/material.dart';

import '../assistant/rail_assistant_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ktmb_ridership.dart';
import '../../models/rail_ridership.dart';
import '../../services/government_data_service.dart';
import '../explorer/railway_information_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onNavigate,
    this.userName = 'Traveller',
  });

  final ValueChanged<int>? onNavigate;

  final String userName;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GovernmentDataService _dataService = const GovernmentDataService();

  late Future<_DashboardData> _dashboardFuture;
  String _selectedLine = 'MRT Kajang';
  int _unreadUpdates = 2;

  static const List<String> _railwayLines = [
    'MRT Kajang',
    'LRT Kelana',
    'KTM Komuter',
  ];

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboardData();
  }

  void _retryLoading() {
    setState(() {
      _dashboardFuture = _loadDashboardData();
    });
  }

  void _openRailwayInformation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RailwayInformationScreen()),
    );
  }

  Future<void> _refreshData() async {
    final refreshedData = _loadDashboardData();
    setState(() {
      _dashboardFuture = refreshedData;
    });
    await refreshedData;
  }

  Future<_DashboardData> _loadDashboardData() async {
    final results = await Future.wait([
      _dataService.loadHeadlineRidership(),
      _dataService.loadKtmbRidership(),
    ]);

    return _DashboardData(
      headline: results[0] as List<RailRidership>,
      ktmb: results[1] as List<KtmbRidership>,
    );
  }

  String _latestDate(Iterable<DateTime> dates) {
    final dateList = dates.toList();

    if (dateList.isEmpty) {
      return 'No date';
    }

    final latest = dateList.reduce(
      (current, next) => next.isAfter(current) ? next : current,
    );

    return latest.toIso8601String().split('T').first;
  }

  _SelectedRailData? _selectedRailData(_DashboardData data) {
    if (_selectedLine == 'KTM Komuter') {
      final records =
          data.ktmb
              .where(
                (record) => record.service == 'komuter' && record.ridership > 0,
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      if (records.isEmpty) return null;
      return _SelectedRailData(
        date: records.first.date,
        ridership: records.first.ridership,
        previousRidership: records.length > 1 ? records[1].ridership : null,
      );
    }

    int valueOf(RailRidership record) =>
        _selectedLine == 'LRT Kelana' ? record.lrtKelanaJaya : record.mrtKajang;

    final records =
        data.headline.where((record) => valueOf(record) > 0).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    if (records.isEmpty) return null;
    return _SelectedRailData(
      date: records.first.date,
      ridership: valueOf(records.first),
      previousRidership: records.length > 1 ? valueOf(records[1]) : null,
    );
  }

  int get _busyBenchmark {
    switch (_selectedLine) {
      case 'LRT Kelana':
        return 400000;
      case 'KTM Komuter':
        return 180000;
      default:
        return 320000;
    }
  }

  String get _bestTravelWindow {
    switch (_selectedLine) {
      case 'LRT Kelana':
        return '11 AM–3 PM';
      case 'KTM Komuter':
        return '10 AM–4 PM';
      default:
        return '10 AM–3 PM';
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_DashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error, onRetry: _retryLoading);
          }

          final data = snapshot.data;
          if (data == null || (data.headline.isEmpty && data.ktmb.isEmpty)) {
            return const Center(child: Text('No railway data available.'));
          }

          final selectedData = _selectedRailData(data);
          final ridership = selectedData?.ridership ?? 0;
          final formattedDate = selectedData == null
              ? 'No date'
              : selectedData.date.toIso8601String().split('T').first;

          final headlineDate = _latestDate(
            data.headline.map((record) => record.date),
          );

          final ktmbDate = _latestDate(
            data.ktmb
                .where(
                  (record) =>
                      record.service == 'komuter' && record.ridership > 0,
                )
                .map((record) => record.date),
          );

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildHeader(
                  ridership: ridership,
                  formattedDate: formattedDate,
                  headlineDate: headlineDate,
                  ktmbDate: ktmbDate,
                  changePercent: selectedData?.changePercent,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: 'Data Updates'),
                      const SizedBox(height: 12),

                      _ServiceUpdateTile(
                        icon: Icons.verified_rounded,
                        iconColor: AppColors.success,
                        iconBackground: AppColors.crowdLightBackground,
                        title: 'Headline ridership available',
                        subtitle: 'Latest audited data · $headlineDate',
                        statusColor: AppColors.success,
                      ),

                      const SizedBox(height: 10),

                      _ServiceUpdateTile(
                        icon: Icons.update_rounded,
                        iconColor: AppColors.secondary,
                        iconBackground: AppColors.lightBlue,
                        title: 'KTMB Komuter data available',
                        subtitle: 'Latest daily data · $ktmbDate',
                        statusColor: AppColors.secondary,
                      ),

                      const SizedBox(height: 10),

                      _ServiceUpdateTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: AppColors.warning,
                        iconBackground: AppColors.crowdModerateBackground,
                        title: 'Live service alerts unavailable',
                        subtitle: 'No verified disruption feed is connected',
                        statusColor: AppColors.warning,
                      ),
                      const SizedBox(height: 24),

                      _buildAssistantCard(),
                      const SizedBox(height: 24),

                      _SectionTitle(title: 'Quick Access'),
                      const SizedBox(height: 12),
                      GridView.count(
                        padding: EdgeInsets.zero,
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.32,
                        children: [
                          _QuickAccessCard(
                            icon: Icons.train_rounded,
                            iconColor: AppColors.primary,
                            iconBackground: AppColors.lightBlue,
                            title: 'Railway\nInformation',
                            onTap: _openRailwayInformation,
                          ),
                          _QuickAccessCard(
                            icon: Icons.map_rounded,
                            iconColor: AppColors.secondary,
                            iconBackground: const Color(0xFFE0F2FE),
                            title: 'Route\nExplorer',
                            onTap: () => _navigateTo(1, 'Route Explorer'),
                          ),
                          _QuickAccessCard(
                            icon: Icons.bar_chart_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            iconBackground: const Color(0xFFF3E8FF),
                            title: 'Insights &\nTrends',
                            onTap: () => _navigateTo(2, 'Insights & Trends'),
                          ),
                          _QuickAccessCard(
                            icon: Icons.favorite_rounded,
                            iconColor: const Color(0xFFE91E63),
                            iconBackground: const Color(0xFFFCE7F3),
                            title: 'My\nFavourites',
                            onTap: () => _navigateTo(3, 'My Favourites'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'About this estimate',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          'Crowd level and capacity are estimates calculated '
                          'from daily Government Open Data. They are not live '
                          'train occupancy readings.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            height: 1.5,
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

  Widget _buildHeader({
    required int ridership,
    required String formattedDate,
    required String headlineDate,
    required String ktmbDate,
    required double? changePercent,
  }) {
    final hasData = ridership > 0;
    final capacity = hasData
        ? ((ridership / _busyBenchmark) * 100).round().clamp(0, 100)
        : 0;
    final crowd = _CrowdEstimate.fromCapacity(capacity, hasData: hasData);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 18,
        20,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.userName} 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Open latest updates',
                    onPressed: () => _openNotifications(headlineDate, ktmbDate),
                    style: IconButton.styleFrom(
                      fixedSize: const Size(44, 44),
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      foregroundColor: AppColors.white,
                    ),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                  if (_unreadUpdates > 0)
                    Positioned(
                      right: -1,
                      top: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_unreadUpdates',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR LINE · LATEST DATA',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedLine,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (changePercent != null) ...[
                      _TrendBadge(changePercent: changePercent),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _TrainCapacityIndicator(
                  capacity: hasData ? capacity : 0,
                  activeColor: crowd.color,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: crowd.backgroundColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '• ${crowd.label}',
                        style: TextStyle(
                          color: crowd.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      hasData ? '$capacity% estimated capacity' : 'No data',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricBox(
                        label: 'DAILY RIDERSHIP',
                        value: hasData ? _formatNumber(ridership) : 'No data',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricBox(
                        label: 'SUGGESTED OFF-PEAK',
                        value: _bestTravelWindow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _railwayLines.map((line) {
              final isSelected = _selectedLine == line;
              return ChoiceChip(
                label: Text(line),
                selected: isSelected,
                showCheckmark: false,
                backgroundColor: AppColors.secondary,
                selectedColor: AppColors.white,
                side: BorderSide(
                  color: AppColors.white.withValues(alpha: 0.65),
                  width: 1,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) {
                  setState(() => _selectedLine = line);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RailAssistantScreen(),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.78),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'RailSense Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.auto_awesome,
                          color: Colors.white70,
                          size: 15,
                        ),
                      ],
                    ),

                    SizedBox(height: 5),

                    Text(
                      'Ask about crowd levels, travel times and railway insights',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  void _navigateTo(int index, String module) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(index);
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$module will be connected during integration.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showNotifications(String headlineDate, String ktmbDate) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Latest Updates',
                        style: TextStyle(
                          color: Theme.of(sheetContext).colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _NotificationItem(
                  icon: Icons.storage_rounded,
                  iconColor: AppColors.secondary,
                  iconBackground: AppColors.lightBlue,
                  title: 'Government ridership data ready',
                  message:
                      'Headline data is available up to $headlineDate. '
                      'KTMB Komuter data is available up to $ktmbDate.',
                ),
                const SizedBox(height: 10),
                _NotificationItem(
                  icon: Icons.info_outline_rounded,
                  iconColor: AppColors.warning,
                  iconBackground: AppColors.crowdModerateBackground,
                  title: 'Service alert notice',
                  message:
                      'Rail disruption alerts are not available from the '
                      'current Government Open Data feeds. Ridership and '
                      'crowd information are estimates, not live occupancy.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openNotifications(String headlineDate, String ktmbDate) {
    if (_unreadUpdates > 0) {
      setState(() {
        _unreadUpdates = 0;
      });
    }

    _showNotifications(headlineDate, ktmbDate);
  }
}

class _DashboardData {
  const _DashboardData({required this.headline, required this.ktmb});

  final List<RailRidership> headline;
  final List<KtmbRidership> ktmb;
}

class _SelectedRailData {
  const _SelectedRailData({
    required this.date,
    required this.ridership,
    required this.previousRidership,
  });

  final DateTime date;
  final int ridership;
  final int? previousRidership;

  double? get changePercent {
    final previous = previousRidership;
    if (previous == null || previous <= 0) return null;
    return ((ridership - previous) / previous) * 100;
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.changePercent});

  final double changePercent;

  @override
  Widget build(BuildContext context) {
    final isUp = changePercent >= 0;
    final color = isUp ? AppColors.success : AppColors.error;
    final sign = isUp ? '+' : '-';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: color,
          size: 15,
        ),
        const SizedBox(width: 3),
        Text(
          '$sign${changePercent.abs().toStringAsFixed(1)}%',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ServiceUpdateTile extends StatelessWidget {
  const _ServiceUpdateTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.statusColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainCapacityIndicator extends StatelessWidget {
  const _TrainCapacityIndicator({
    required this.capacity,
    required this.activeColor,
  });

  static const int _carriageCount = 8;

  final int capacity;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final safeCapacity = capacity.clamp(0, 100);
    final filledCarriages = safeCapacity == 0
        ? 0
        : ((safeCapacity / 100) * _carriageCount).round().clamp(
            1,
            _carriageCount,
          );

    return Semantics(
      label: '$safeCapacity percent estimated capacity',
      child: SizedBox(
        height: 47,
        child: Stack(
          children: [
            Positioned(
              left: 3,
              right: 3,
              bottom: 2,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < _carriageCount; index++) ...[
                  Expanded(
                    child: _TrainCarriage(
                      isFilled: index < filledCarriages,
                      activeColor: activeColor,
                      isFirst: index == 0,
                      isLast: index == _carriageCount - 1,
                    ),
                  ),
                  if (index < _carriageCount - 1)
                    Container(
                      width: 4,
                      height: 3,
                      margin: const EdgeInsets.only(top: 18),
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainCarriage extends StatelessWidget {
  const _TrainCarriage({
    required this.isFilled,
    required this.activeColor,
    required this.isFirst,
    required this.isLast,
  });

  final bool isFilled;
  final Color activeColor;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final detailColor = isFilled
        ? Colors.white.withValues(alpha: 0.82)
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.45);

    return SizedBox(
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            height: 34,
            decoration: BoxDecoration(
              color: isFilled
                  ? activeColor
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(isFirst ? 13 : 3),
                right: Radius.circular(isLast ? 13 : 3),
              ),
              border: Border.all(
                color: isFilled
                    ? activeColor
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: detailColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(
                        child: Container(
                          width: 1,
                          color: isFilled
                              ? activeColor.withValues(alpha: 0.7)
                              : colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    height: 2,
                    decoration: BoxDecoration(
                      color: detailColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 7,
            bottom: 5,
            child: _TrainWheel(color: detailColor),
          ),
          Positioned(
            right: 7,
            bottom: 5,
            child: _TrainWheel(color: detailColor),
          ),
        ],
      ),
    );
  }
}

class _TrainWheel extends StatelessWidget {
  const _TrainWheel({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CrowdEstimate {
  const _CrowdEstimate({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  factory _CrowdEstimate.fromCapacity(int capacity, {required bool hasData}) {
    if (!hasData) {
      return const _CrowdEstimate(
        label: 'No data',
        color: AppColors.textMuted,
        backgroundColor: AppColors.surface,
      );
    }
    if (capacity < 50) {
      return const _CrowdEstimate(
        label: 'Light',
        color: AppColors.crowdLight,
        backgroundColor: AppColors.crowdLightBackground,
      );
    }
    if (capacity < 80) {
      return const _CrowdEstimate(
        label: 'Moderate',
        color: AppColors.crowdModerate,
        backgroundColor: AppColors.crowdModerateBackground,
      );
    }
    return const _CrowdEstimate(
      label: 'Crowded',
      color: AppColors.crowdCrowded,
      backgroundColor: AppColors.crowdCrowdedBackground,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load railway data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
