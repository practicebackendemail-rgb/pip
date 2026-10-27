import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/di/injection.dart';
import '../core/domain/memory_repository.dart';
import '../core/services/pip_audio_coordinator.dart';
import '../core/theme/pip_theme.dart';
import '../features/companion/presentation/cubit/pip_stage_cubit.dart';
import '../features/reminders/presentation/screens/alarms_reminders_screen.dart';
import '../widgets/companion/pip_overlay_and_dock_area.dart';
import '../widgets/home/pip_today_panel.dart';
import 'companion_stage_screen.dart';
import 'settings/pip_settings_screen.dart';
import 'what_pip_knows_screen.dart';

/// Pip's home. Phones get the full-screen stage. At [PipSpace.wideBreakpoint]
/// and up (Windows, tablets) it becomes rail + stage + today panel, with
/// keyboard shortcuts: Ctrl+Space to talk, Ctrl+, for settings.
class PipHomeScreen extends StatelessWidget {
  const PipHomeScreen({super.key});

  void _talk(BuildContext context) {
    final audio = getIt<PipAudioCoordinator>();
    final cubit = context.read<PipStageCubit>();
    audio.isActiveListening ? audio.stopListening() : audio.startActiveListening(onQuery: cubit.handleQuery);
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.space, control: true): () => _talk(context),
      const SingleActivator(LogicalKeyboardKey.comma, control: true): () => PipSettingsScreen.open(context),
      const SingleActivator(LogicalKeyboardKey.keyB, control: true): () => context.read<PipStageCubit>().triggerBriefing(),
    };

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < PipSpace.wideBreakpoint) return const CompanionStageScreen();
            return _WideHome(showPanel: constraints.maxWidth >= 1100);
          },
        ),
      ),
    );
  }
}

class _WideHome extends StatelessWidget {
  final bool showPanel;

  const _WideHome({required this.showPanel});

  void _select(BuildContext context, int index) {
    final cubit = context.read<PipStageCubit>();
    switch (index) {
      case 1:
        cubit.setOverlay(CompanionOverlay.tasks);
      case 2:
        AlarmsRemindersScreen.open(context);
      case 3:
        WhatPipKnowsScreen.show(context, getIt<MemoryRepository>());
      case 4:
        PipSettingsScreen.open(context);
      default:
        cubit.dismissOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: 0,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => _select(context, i),
            leading: const Padding(
              padding: EdgeInsets.only(top: PipSpace.md, bottom: PipSpace.lg),
              child: Text('PIP',
                  style: TextStyle(color: PipColors.amber, fontWeight: FontWeight.w700, letterSpacing: 4, fontSize: 15)),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.smart_toy_outlined), label: Text('Pip')),
              NavigationRailDestination(icon: Icon(Icons.checklist), label: Text('Tasks')),
              NavigationRailDestination(icon: Icon(Icons.alarm), label: Text('Alarms')),
              NavigationRailDestination(icon: Icon(Icons.psychology_outlined), label: Text('Memory')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('Settings')),
            ],
          ),
          const VerticalDivider(width: 1),
          const Expanded(child: CompanionStageScreen(embedded: true)),
          if (showPanel) ...[
            const VerticalDivider(width: 1),
            const SizedBox(width: 320, child: PipTodayPanel()),
          ],
        ],
      ),
    );
  }
}
