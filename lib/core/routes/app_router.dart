import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/onboarding_flow.dart';
import '../../features/reminders/presentation/screens/alarms_reminders_screen.dart';
import '../../screens/pip_home_screen.dart';
import '../../screens/settings/pip_settings_screen.dart';
import '../../screens/settings/settings_pages.dart';
import '../../screens/splash_screen.dart';
import '../../screens/welcome_screen.dart';
import '../../screens/what_pip_knows_screen.dart';
import '../theme/app_motion_tokens.dart';
import 'app_routes.dart';
import 'onboarding_gate.dart';

/// Declarative route table and transitions only. No business logic here:
/// screens decide where to go next; the gate only guards setup.
GoRouter buildAppRouter(OnboardingGate gate, {GlobalKey<NavigatorState>? navigatorKey}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: gate,
    redirect: (context, state) => routeGuard(gate.completed, state.matchedLocation),
    routes: [
      _page(AppRoutes.splash, (_, _) => const PipSplashScreen()),
      _page(AppRoutes.welcome, (_, _) => const PipWelcomeScreen()),
      _page(
        AppRoutes.onboarding,
        (_, state) => OnboardingFlow(restoredFromBackup: state.uri.queryParameters[AppRoutes.restoredParam] == '1'),
      ),
      _page(AppRoutes.home, (_, _) => const PipHomeScreen()),
      _page(AppRoutes.alarms, (_, _) => const AlarmsRemindersScreen()),
      _page(AppRoutes.memory, (_, _) => const WhatPipKnowsScreen()),
      _page(AppRoutes.settings, (_, _) => const PipSettingsScreen()),
      _page(AppRoutes.settingsPersonality, (_, _) => const PersonalityPage()),
      _page(AppRoutes.settingsAiModel, (_, _) => const AiModelPage()),
      _page(AppRoutes.settingsConnections, (_, _) => const ConnectionsPage()),
      _page(AppRoutes.settingsBackup, (_, _) => const BackupPage()),
      _page(AppRoutes.settingsSetupAgain, (_, _) => const OnboardingFlow(rerun: true)),
    ],
  );
}

/// Before setup: only splash, welcome and onboarding. After setup: never
/// back into welcome/onboarding (re-running setup has its own route).
@visibleForTesting
String? routeGuard(bool setupDone, String location) {
  final isPublic = AppRoutes.publicPaths.contains(location);
  if (!setupDone && !isPublic) return AppRoutes.welcome;
  if (setupDone && (location == AppRoutes.welcome || location == AppRoutes.onboarding)) return AppRoutes.home;
  return null;
}

/// Every screen fades in with the screen-transition token; reduce motion
/// makes it instant.
GoRoute _page(String path, Widget Function(BuildContext, GoRouterState) build) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      child: build(context, state),
      transitionDuration: AppMotionTokens.resolveDuration(context, AppMotionTokens.screen),
      reverseTransitionDuration: AppMotionTokens.resolveDuration(context, AppMotionTokens.medium),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: AppMotionTokens.easeOut),
        child: child,
      ),
    ),
  );
}
