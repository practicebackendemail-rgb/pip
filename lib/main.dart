import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/di/injection.dart';
import 'core/domain/pip_emotion_state.dart';
import 'core/services/nightly_reflection_service.dart';
import 'core/services/pip_audio_coordinator.dart';
import 'core/services/pip_overlay_bridge.dart';
import 'core/services/pip_desktop_window_manager.dart';
import 'core/services/sync/pip_cloud_sync_coordinator.dart';
import 'core/theme/apple_theme.dart';
import 'features/companion/presentation/cubit/pip_stage_cubit.dart';
import 'screens/companion_stage_screen.dart';
import 'screens/onboarding_setup_screen.dart';
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

  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding =
      prefs.getBool('has_completed_onboarding') ?? false;

  runApp(PersonalAssistantApp(showOnboarding: !hasCompletedOnboarding));
}

class PersonalAssistantApp extends StatefulWidget {
  final bool showOnboarding;

  const PersonalAssistantApp({super.key, required this.showOnboarding});

  @override
  State<PersonalAssistantApp> createState() => _PersonalAssistantAppState();
}

class _PersonalAssistantAppState extends State<PersonalAssistantApp>
    with WidgetsBindingObserver {
  late bool _onboardingActive;
  // One cubit instance shared by the widget tree and the overlay bridge, so the
  // floating overlay mirrors the same state the app shows.
  late final PipStageCubit _stageCubit;
  PipOverlayBridge? _overlayBridge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onboardingActive = widget.showOnboarding;
    _stageCubit = getIt<PipStageCubit>();
    if (!kIsWeb && Platform.isAndroid) {
      _overlayBridge = PipOverlayBridge(
        cubit: _stageCubit,
        audioCoordinator: getIt<PipAudioCoordinator>(),
      )..start();
    }
    // Trigger reflection on initial application startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<NightlyReflectionService>().runReflectionIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayBridge?.dispose();
    _stageCubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Trigger reflection check and update emotion drift on app resume
      getIt<PipEmotionState>().evaluateTimeDrift();
      getIt<NightlyReflectionService>().runReflectionIfNeeded();
      // Phase 6: Sync cloud/local state on app resume (cooldown managed internally)
      getIt<PipCloudSyncCoordinator>().syncNow();
    }
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    setState(() => _onboardingActive = false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _stageCubit,
      child: MaterialApp(
        title: 'Pip - Desk Companion',
        debugShowCheckedModeBanner: false,
        theme: AppleTheme.darkTheme,
        home: _onboardingActive
            ? OnboardingSetupScreen(onComplete: _finishOnboarding)
            : const CompanionStageScreen(),
      ),
    );
  }
}
