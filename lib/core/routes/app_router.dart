import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/onboarding_flow.dart';
import '../../features/voice/presentation/voice_settings_page.dart';
import '../../features/reminders/presentation/screens/alarms_reminders_screen.dart';
import '../../app/pip_app_shell.dart';
import '../../features/activity/presentation/activity_screen.dart';
import '../../features/companion/presentation/screens/briefing_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../screens/companion_stage_screen.dart';
import '../theme/pip_theme.dart';
import '../../screens/settings/pip_settings_screen.dart';
import '../../screens/settings/settings_pages.dart';
import '../../screens/splash_screen.dart';
import '../../screens/welcome_screen.dart';
import '../../screens/what_pip_knows_screen.dart';
import '../theme/app_motion_tokens.dart';
import '../../features/brains/presentation/brains_page.dart';
import '../../features/games/domain/game_kind.dart';
import '../../features/games/presentation/screens/chess_screen.dart';
import '../../features/games/presentation/widgets/arcade_transitions.dart';
import '../../features/games/presentation/screens/four_in_row_screen.dart';
import '../../features/games/presentation/screens/game_hub_screen.dart';
import '../../features/games/presentation/screens/rps_screen.dart';
import '../../features/games/presentation/screens/tic_tac_toe_screen.dart';
import '../../features/games/presentation/screens/twenty_questions_screen.dart';
import 'app_routes.dart';
import 'onboarding_gate.dart';

/// Declarative route table and transitions only. No business logic here:
/// screens decide where to go next; the gate only guards setup.
GoRouter buildAppRouter(OnboardingGate gate, {GlobalKey<NavigatorState>? navigatorKey}) {
  final root = navigatorKey ?? GlobalKey<NavigatorState>();
  // Full-screen pages cover the tabs; tab pages keep the bar and command bar.
  GoRoute full(String path, Widget Function(BuildContext, GoRouterState) build) =>
      _page(path, build, parent: root);

  return GoRouter(
    navigatorKey: root,
    initialLocation: AppRoutes.splash,
    refreshListenable: gate,
    redirect: (context, state) => routeGuard(gate.completed, state.matchedLocation),
    routes: [
      full(AppRoutes.splash, (_, _) => const PipSplashScreen()),
      full(AppRoutes.welcome, (_, _) => const PipWelcomeScreen()),
      full(
        AppRoutes.onboarding,
        (_, state) => OnboardingFlow(restoredFromBackup: state.uri.queryParameters[AppRoutes.restoredParam] == '1'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => PipAppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            _page(AppRoutes.home, (context, _) => CompanionStageScreen(embedded: context.isWide), routes: [
              _page(AppRoutes.briefingSegment, (_, _) => const BriefingScreen()),
            ]),
          ]),
          StatefulShellBranch(routes: [_page(AppRoutes.tasks, (_, _) => const TasksScreen())]),
          StatefulShellBranch(routes: [_page(AppRoutes.alarms, (_, _) => const AlarmsRemindersScreen())]),
          StatefulShellBranch(routes: [_page(AppRoutes.activity, (_, _) => const ActivityScreen())]),
        ],
      ),
      full(AppRoutes.memory, (_, _) => const WhatPipKnowsScreen()),
      _arcade(AppRoutes.games, ArcadeEntrance.cabinet, root, (_, _) => const GameHubScreen()),
      _arcade('${AppRoutes.games}/:kind', ArcadeEntrance.ready, root, (_, state) => switch (GameKind.fromSlug(state.pathParameters['kind'])) {
            GameKind.fourInRow => const FourInRowScreen(),
            GameKind.rockPaperScissors => const RpsScreen(),
            GameKind.twentyQuestions => const TwentyQuestionsScreen(),
            GameKind.ticTacToe => const TicTacToeScreen(),
            GameKind.chess => const ChessScreen(),
            null => const GameHubScreen(),
          }),
      full(AppRoutes.settings, (_, _) => const PipSettingsScreen()),
      full(AppRoutes.settingsPersonality, (_, _) => const PersonalityPage()),
      full(AppRoutes.settingsAiModel, (_, _) => const AiModelPage()),
      full(AppRoutes.settingsBrains, (_, _) => const BrainsPage()),
      full(AppRoutes.settingsConnections, (_, _) => const ConnectionsPage()),
      full(AppRoutes.settingsBackup, (_, _) => const BackupPage()),
      full(AppRoutes.settingsVoice, (_, _) => const VoiceSettingsPage()),
      full(AppRoutes.settingsSetupAgain, (_, _) => const OnboardingFlow(rerun: true)),
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
/// Game mode: the arcade powers on like an old set; games open with a
/// "PLAYER 1 READY" splash.
GoRoute _arcade(String path, ArcadeEntrance entrance, GlobalKey<NavigatorState> parent,
        Widget Function(BuildContext, GoRouterState) build) =>
    GoRoute(
      path: path,
      parentNavigatorKey: parent,
      pageBuilder: (context, state) => arcadePage(key: state.pageKey, child: build(context, state), entrance: entrance),
    );

GoRoute _page(
  String path,
  Widget Function(BuildContext, GoRouterState) build, {
  GlobalKey<NavigatorState>? parent,
  List<RouteBase> routes = const [],
}) {
  return GoRoute(
    path: path,
    parentNavigatorKey: parent,
    routes: routes,
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
