import 'package:equatable/equatable.dart';
import '../../../../widgets/pip_params.dart';
import '../../../../widgets/companion/pip_overlay_and_dock_area.dart';

class PipStageState extends Equatable {
  final CompanionOverlay overlay;
  final PipMood currentMood;
  final String statusText;
  final String speechText;
  final bool isTypewriting;
  final bool isLoading;
  final bool isSleeping;
  final String userPromptCallout;
  final String briefingContent;
  final Map<String, dynamic>? pendingActionConfirmation;
  final bool isSilentCompanionMode;

  const PipStageState({
    this.overlay = CompanionOverlay.none,
    this.currentMood = PipMood.idle,
    this.statusText = "Tap Pip or ask a question",
    this.speechText = "",
    this.isTypewriting = false,
    this.isLoading = false,
    this.isSleeping = false,
    this.userPromptCallout = "",
    this.briefingContent = "",
    this.pendingActionConfirmation,
    this.isSilentCompanionMode = true,
  });

  PipStageState copyWith({
    CompanionOverlay? overlay,
    PipMood? currentMood,
    String? statusText,
    String? speechText,
    bool? isTypewriting,
    bool? isLoading,
    bool? isSleeping,
    String? userPromptCallout,
    String? briefingContent,
    Map<String, dynamic>? pendingActionConfirmation,
    bool clearPendingAction = false,
    bool? isSilentCompanionMode,
  }) {
    return PipStageState(
      overlay: overlay ?? this.overlay,
      currentMood: currentMood ?? this.currentMood,
      statusText: statusText ?? this.statusText,
      speechText: speechText ?? this.speechText,
      isTypewriting: isTypewriting ?? this.isTypewriting,
      isLoading: isLoading ?? this.isLoading,
      isSleeping: isSleeping ?? this.isSleeping,
      userPromptCallout: userPromptCallout ?? this.userPromptCallout,
      briefingContent: briefingContent ?? this.briefingContent,
      pendingActionConfirmation:
          clearPendingAction ? null : (pendingActionConfirmation ?? this.pendingActionConfirmation),
      isSilentCompanionMode: isSilentCompanionMode ?? this.isSilentCompanionMode,
    );
  }

  @override
  List<Object?> get props => [
        overlay,
        currentMood,
        statusText,
        speechText,
        isTypewriting,
        isLoading,
        isSleeping,
        userPromptCallout,
        briefingContent,
        pendingActionConfirmation,
        isSilentCompanionMode,
      ];
}
