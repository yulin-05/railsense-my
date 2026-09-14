import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/favourites_notifier.dart';
import '../models/favourite_route.dart';

class FavouriteRouteService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _table = 'favourite_routes';

  String get _requireUserId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('No logged-in user. Cannot access favourite routes.');
    }
    return userId;
  }

  Future<List<FavouriteRoute>> getFavourites() async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', _requireUserId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => FavouriteRoute.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<FavouriteRoute> addFavourite({
    required String origin,
    required String destination,
    required String line,
  }) async {
    final response = await _client
        .from(_table)
        .insert({
          'user_id': _requireUserId,
          'origin': origin,
          'destination': destination,
          'line': line,
        })
        .select()
        .single();

    favouritesChangeNotifier.value++;
    return FavouriteRoute.fromJson(response);
  }

  Future<FavouriteRoute> updateFavourite({
    required int id,
    required String origin,
    required String destination,
    required String line,
  }) async {
    final response = await _client
        .from(_table)
        .update({'origin': origin, 'destination': destination, 'line': line})
        .eq('id', id)
        .eq('user_id', _requireUserId)
        .select()
        .single();

    favouritesChangeNotifier.value++;
    return FavouriteRoute.fromJson(response);
  }

  Future<void> removeFavourite(int id) async {
    await _client
        .from(_table)
        .delete()
        .eq('id', id)
        .eq('user_id', _requireUserId);

    favouritesChangeNotifier.value++;
  }

  Future<void> removeFavouriteByRoute({
    required String origin,
    required String destination,
    required String line,
  }) async {
    await _client.from(_table).delete().match({
      'user_id': _requireUserId,
      'origin': origin,
      'destination': destination,
      'line': line,
    });

    favouritesChangeNotifier.value++;
  }

  Future<bool> isFavourite({
    required String origin,
    required String destination,
    required String line,
  }) async {
    final response = await _client.from(_table).select('id').match({
      'user_id': _requireUserId,
      'origin': origin,
      'destination': destination,
      'line': line,
    }).maybeSingle();

    return response != null;
  }
}
