import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../core/di/injection.dart';
import '../core/localization/l10n_extension.dart';
import '../core/routes/app_routes.dart';
import '../core/services/pip_audio_coordinator.dart';
import '../core/theme/pip_theme.dart';
import '../features/activity/presentation/action_result_card.dart';
import '../features/companion/presentation/cubit/pip_stage_cubit.dart';
import '../features/companion/presentation/widgets/pip_command_bar.dart';
import '../features/companion/presentation/widgets/pip_screen_context.dart';
import '../widgets/home/pip_today_panel.dart';

/// The frame around every tab: Pip, Tasks, Alarms, Activity. Holds the one
/// command bar and the result card, and tells Pip which screen is showing.
/// Phones get a bottom bar; wide screens (Windows, tablets) a side rail.
class PipAppShell extends StatelessWidget {
  final StatefulNavigationShell shell;

  const PipAppShell({super.key, required this.shell});

  /// What Pip is told about each tab, by branch index.
  static const List<String?> screenContexts = [
    null,
    'the Tasks screen, looking at their open tasks',
    'the Alarms & reminders screen, looking at their alarms and reminders',
    'the Activity screen, looking at what Pip has done for them',
  ];

  void _go(int index) {
    PipScreenContext.current.value = screenContexts[index];
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  String _hint(BuildContext context) => switch (shell.currentIndex) {
        1 => context.l10n.commandHintTasks,
        2 => context.l10n.commandHintAlarms,
        _ => context.l10n.commandHint,
      };

  Map<ShortcutActivator, VoidCallback> _shortcuts(BuildContext context) {
    final audio = getIt<PipAudioCoordinator>();
    final cubit = context.read<PipStageCubit>();
    return {
      const SingleActivator(LogicalKeyboardKey.space, control: true): () => audio.isActiveListening
          ? audio.stopListening()
          : audio.startActiveListening(onQuery: (q) => cubit.handleQuery(PipScreenContext.withContext(q))),
      const SingleActivator(LogicalKeyboardKey.comma, control: true): () => context.push(AppRoutes.settings),
      const SingleActivator(LogicalKeyboardKey.keyB, control: true): () => context.push(AppRoutes.briefing),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = Column(mainAxisSize: MainAxisSize.min, children: [
      const ActionResultCard(),
      Padding(
        padding: EdgeInsets.fromLTRB(t.space.md, t.space.xs, t.space.md, t.space.sm),
        child: PipCommandBar(hint: _hint(context)),
      ),
    ]);
    final content = Column(children: [Expanded(child: shell), bottom]);

    return CallbackShortcuts(
      bindings: _shortcuts(context),
      child: Focus(
        autofocus: true,
        child: context.isWide ? _wide(context, content) : _phone(context, content),
      ),
    );
  }

  Widget _phone(BuildContext context, Widget content) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(bottom: false, child: content),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.smart_toy_outlined), label: l10n.navPip),
          NavigationDestination(icon: const Icon(Icons.checklist), label: l10n.navTasks),
          NavigationDestination(icon: const Icon(Icons.alarm), label: l10n.navAlarms),
          NavigationDestination(icon: const Icon(Icons.history), label: l10n.navActivity),
        ],
      ),
    );
  }

  Widget _wide(BuildContext context, Widget content) {
    final t = context.tokens;
    final l10n = context.l10n;
    final showToday = shell.currentIndex == 0 && MediaQuery.sizeOf(context).width >= 1100;
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: EdgeInsets.only(top: t.space.md, bottom: t.space.lg),
            child: Text(l10n.appTitle.toUpperCase(),
                style: TextStyle(color: t.colors.accent, fontWeight: FontWeight.w700, letterSpacing: 4)),
          ),
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: t.space.lg),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      tooltip: l10n.navMemory,
                      onPressed: () => context.push(AppRoutes.memory),
                      icon: const Icon(Icons.psychology_outlined)),
                  IconButton(
                      tooltip: l10n.navSettings,
                      onPressed: () => context.push(AppRoutes.settings),
                      icon: const Icon(Icons.settings_outlined)),
                ]),
              ),
            ),
          ),
          destinations: [
            NavigationRailDestination(icon: const Icon(Icons.smart_toy_outlined), label: Text(l10n.navPip)),
            NavigationRailDestination(icon: const Icon(Icons.checklist), label: Text(l10n.navTasks)),
            NavigationRailDestination(icon: const Icon(Icons.alarm), label: Text(l10n.navAlarms)),
            NavigationRailDestination(icon: const Icon(Icons.history), label: Text(l10n.navActivity)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: content),
        if (showToday) ...[
          const VerticalDivider(width: 1),
          const SizedBox(width: 320, child: PipTodayPanel()),
        ],
      ]),
    );
  }
}
