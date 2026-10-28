import 'package:flutter/material.dart';
import '../../../core/theme/pip_theme.dart';
import '../../brains/presentation/local_model_list.dart';
import '../onboarding_flow.dart';

/// Optional on-device brain. Downloads keep going after Continue.
class LocalBrainStep extends StatelessWidget {
  final ValueChanged<PipStepState> onState;
  const LocalBrainStep({super.key, required this.onState});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(PipSpace.xl),
        children: const [LocalModelList()],
      );
}
