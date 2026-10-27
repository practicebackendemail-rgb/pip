import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app/pip_app_flow.dart';
import 'core/di/injection.dart';
import 'core/domain/encrypted_memory_db.dart';
import 'core/domain/event_log.dart';
import 'core/domain/memory_repository.dart';
import 'core/domain/pip_emotion_state.dart';
import 'core/services/embedding_backfill_service.dart';
import 'core/services/llm_registry_service.dart';
import 'core/services/nightly_reflection_service.dart';
import 'core/services/pip_audio_coordinator.dart';
import 'core/services/pip_overlay_bridge.dart';
import 'core/services/pip_sfx_service.dart';
import 'core/services/pip_desktop_window_manager.dart';
import 'core/services/pip_notification_service.dart';
import 'core/services/sync/pip_cloud_sync_coordinator.dart';
import 'core/services/task_provider.dart';
import 'core/theme/pip_theme.dart';
import 'features/companion/presentation/cubit/pip_stage_cubit.dart';
import 'features/reminders/presentation/screens/alarms_reminders_screen.dart';
import 'widgets/companion/pip_overlay_widget.dart';

// Overlay entry point required by flutter_overlay_window
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PipOverlayWidget(),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await PipDesktopWindowManager.initialize();
  await PipSfxService.loadSetting();
  PipSfxService.preload();
  await PipNotificationService.init();

  runApp(const PersonalAssistantApp());
}

/// Lets notification taps open a screen from outside the widget tree.
final GlobalKey<NavigatorState> pipNavigatorKey = GlobalKey<NavigatorState>();

class PersonalAssistantApp extends StatefulWidget {
  const PersonalAssistantApp({super.key});

  @override
  State<PersonalAssistantApp> createState() => _PersonalAssistantAppState();
}

class _PersonalAssistantAppState extends State<PersonalAssistantApp>
    with WidgetsBindingObserver {
  // One cubit instance shared by the widget tree and the overlay bridge, so the
  // floating overlay mirrors the same state the app shows.
  late final PipStageCubit _stageCubit;
  PipOverlayBridge? _overlayBridge;
  late final EmbeddingBackfillService _backfill;
  String? _embeddingProviderId;
  Timer? _driftTimer;
  StreamSubscription<int>? _notificationTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stageCubit = getIt<PipStageCubit>();
    if (!kIsWeb && Platform.isAndroid) {
      _overlayBridge = PipOverlayBridge(
        cubit: _stageCubit,
        audioCoordinator: getIt<PipAudioCoordinator>(),
      )..start();
    }
    final registry = getIt<LlmRegistryService>();
    _backfill = EmbeddingBackfillService(
      memoryRepository: getIt<MemoryRepository>(),
      embeddingProvider: registry.getEmbeddingProvider,
    );
    registry.addListener(_onRegistryChanged);
    _driftTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => getIt<PipEmotionState>().evaluateTimeDrift(),
    );
    _logSession('session_started');
    _notificationTaps = PipNotificationService.openedItems.listen((_) => _openAlarms());
    // Reflection, then embedding backfill, once the first frame is up
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (PipNotificationService.launchedFromItem != null) _openAlarms();
      await PipNotificationService.rescheduleAll();
      await getIt<NightlyReflectionService>().runReflectionIfNeeded();
      if (EncryptedMemoryDatabase.instance.quarantinedPath != null) {
        _stageCubit.speak(
          "I couldn't unlock my old memory on this device, so I started a fresh one. "
          "If you have a backup, restore it from Settings → Sync and backup.",
        );
      }
      _embeddingProviderId = registry.getEmbeddingProvider().id;
      await _backfill.run();
    });
  }

  /// Re-embeds memories when the user switches embedding provider.
  void _onRegistryChanged() {
    final id = getIt<LlmRegistryService>().getEmbeddingProvider().id;
    if (_embeddingProviderId != null && id != _embeddingProviderId) _backfill.run();
    _embeddingProviderId = id;
  }

  void _openAlarms() {
    PipNotificationService.launchedFromItem = null;
    pipNavigatorKey.currentState?.push(AlarmsRemindersScreen.route());
  }

  void _logSession(String type) {
    final now = DateTime.now();
    getIt<EventLogService>().log(type, {'hour': now.hour, 'weekday': now.weekday});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    getIt<LlmRegistryService>().removeListener(_onRegistryChanged);
    _driftTimer?.cancel();
    _notificationTaps?.cancel();
    _overlayBridge?.dispose();
    _stageCubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _logSession('session_ended');
    if (state == AppLifecycleState.resumed) {
      _logSession('session_started');
      // Trigger reflection check and update emotion drift on app resume
      getIt<PipEmotionState>().evaluateTimeDrift();
      getIt<TaskProvider>().checkOverdueTasks();
      getIt<NightlyReflectionService>().runReflectionIfNeeded();
      // Phase 6: Sync cloud/local state on app resume (cooldown managed internally)
      getIt<PipCloudSyncCoordinator>().syncNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _stageCubit,
      child: MaterialApp(
        title: 'Pip',
        navigatorKey: pipNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: PipTheme.dark,
        home: const PipAppFlow(),
      ),
    );
  }
}
