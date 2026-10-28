import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/localization/l10n_extension.dart';
import 'package:personal_assistant/core/routes/app_router.dart';
import 'package:personal_assistant/core/routes/app_routes.dart';
import 'package:personal_assistant/core/theme/pip_theme.dart';

void main() {
  group('Route guard', () {
    test('before setup, only splash, welcome and onboarding are reachable', () {
      expect(routeGuard(false, AppRoutes.home), AppRoutes.welcome);
      expect(routeGuard(false, AppRoutes.settings), AppRoutes.welcome);
      expect(routeGuard(false, AppRoutes.alarms), AppRoutes.welcome);
      expect(routeGuard(false, AppRoutes.splash), isNull);
      expect(routeGuard(false, AppRoutes.onboarding), isNull);
    });

    test('after setup, welcome and onboarding bounce to home; re-running setup is allowed', () {
      expect(routeGuard(true, AppRoutes.welcome), AppRoutes.home);
      expect(routeGuard(true, AppRoutes.onboarding), AppRoutes.home);
      expect(routeGuard(true, AppRoutes.settingsSetupAgain), isNull);
      expect(routeGuard(true, AppRoutes.home), isNull);
    });
  });

  testWidgets('context.tokens and context.l10n resolve inside the app theme', (tester) async {
    late PipTokens tokens;
    late String title;
    late String tasks;
    await tester.pumpWidget(MaterialApp(
      theme: PipTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        tokens = context.tokens;
        title = context.l10n.appTitle;
        tasks = context.l10n.openTasksCount(3);
        return const SizedBox();
      }),
    ));
    expect(tokens.colors.accent, PipColors.amber);
    expect(tokens.space.lg, PipSpace.lg);
    expect(title, 'Pip');
    expect(tasks, '3 open tasks');
  });

  testWidgets('tokens fall back to the dark set outside the Pip theme', (tester) async {
    late PipTokens tokens;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      tokens = context.tokens;
      return const SizedBox();
    })));
    expect(tokens.colors.background, PipColors.background);
  });
}
