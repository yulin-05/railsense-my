import 'package:flutter/material.dart';

import '../../core/favourites_notifier.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/favourite_route.dart';
import '../../models/route_ridership.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/favourite_route_service.dart';
import '../../services/government_data_service.dart';
import '../../services/user_service.dart';
import '../explorer/route_detail_screen.dart';
import 'appearance_screen.dart';
import 'data_source_screen.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.onNavigate,
    this.onProfileUpdated,
  });

  final ValueChanged<int>? onNavigate;
  final Future<void> Function()? onProfileUpdated;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _favouriteService = FavouriteRouteService();
  final _dataService = const GovernmentDataService();

  late Future<_ProfileData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    favouritesChangeNotifier.addListener(_onFavouritesChanged);
  }

  @override
  void dispose() {
    favouritesChangeNotifier.removeListener(_onFavouritesChanged);
    super.dispose();
  }

  void _onFavouritesChanged() {
    if (mounted) _refresh();
  }

  Future<_ProfileData> _loadData() async {
    final results = await Future.wait([
      _userService.getProfile(),
      _favouriteService.getFavourites(),
      _dataService.loadRapidRailOdRidership(),
    ]);

    final profile = results[0] as UserModel;
    final favourites = results[1] as List<FavouriteRoute>;
    final routes = results[2] as List<RouteRidership>;

    final routesByKey = <String, RouteRidership>{
      for (final r in routes) r.routeKey: r,
    };

    return _ProfileData(
      profile: profile,
      favourites: favourites,
      routesByKey: routesByKey,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _openEditProfile(UserModel profile) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
    );

    if (changed == true) {
      await _refresh();
      await widget.onProfileUpdated?.call();
    }
  }

  Future<void> _removeFavourite(FavouriteRoute favourite) async {
    try {
      await _favouriteService.removeFavourite(favourite.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove favourite: $e')));
    }
  }

  String _reversedLine(String line) {
    if (line.contains('→')) {
      final parts = line.split('→').map((p) => p.trim()).toList();
      if (parts.length == 2) return '${parts[1]} → ${parts[0]}';
    }
    return line;
  }

  Future<void> _swapFavouriteDirection(FavouriteRoute favourite) async {
    try {
      await _favouriteService.updateFavourite(
        id: favourite.id,
        origin: favourite.destination,
        destination: favourite.origin,
        line: _reversedLine(favourite.line),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update favourite: $e')));
    }
  }

  String _lineFor(RouteRidership route) {
    return route.originLine == route.destinationLine
        ? route.originLine
        : '${route.originLine} → ${route.destinationLine}';
  }

  Future<void> _handleRouteDetailToggle(
    RouteRidership route,
    List<FavouriteRoute> currentFavourites,
  ) async {
    FavouriteRoute? existing;
    for (final f in currentFavourites) {
      if (f.origin == route.origin && f.destination == route.destination) {
        existing = f;
        break;
      }
    }

    try {
      if (existing != null) {
        await _favouriteService.removeFavourite(existing.id);
      } else {
        await _favouriteService.addFavourite(
          origin: route.origin,
          destination: route.destination,
          line: _lineFor(route),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update favourite: $e')));
    }
  }

  Future<void> _openFavouriteDetails(
    FavouriteRoute favourite,
    RouteRidership? route,
    List<FavouriteRoute> currentFavourites,
  ) async {
    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No detailed data for this saved direction — the dataset only "
            "has ridership records for the direction you originally saved.",
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RouteDetailScreen(
          route: route,
          isFavourite: true,
          onToggleFavourite: (r) =>
              _handleRouteDetailToggle(r, currentFavourites),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.lightBlue,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('👋', style: TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Leaving so soon?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                "You'll need to log in again to see your favourite routes.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Stay'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: AppColors.error.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          'Log out',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  void _goToExplorer() {
    if (widget.onNavigate != null) {
      widget.onNavigate!(1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open the Explorer tab to add a route.')),
      );
    }
  }

  _CrowdLevel? _crowdFor(RouteRidership? route) {
    if (route == null) return null;
    final ridership = route.ridership;
    if (ridership >= 1500) return _CrowdLevel.crowded;
    if (ridership >= 500) return _CrowdLevel.moderate;
    return _CrowdLevel.light;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_ProfileData>(
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
                      'Unable to load profile\n${snapshot.error}',
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

          final data = snapshot.data!;

          return SafeArea(
            top: false,
            bottom: false,
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildHeader(data),
                      const SizedBox(height: 20),
                      _buildFavouritesSection(data),
                      const SizedBox(height: 24),
                      _buildSettingsSection(),
                      const SizedBox(height: 20),
                      _buildLogoutButton(),
                      const SizedBox(height: 16),
                      _buildFooter(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: IconButton(
                    onPressed: () => _openEditProfile(data.profile),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    tooltip: 'Edit Profile',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(_ProfileData data) {
    final distinctLines = data.favourites.map((f) => f.line).toSet().length;
    final daysSinceJoined = DateTime.now()
        .difference(data.profile.createdAt)
        .inDays;
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            data.profile.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.profile.email,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat('${data.favourites.length}', 'Favourites'),
              _buildStat('$distinctLines', 'Lines'),
              _buildStat('$daysSinceJoined', 'Days'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFavouritesSection(_ProfileData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Favourite Routes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          if (data.favourites.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No favourites yet. Save a route from Explorer to see it here.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...data.favourites.map((f) {
              final route = data.routesByKey['${f.origin}->${f.destination}'];
              return _buildFavouriteCard(f, route, data.favourites);
            }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _goToExplorer,
              icon: const Icon(Icons.add),
              label: const Text('Add Favourite Route'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavouriteCard(
    FavouriteRoute favourite,
    RouteRidership? route,
    List<FavouriteRoute> currentFavourites,
  ) {
    final crowd = _crowdFor(route);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              _openFavouriteDetails(favourite, route, currentFavourites),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.directions_railway,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_stationName(favourite.origin)} → ${_stationName(favourite.destination)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.swap_horiz,
                        size: 18,
                        color: Colors.blueGrey,
                      ),
                      tooltip: 'Swap direction',
                      onPressed: () => _swapFavouriteDirection(favourite),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onPressed: () => _removeFavourite(favourite),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      favourite.line,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    if (crowd != null)
                      _buildCrowdTag(crowd)
                    else
                      _buildNoDataTag(),
                    const Spacer(),
                    if (route != null)
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Colors.grey,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stationName(String raw) {
    final parts = raw.split(':');
    return parts.length > 1 ? parts[1].trim() : raw;
  }

  Widget _buildCrowdTag(_CrowdLevel level) {
    late Color color;
    late String label;
    switch (level) {
      case _CrowdLevel.light:
        color = AppColors.crowdLight;
        label = 'Light';
        break;
      case _CrowdLevel.moderate:
        color = AppColors.crowdModerate;
        label = 'Moderate';
        break;
      case _CrowdLevel.crowded:
        color = AppColors.crowdCrowded;
        label = 'Crowded';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'No data for this direction',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Latest data updates',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.storage_outlined,
            title: 'Data Source',
            subtitle:
                'data.gov.my · ridership_headline, ridership_od_rapidrail_daily',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DataSourceScreen())),
          ),
          _buildSettingsTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Blue theme',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AppearanceScreen())),
          ),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'FAQ · Contact',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _confirmLogout,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Column(
        children: [
          Text(
            'RailSenseMY · MyRail Insight Malaysia',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          SizedBox(height: 2),
          Text(
            'Data: data.gov.my · ridership_headline · ridership_od_rapidrail_daily',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.profile,
    required this.favourites,
    required this.routesByKey,
  });

  final UserModel profile;
  final List<FavouriteRoute> favourites;
  final Map<String, RouteRidership> routesByKey;
}

enum _CrowdLevel { light, moderate, crowded }
