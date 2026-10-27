import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/di/injection.dart';
import '../../core/domain/memory_repository.dart';
import '../../core/services/pip_audio_coordinator.dart';
import '../../core/services/pip_desktop_window_manager.dart';
import '../../core/services/pip_overlay_manager.dart';
import '../../core/services/pip_sfx_service.dart';
import '../../core/theme/apple_theme.dart';
import '../../core/theme/app_motion_tokens.dart';
import '../../core/theme/pip_theme.dart';
import '../../features/reminders/presentation/screens/alarms_reminders_screen.dart';
import '../../screens/settings/pip_settings_screen.dart';
import '../../screens/what_pip_knows_screen.dart';
import '../chat_transcript_sheet.dart';

/// Top header containing live listening badge, overlay dismissal, and settings navigation.
class PipStageHeader extends StatelessWidget {
  final bool hasActiveOverlay;
  final VoidCallback onDismissOverlay;
  final List<Map<String, dynamic>> messages;
  final PipAudioCoordinator audioCoordinator;

  /// False on wide layouts, where the navigation rail already offers these.
  final bool showNavActions;

  const PipStageHeader({
    super.key,
    required this.hasActiveOverlay,
    required this.onDismissOverlay,
    required this.messages,
    required this.audioCoordinator,
    this.showNavActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (hasActiveOverlay)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                child: IconButton(
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white, size: 28),
                  onPressed: onDismissOverlay,
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: IconButton(
                  icon: const Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white, size: 22),
                  onPressed: () {
                    PipSfxService.blip();
                    ChatTranscriptSheet.show(context, messages);
                  },
                  tooltip: "Conversation History",
                ),
              ),

            // Push-to-Talk Status Capsule (iOS Liquid Frosted Glass)
            GestureDetector(
              onTap: () {
                PipSfxService.chirp();
                if (audioCoordinator.isActiveListening) {
                  audioCoordinator.stopListening();
                } else {
                  audioCoordinator.handleWakeDetected();
                }
              },
              child: AnimatedContainer(
                duration: AppMotionTokens.fast,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: audioCoordinator.isActiveListening
                      ? AppleTheme.accentRed.withValues(alpha: 0.35)
                      : const Color(0xFF1B1D26).withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: audioCoordinator.isActiveListening
                        ? AppleTheme.accentRed.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: audioCoordinator.isActiveListening
                            ? AppleTheme.accentRed
                            : const Color(0xFFE2A826),
                      ),
                    ).animate(target: audioCoordinator.isActiveListening ? 1 : 0).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3)),
                    const SizedBox(width: 8),
                    Text(
                      audioCoordinator.isActiveListening ? "Listening..." : "Push to Talk",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: audioCoordinator.isActiveListening ? Colors.white : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.black.withValues(alpha: 0.45),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!kIsWeb && Platform.isWindows)
                    IconButton(
                      icon: Icon(
                        PipDesktopWindowManager.isPetModeActive ? CupertinoIcons.square_arrow_up_on_square : CupertinoIcons.macwindow,
                        color: const Color(0xFFE2A826),
                        size: 20,
                      ),
                      tooltip: PipDesktopWindowManager.isPetModeActive ? "Expand to Window" : "Ambient Pet Mode",
                      onPressed: () async {
                        PipSfxService.chirp();
                        await PipDesktopWindowManager.togglePetMode();
                      },
                    ),
                  if (!kIsWeb && Platform.isAndroid)
                    IconButton(
                      icon: const Icon(CupertinoIcons.layers_alt, color: Color(0xFF6FBF73), size: 20),
                      tooltip: "Floating Overlay Mode",
                      onPressed: () async {
                        PipSfxService.chirp();
                        await PipOverlayManager.showOverlay();
                      },
                    ),
                  if (showNavActions) ...[
                    IconButton(
                      icon: const Icon(Icons.alarm, color: PipColors.ink, size: 22),
                      tooltip: "Alarms & reminders",
                      onPressed: () {
                        PipSfxService.blip();
                        AlarmsRemindersScreen.open(context);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.psychology_outlined, color: PipColors.ink, size: 22),
                      tooltip: "What Pip knows",
                      onPressed: () {
                        PipSfxService.blip();
                        WhatPipKnowsScreen.show(context, getIt<MemoryRepository>());
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: PipColors.ink, size: 21),
                      tooltip: "Settings",
                      onPressed: () {
                        PipSfxService.blip();
                        PipSettingsScreen.open(context);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
