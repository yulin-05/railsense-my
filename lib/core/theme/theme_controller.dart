import 'package:flutter/material.dart';

/// Global theme mode, shared across the app. Kept as a simple
/// ValueNotifier instead of adding a state-management package, since
/// this is currently the only piece of cross-screen shared state.
///
/// Note: this resets to light mode on app restart — it isn't persisted
/// to disk yet.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.light,
);
