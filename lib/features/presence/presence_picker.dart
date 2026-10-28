import 'package:flutter/material.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/pip_theme.dart';
import 'presence_mode.dart';

/// Choose how much Pip speaks up on its own (Settings → Voice).
class PresencePicker extends StatelessWidget {
  const PresencePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = PresenceSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => RadioGroup<PresenceMode>(
        groupValue: settings.mode,
        onChanged: (m) {
          if (m != null) settings.setMode(m);
        },
        child: Column(children: [for (final m in PresenceMode.values) _Option(mode: m)]),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final PresenceMode mode;
  const _Option({required this.mode});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, detail, icon) = switch (mode) {
      PresenceMode.casual => (l10n.presenceCasual, l10n.presenceCasualDetail, Icons.emoji_emotions_outlined),
      PresenceMode.focus => (l10n.presenceFocus, l10n.presenceFocusDetail, Icons.center_focus_strong_outlined),
      PresenceMode.briefing => (l10n.presenceBriefing, l10n.presenceBriefingDetail, Icons.wb_sunny_outlined),
      PresenceMode.quiet => (l10n.presenceQuiet, l10n.presenceQuietDetail, Icons.do_not_disturb_on_outlined),
    };
    return RadioListTile<PresenceMode>(
      value: mode,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: context.tokens.colors.accent),
      title: Text(title),
      subtitle: Text(detail, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
