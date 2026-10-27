import 'package:flutter/material.dart';
import '../../../core/services/pip_profile_service.dart';
import '../../../core/theme/pip_theme.dart';
import '../../../widgets/pip_params.dart';
import '../onboarding_flow.dart';

class NameStep extends StatefulWidget {
  final ValueChanged<PipStepState> onState;

  const NameStep({super.key, required this.onState});

  @override
  State<NameStep> createState() => _NamePipStepState();
}

class _NamePipStepState extends State<NameStep> implements OnboardingStepController {
  final TextEditingController _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    PipProfileService.userName().then((n) {
      if (n != null && mounted) _name.text = n;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _changed(String value) {
    final name = value.trim();
    widget.onState(PipStepState(
      name.isEmpty ? "Hi! I'm Pip. What should I call you?" : 'Hi $name! Great name.',
      mood: name.isEmpty ? PipMood.happy : PipMood.excited,
    ));
  }

  @override
  Future<bool> commit() async {
    await PipProfileService.setUserName(_name.text);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(PipSpace.xl),
      children: [
        Text('Your name', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: PipSpace.sm),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: _changed,
          decoration: const InputDecoration(hintText: 'Sam'),
        ),
        const SizedBox(height: PipSpace.sm),
        Text('Pip uses it to greet you. You can skip this.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
