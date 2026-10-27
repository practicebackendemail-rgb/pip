import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/pip_audio_coordinator.dart';
import '../../core/theme/apple_theme.dart';
import '../glass_container.dart';

/// Floating bottom action dock with mic button, text field, and quick action chips.
class PipActionDock extends StatelessWidget {
  final bool showChips;
  final PipAudioCoordinator audioCoordinator;
  final TextEditingController textController;
  final ValueChanged<String> onSubmit;
  final VoidCallback onTriggerBriefing;
  final VoidCallback onTriggerObjectives;
  final VoidCallback onTriggerTranscript;

  const PipActionDock({
    super.key,
    required this.showChips,
    required this.audioCoordinator,
    required this.textController,
    required this.onSubmit,
    required this.onTriggerBriefing,
    required this.onTriggerObjectives,
    required this.onTriggerTranscript,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showChips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChip("☀️ Briefing", onTriggerBriefing),
                const SizedBox(width: 8),
                _buildChip("📋 Objectives", onTriggerObjectives),
                const SizedBox(width: 8),
                _buildChip("📜 Transcript", onTriggerTranscript),
              ],
            ),
          ),
        const SizedBox(height: 10),
        GlassContainer(
          borderRadius: 30,
          backgroundColor: const Color(0xFF14161F).withValues(alpha: 0.85),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  if (audioCoordinator.isActiveListening) {
                    await audioCoordinator.stopListening();
                  } else {
                    await audioCoordinator.startActiveListening(
                      onQuery: (words) {
                        textController.text = words;
                        onSubmit(words);
                      },
                    );
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: audioCoordinator.isActiveListening
                        ? AppleTheme.accentRed
                        : const Color(0xFFE2A826).withValues(alpha: 0.25),
                  ),
                  child: Icon(
                    audioCoordinator.isActiveListening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
                    color: audioCoordinator.isActiveListening ? Colors.white : const Color(0xFFE2A826),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: textController,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                  decoration: const InputDecoration(
                    hintText: 'Talk to Pip...',
                    hintStyle: TextStyle(color: AppleTheme.textTertiary),
                    border: InputBorder.none,
                  ),
                  onSubmitted: onSubmit,
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.arrow_up_circle_fill, color: Color(0xFFE2A826), size: 30),
                onPressed: () => onSubmit(textController.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14161F).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
      ),
    );
  }
}
