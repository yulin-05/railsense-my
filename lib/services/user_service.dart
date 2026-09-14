import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

class UserService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _table = 'profile';

  String get _requireUserId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('No logged-in user. Cannot access profile.');
    }
    return userId;
  }

  Future<UserModel> getProfile() async {
    final userId = _requireUserId;

    final existing = await _client
        .from(_table)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (existing != null) {
      return UserModel.fromJson(existing);
    }

    final authUser = _client.auth.currentUser;
    final created = await _client
        .from(_table)
        .insert({
          'id': userId,
          'name':
              authUser?.userMetadata?['name'] as String? ?? 'RailSense User',
          'email': authUser?.email ?? '',
        })
        .select()
        .single();

    return UserModel.fromJson(created);
  }

  Future<UserModel> updateName(String name) async {
    final response = await _client
        .from(_table)
        .update({'name': name})
        .eq('id', _requireUserId)
        .select()
        .single();

    return UserModel.fromJson(response);
  }
}
