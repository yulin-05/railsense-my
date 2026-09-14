import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/explorer/explorer_screen.dart';
import 'screens/insights/insights_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/profile/profile_screen.dart';

class RailSenseApp extends StatelessWidget {
  const RailSenseApp({super.key});

  bool _isDark(ThemeMode mode) {
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = _isDark(mode);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: MaterialApp(
            title: 'RailSenseMY',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,

            initialRoute: AppRoutes.login,

            routes: {
              AppRoutes.login: (context) => const LoginScreen(),

              AppRoutes.dashboard: (context) => const MainNavigationScreen(),

              AppRoutes.explorer: (context) => const ExplorerScreen(),
              AppRoutes.insights: (context) => const InsightsScreen(),
              AppRoutes.profile: (context) => const ProfileScreen(),
              AppRoutes.register: (context) => const RegisterScreen(),
              AppRoutes.forgotPassword: (context) =>
                  const ForgotPasswordScreen(),
            },
          ),
        );
      },
    );
  }
}
