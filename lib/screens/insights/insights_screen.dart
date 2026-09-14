import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ktmb_ridership.dart';
import '../../models/rail_ridership.dart';
import '../../services/government_data_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

enum _Range { week, month }

class _InsightsScreenState extends State<InsightsScreen> {
  final GovernmentDataService _dataService = const GovernmentDataService();

  late Future<List<_DayUsage>> _future;
  _Range _range = _Range.week;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_DayUsage>> _load() async {
    final results = await Future.wait([
      _dataService.loadHeadlineRidership(),
      _dataService.loadKtmbRidership(),
    ]);
    final headline = List<RailRidership>.from(results[0] as List)
      ..sort((a, b) => a.date.compareTo(b.date));
    final ktmb = List<KtmbRidership>.from(results[1] as List);

    final byService = <String, Map<String, int>>{};
    for (final k in ktmb) {
      final serviceMap = byService.putIfAbsent(k.service, () => {});
      serviceMap[_dateKey(k.date)] = k.ridership;
    }

    return [for (final r in headline) _DayUsage.merge(r, byService)];
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.background(context),
      body: FutureBuilder<List<_DayUsage>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SafeArea(child: _LoadingView());
          }
          if (snapshot.hasError) {
            return SafeArea(
              child: _ErrorView(
                message: '${snapshot.error}',
                onRetry: _refresh,
              ),
            );
          }

          final data = snapshot.data ?? const [];
          if (data.isEmpty) {
            return SafeArea(child: _EmptyView(onRetry: _refresh));
          }

          return RefreshIndicator(
            color: _Palette.headerBlue(context),
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header()),
                SliverToBoxAdapter(
                  child: _RangeSelector(
                    range: _range,
                    onChanged: (r) => setState(() => _range = r),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TrendCard(data: data, range: _range),
                ),
                SliverToBoxAdapter(
                  child: _CompareCard(data: data, range: _range),
                ),
                SliverToBoxAdapter(
                  child: _TopUsageCard(data: data, range: _range),
                ),
                SliverToBoxAdapter(child: _InsightCard(data: data)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _DayUsage {
  const _DayUsage({
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
    required this.hasKtmbOverride,
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

  final bool hasKtmbOverride;

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

  factory _DayUsage.merge(
    RailRidership r,
    Map<String, Map<String, int>> byService,
  ) {
    final key = _dateKey(r.date);

    int? lookup(List<String> aliases) {
      for (final a in aliases) {
        final v = byService[a]?[key];
        if (v != null) return v;
      }
      return null;
    }

    final komuterOverride = lookup(['komuter']);
    final komuterUtaraOverride = lookup(['komuter_utara', 'komuterutara']);
    final etsOverride = lookup(['ets']);
    final intercityOverride = lookup(['intercity']);

    return _DayUsage(
      date: r.date,
      lrtAmpang: r.lrtAmpang,
      lrtKelanaJaya: r.lrtKelanaJaya,
      mrtKajang: r.mrtKajang,
      mrtPutrajaya: r.mrtPutrajaya,
      monorail: r.monorail,
      komuter: komuterOverride ?? r.komuter,
      komuterUtara: komuterUtaraOverride ?? r.komuterUtara,
      ets: etsOverride ?? r.ets,
      intercity: intercityOverride ?? r.intercity,
      hasKtmbOverride:
          komuterOverride != null ||
          komuterUtaraOverride != null ||
          etsOverride != null ||
          intercityOverride != null,
    );
  }
}

class _Palette {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) {
    return isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  }

  static Color surface(BuildContext context) {
    return isDark(context) ? const Color(0xFF1E293B) : Colors.white;
  }

  static Color headerBlue(BuildContext context) {
    return AppColors.primary;
  }

  static Color textPrimary(BuildContext context) {
    return isDark(context) ? const Color(0xFFF8FAFC) : const Color(0xFF172033);
  }

  static Color textSecondary(BuildContext context) {
    return isDark(context) ? const Color(0xFFB8C4D6) : const Color(0xFF64748B);
  }

  static Color divider(BuildContext context) {
    return isDark(context) ? const Color(0xFF334155) : const Color(0xFFD9E2EC);
  }

  static Color trackBg(BuildContext context) {
    return isDark(context) ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  }

  static Color searchBackground(BuildContext context) {
    return isDark(context) ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
  }

  static Color barFill(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color insightBg(BuildContext context) {
    return isDark(context) ? const Color(0xFF172554) : const Color(0xFFE8F1FF);
  }

  static Color insightAccent(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color danger(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  static const live = Color(0xFF23C16B);

  static const mrt = Color(0xFFE53935);
  static const lrt = Color(0xFFF7B500);
  static const ktmb = Color(0xFF43A047);
  static const ets = Color(0xFF3B82F6);
  static const monorail = Color(0xFF7C3AED);

  static const gold = Color(0xFFF2A93B);
  static const silver = Color(0xFFB0B7C3);
  static const bronze = Color(0xFFCB7B4B);
  static const neutralBadge = Color(0xFFCBD2E0);
}

typedef _GroupGetter = double Function(_DayUsage r);

class _GroupSpec {
  const _GroupSpec(this.key, this.label, this.color, this.value, this.note);

  final String key;
  final String label;
  final Color color;
  final _GroupGetter value;
  final String note;
}

final List<_GroupSpec> _groups = <_GroupSpec>[
  _GroupSpec(
    'mrt',
    'MRT',
    _Palette.mrt,
    (r) => (r.mrtKajang + r.mrtPutrajaya).toDouble(),
    'Kajang · Putrajaya',
  ),
  _GroupSpec(
    'lrt',
    'LRT',
    _Palette.lrt,
    (r) => (r.lrtAmpang + r.lrtKelanaJaya).toDouble(),
    'Kelana Jaya · Ampang',
  ),
  _GroupSpec(
    'ktmb',
    'KTMB',
    _Palette.ktmb,
    (r) => (r.komuter + r.komuterUtara + r.intercity).toDouble(),
    'Komuter · Intercity',
  ),
  _GroupSpec(
    'ets',
    'ETS',
    _Palette.ets,
    (r) => r.ets.toDouble(),
    'Electric Train Service',
  ),
  _GroupSpec(
    'monorail',
    'Monorail',
    _Palette.monorail,
    (r) => r.monorail.toDouble(),
    'KL Monorail',
  ),
];

const List<String> _weekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _weekdayFull = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatCompact(num value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
  return value.toStringAsFixed(0);
}

String _formatShortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

List<_DayUsage> _lastNDays(List<_DayUsage> data, int n) {
  if (data.length <= n) return data;
  return data.sublist(data.length - n);
}

List<_DayUsage> _windowFor(List<_DayUsage> data, _Range range) =>
    _lastNDays(data, range == _Range.week ? 7 : 30);

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.shortText, required this.fullText});

  final String shortText;
  final String fullText;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: fullText,
      triggerMode: TooltipTriggerMode.tap,
      textStyle: const TextStyle(
        fontSize: 11.5,
        color: Colors.white,
        height: 1.4,
      ),
      decoration: BoxDecoration(
        color: _Palette.textPrimary(context),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: _Palette.textSecondary(context),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              shortText,
              style: TextStyle(
                fontSize: 10.5,
                color: _Palette.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearLink extends StatelessWidget {
  const _ClearLink({required this.onTap, this.label = 'Clear'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.close_rounded, size: 12, color: _Palette.danger(context)),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _Palette.danger(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Railway Insights',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'ridership_headline · ridership_ktmb · data.gov.my',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.range, required this.onChanged});

  final _Range range;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _Palette.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _Palette.divider(context)),
        ),
        child: Row(
          children: [
            _tab(context, 'This Week', _Range.week),
            _tab(context, 'This Month', _Range.month),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, String label, _Range value) {
    final selected = range == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _Palette.headerBlue(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : _Palette.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _Palette.textPrimary(context),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: _Palette.textSecondary(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _TrendCard extends StatefulWidget {
  const _TrendCard({required this.data, required this.range});

  final List<_DayUsage> data;
  final _Range range;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  final Set<String> _hidden = {};

  void _toggle(String key) {
    setState(() {
      if (_hidden.contains(key)) {
        _hidden.remove(key);
      } else {
        _hidden.add(key);
      }
    });
  }

  void _clearFilters() => setState(() => _hidden.clear());

  @override
  Widget build(BuildContext context) {
    final window = _windowFor(widget.data, widget.range);
    final visibleGroups = _groups
        .where((g) => !_hidden.contains(g.key))
        .toList();

    final allSpots = <String, List<FlSpot>>{
      for (final g in _groups)
        g.key: [
          for (int i = 0; i < window.length; i++)
            FlSpot(i.toDouble(), g.value(window[i])),
        ],
    };

    final visibleValues = [
      for (final g in visibleGroups) ...allSpots[g.key]!.map((s) => s.y),
    ];
    final baseMaxY = visibleValues.isEmpty
        ? 1.0
        : visibleValues.reduce((a, b) => a > b ? a : b);

    bool isFlatZero(List<FlSpot> spots) => spots.every((s) => s.y == 0);
    final offsetStep = (baseMaxY <= 0 ? 1 : baseMaxY) * 0.035;

    final lineDefs = <_TrendLine>[];
    int flatIndex = 0;
    for (final g in visibleGroups) {
      final spots = allSpots[g.key]!;
      if (isFlatZero(spots)) {
        flatIndex++;
        final offset = offsetStep * flatIndex;
        lineDefs.add(
          _TrendLine(
            color: g.color,
            spots: [for (final s in spots) FlSpot(s.x, s.y + offset)],
            isFlat: true,
          ),
        );
      } else {
        lineDefs.add(_TrendLine(color: g.color, spots: spots));
      }
    }

    final hasFlatLines = flatIndex > 0;
    final displayMaxY = lineDefs
        .expand((d) => d.spots)
        .fold<double>(baseMaxY, (m, s) => s.y > m ? s.y : m);
    final maxY = displayMaxY <= 0 ? 1.0 : displayMaxY * 1.2;

    final labelStep = widget.range == _Range.week
        ? 1
        : (window.isEmpty
              ? 1
              : (window.length / 6).ceil().clamp(1, window.length));

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.show_chart_rounded,
            iconColor: _Palette.headerBlue(context),
            title: widget.range == _Range.week
                ? 'Weekly Ridership Trend'
                : 'Monthly Ridership Trend',
            subtitle: 'Tap a chip below to show/hide a service',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _Palette.live,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'HISTORICAL',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 160,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            decoration: BoxDecoration(
              color: _Palette.background(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _Palette.divider(context)),
            ),
            child: window.isEmpty || visibleGroups.isEmpty
                ? const _MiniEmpty()
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= window.length)
                                return const SizedBox.shrink();
                              if (index % labelStep != 0 &&
                                  index != window.length - 1) {
                                return const SizedBox.shrink();
                              }
                              final label = widget.range == _Range.week
                                  ? _weekdayShort[window[index].date.weekday -
                                        1]
                                  : _formatShortDate(window[index].date);
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _Palette.textSecondary(context),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        for (final d in lineDefs)
                          _line(d.spots, d.color, dashed: d.isFlat),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in _groups)
                      _FilterChip(
                        color: g.color,
                        label: g.label,
                        active: !_hidden.contains(g.key),
                        onTap: () => _toggle(g.key),
                      ),
                  ],
                ),
              ),
              if (_hidden.isNotEmpty) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _ClearLink(onTap: _clearFilters, label: 'Clear'),
                ),
              ],
            ],
          ),
          if (hasFlatLines) ...[
            const SizedBox(height: 10),
            const _InfoNote(
              shortText: 'Dashed lines = no data for this range',
              fullText:
                  'A dashed line means that service has no data (null '
                  'in the source JSON) for this date range. It is nudged up '
                  'slightly so it stays visible next to other 0-value lines '
                  '— its real value is 0, not the raised position shown.',
            ),
          ],
        ],
      ),
    );
  }

  LineChartBarData _line(
    List<FlSpot> spots,
    Color color, {
    bool dashed = false,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: !dashed,
      curveSmoothness: 0.3,
      color: dashed ? color.withValues(alpha: 0.55) : color,
      barWidth: dashed ? 2 : 2.5,
      dashArray: dashed ? [5, 4] : null,
      dotData: FlDotData(
        show: !dashed,
        getDotPainter: (spot, percent, bar, index) =>
            FlDotCirclePainter(radius: 2.5, color: color, strokeWidth: 0),
      ),
    );
  }
}

class _TrendLine {
  const _TrendLine({
    required this.color,
    required this.spots,
    this.isFlat = false,
  });

  final Color color;
  final List<FlSpot> spots;
  final bool isFlat;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.color,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.1)
              : _Palette.background(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.35)
                : _Palette.divider(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? color
                    : _Palette.textSecondary(context).withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: active
                    ? _Palette.textPrimary(context)
                    : _Palette.textSecondary(context),
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.data, required this.range});

  final List<_DayUsage> data;
  final _Range range;

  List<double> _averages() {
    final window = _windowFor(data, range);
    if (window.isEmpty) return List.filled(_groups.length, 0);
    return [
      for (final g in _groups)
        window.fold<double>(0, (sum, r) => sum + g.value(r)) / window.length,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final averages = _averages();
    final maxVal = averages.isEmpty
        ? 1.0
        : averages.reduce((a, b) => a > b ? a : b);
    final rangeLabel = range == _Range.week ? 'This Week' : 'This Month';

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.bar_chart_rounded,
            iconColor: _Palette.ktmb,
            title: 'Compare Railway Usage',
            subtitle: '$rangeLabel · average ridership per day',
          ),
          const SizedBox(height: 18),
          Container(
            height: 150,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            decoration: BoxDecoration(
              color: _Palette.background(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _Palette.divider(context)),
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxVal <= 0 ? 1 : maxVal) * 1.25,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= _groups.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _groups[index].label,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: _Palette.textSecondary(context),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < _groups.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: averages[i] > 0
                              ? averages[i]
                              : (maxVal <= 0 ? 1 : maxVal) * 0.03,
                          color: averages[i] > 0
                              ? _groups[i].color
                              : _Palette.trackBg(context),
                          width: 26,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _groups.length; i++)
                _LegendDot(
                  color: _groups[i].color,
                  label: averages[i] > 0
                      ? '${_groups[i].label}: ${_formatCompact(averages[i])}/day'
                      : '${_groups[i].label}: no data',
                ),
            ],
          ),
          if (averages.any((v) => v <= 0)) ...[
            const SizedBox(height: 10),
            const _InfoNote(
              shortText: 'Some categories have no data yet',
              fullText:
                  'Categories showing "no data" have null values for '
                  'every row in both ridership_headline_sample.json and '
                  'ridership_ktmb_sample.json for this range — that\'s not '
                  'zero ridership, just missing data.',
            ),
          ],
        ],
      ),
    );
  }
}

enum _SortMode { mostUsed, leastUsed, aToZ, zToA }

class _TopUsageCard extends StatefulWidget {
  const _TopUsageCard({required this.data, required this.range});

  final List<_DayUsage> data;
  final _Range range;

  @override
  State<_TopUsageCard> createState() => _TopUsageCardState();
}

class _TopUsageCardState extends State<_TopUsageCard> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _SortMode _sort = _SortMode.mostUsed;

  bool get _isFiltered => _query.isNotEmpty || _sort != _SortMode.mostUsed;

  void _clearAll() {
    setState(() {
      _query = '';
      _searchController.clear();
      _sort = _SortMode.mostUsed;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final window = _windowFor(widget.data, widget.range);
    final averages = <_GroupSpec, double>{
      for (final g in _groups)
        g: window.isEmpty
            ? 0
            : window.fold<double>(0, (sum, r) => sum + g.value(r)) /
                  window.length,
    };

    final byUsage = averages.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final trueRank = <_GroupSpec, int>{
      for (int i = 0; i < byUsage.length; i++) byUsage[i].key: i + 1,
    };
    final maxVal = byUsage.isEmpty ? 1.0 : byUsage.first.value;

    var entries = averages.entries
        .where((e) => e.key.label.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    switch (_sort) {
      case _SortMode.mostUsed:
        entries.sort((a, b) {
          if (a.value <= 0 && b.value <= 0)
            return a.key.label.compareTo(b.key.label);
          if (a.value <= 0) return 1;
          if (b.value <= 0) return -1;
          return b.value.compareTo(a.value);
        });
        break;
      case _SortMode.leastUsed:
        entries.sort((a, b) {
          if (a.value <= 0 && b.value <= 0)
            return a.key.label.compareTo(b.key.label);
          if (a.value <= 0) return 1;
          if (b.value <= 0) return -1;
          return a.value.compareTo(b.value);
        });
        break;
      case _SortMode.aToZ:
        entries.sort((a, b) => a.key.label.compareTo(b.key.label));
        break;
      case _SortMode.zToA:
        entries.sort((a, b) => b.key.label.compareTo(a.key.label));
        break;
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.emoji_events_rounded,
            iconColor: _Palette.gold,
            title: 'Top Railway Usage',
            subtitle: widget.range == _Range.week ? 'This Week' : 'This Month',
          ),
          const SizedBox(height: 16),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _Palette.searchBackground(context),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _Palette.divider(context), width: 1),
            ),
            child: SizedBox(
              height: 38,
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 17,
                    color: _Palette.textSecondary(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _Palette.textPrimary(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search transport type…',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: _Palette.textSecondary(context),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _Palette.divider(context),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _Palette.divider(context),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _Palette.headerBlue(context),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() {
                        _query = '';
                        _searchController.clear();
                      }),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: _Palette.textSecondary(context),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Text(
                        'Sort:',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _Palette.textSecondary(context),
                        ),
                      ),
                    ),
                    _SortChip(
                      label: 'High→Low',
                      icon: Icons.south_rounded,
                      active: _sort == _SortMode.mostUsed,
                      onTap: () => setState(() => _sort = _SortMode.mostUsed),
                    ),
                    _SortChip(
                      label: 'Low→High',
                      icon: Icons.north_rounded,
                      active: _sort == _SortMode.leastUsed,
                      onTap: () => setState(() => _sort = _SortMode.leastUsed),
                    ),
                    _SortChip(
                      label: 'A→Z',
                      icon: Icons.arrow_downward_rounded,
                      active: _sort == _SortMode.aToZ,
                      onTap: () => setState(() => _sort = _SortMode.aToZ),
                    ),
                    _SortChip(
                      label: 'Z→A',
                      icon: Icons.arrow_upward_rounded,
                      active: _sort == _SortMode.zToA,
                      onTap: () => setState(() => _sort = _SortMode.zToA),
                    ),
                  ],
                ),
              ),
              if (_isFiltered) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _ClearLink(onTap: _clearAll),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: _MiniEmpty(text: 'No transport type matches your search'),
            )
          else
            for (int i = 0; i < entries.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == entries.length - 1 ? 0 : 14,
                ),
                child: _TopUsageRow(
                  rank: trueRank[entries[i].key],
                  spec: entries[i].key,
                  value: entries[i].value,
                  maxValue: maxVal <= 0 ? 1 : maxVal,
                ),
              ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? _Palette.headerBlue(context)
              : _Palette.background(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? _Palette.headerBlue(context)
                : _Palette.divider(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: active ? Colors.white : _Palette.textSecondary(context),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : _Palette.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopUsageRow extends StatelessWidget {
  const _TopUsageRow({
    required this.rank,
    required this.spec,
    required this.value,
    required this.maxValue,
  });

  final int? rank;
  final _GroupSpec spec;
  final double value;
  final double maxValue;

  static const _medalColors = [_Palette.gold, _Palette.silver, _Palette.bronze];

  @override
  Widget build(BuildContext context) {
    final noData = value <= 0 || rank == null;
    final badgeColor = noData
        ? _Palette.neutralBadge
        : (rank! <= 3 ? _medalColors[rank! - 1] : _Palette.neutralBadge);
    final ratio = noData ? 0.0 : (value / maxValue).clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: noData
              ? const Icon(Icons.remove_rounded, color: Colors.white, size: 16)
              : Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spec.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _Palette.textPrimary(context),
                ),
              ),
              Text(
                spec.note,
                style: TextStyle(
                  fontSize: 11,
                  color: _Palette.textSecondary(context),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor: _Palette.trackBg(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _Palette.barFill(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          noData ? 'No data' : _formatCompact(value),
          style: TextStyle(
            fontSize: noData ? 11.5 : 13.5,
            fontWeight: FontWeight.w800,
            color: noData
                ? _Palette.textSecondary(context)
                : _Palette.textPrimary(context),
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.data});

  final List<_DayUsage> data;

  @override
  Widget build(BuildContext context) {
    final insight = _computeInsight(data);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _Palette.insightBg(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _Palette.insightAccent(context),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Railway Insight',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _Palette.textPrimary(context),
                      ),
                    ),
                    Text(
                      'Based on the full loaded dataset · data.gov.my',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _Palette.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: _Palette.textPrimary(context),
                ),
                children: [
                  const TextSpan(text: '"'),
                  TextSpan(text: '${insight.busiestWeekday}s see '),
                  TextSpan(
                    text: '${insight.percentAboveAverage}% higher ridership',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _Palette.insightAccent(context),
                    ),
                  ),
                  TextSpan(
                    text:
                        ' than the weekly average — ${insight.topService} '
                        '(${insight.topServiceNote}) is busiest then. '
                        '${insight.quietestWeekday}s tend to offer the most '
                        'comfortable journey."',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _RailInsight _computeInsight(List<_DayUsage> data) {
    if (data.isEmpty) {
      return const _RailInsight(
        busiestWeekday: 'Friday',
        quietestWeekday: 'Sunday',
        percentAboveAverage: 0,
        topService: 'MRT',
        topServiceNote: 'Kajang · Putrajaya',
      );
    }

    final totalsByWeekday = List<double>.filled(7, 0);
    final countByWeekday = List<int>.filled(7, 0);
    for (final r in data) {
      final index = r.date.weekday - 1;
      totalsByWeekday[index] += r.totalRailRidership;
      countByWeekday[index] += 1;
    }
    final averagesByWeekday = List<double>.generate(
      7,
      (i) =>
          countByWeekday[i] == 0 ? 0 : totalsByWeekday[i] / countByWeekday[i],
    );

    final overallAverage = averagesByWeekday.reduce((a, b) => a + b) / 7;

    int busiestIndex = 0;
    int quietestIndex = 0;
    for (int i = 1; i < 7; i++) {
      if (averagesByWeekday[i] > averagesByWeekday[busiestIndex])
        busiestIndex = i;
      if (averagesByWeekday[i] < averagesByWeekday[quietestIndex])
        quietestIndex = i;
    }

    final percentAbove = overallAverage <= 0
        ? 0
        : (((averagesByWeekday[busiestIndex] - overallAverage) /
                      overallAverage) *
                  100)
              .round();

    final window = _lastNDays(data, 30);
    _GroupSpec topGroup = _groups.first;
    double topValue = -1;
    for (final g in _groups) {
      final avg = window.isEmpty
          ? 0.0
          : window.fold<double>(0, (sum, r) => sum + g.value(r)) /
                window.length;
      if (avg > topValue) {
        topValue = avg;
        topGroup = g;
      }
    }

    return _RailInsight(
      busiestWeekday: _weekdayFull[busiestIndex],
      quietestWeekday: _weekdayFull[quietestIndex],
      percentAboveAverage: percentAbove.clamp(0, 999),
      topService: topGroup.label,
      topServiceNote: topGroup.note,
    );
  }
}

class _RailInsight {
  const _RailInsight({
    required this.busiestWeekday,
    required this.quietestWeekday,
    required this.percentAboveAverage,
    required this.topService,
    required this.topServiceNote,
  });

  final String busiestWeekday;
  final String quietestWeekday;
  final int percentAboveAverage;
  final String topService;
  final String topServiceNote;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _Palette.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _Palette.divider(context), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: _Palette.isDark(context) ? 0.25 : 0.06,
              ),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: _Palette.textSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _Palette.headerBlue(context)),
          const SizedBox(height: 14),
          Text(
            'Loading ridership insights…',
            style: TextStyle(
              fontSize: 13,
              color: _Palette.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 44,
              color: _Palette.textSecondary(context),
            ),
            const SizedBox(height: 12),
            Text(
              'No ridership data available yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _Palette.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check that the sample dataset is bundled under assets/data/.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _Palette.textSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: _Palette.danger(context),
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load insights',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _Palette.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _Palette.textSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _Palette.headerBlue(context),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  const _MiniEmpty({this.text = 'Not enough data yet'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: _Palette.textSecondary(context)),
      ),
    );
  }
}
