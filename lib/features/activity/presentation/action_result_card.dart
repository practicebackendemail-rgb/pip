import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/l10n_extension.dart';
import '../../../core/theme/pip_theme.dart';
import '../domain/activity_entry.dart';
import 'activity_cubit.dart';
import 'activity_icons.dart';

/// The result of what Pip just did, with Undo. Slides in after an action and
/// clears itself after a few seconds; the next action replaces it.
class ActionResultCard extends StatefulWidget {
  const ActionResultCard({super.key});

  static const Duration visibleFor = Duration(seconds: 8);

  @override
  State<ActionResultCard> createState() => _ActionResultCardState();
}

class _ActionResultCardState extends State<ActionResultCard> {
  Timer? _hide;

  void _schedule(ActivityCubit cubit) {
    _hide?.cancel();
    _hide = Timer(ActionResultCard.visibleFor, cubit.dismissLatest);
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return BlocConsumer<ActivityCubit, ActivityState>(
      listenWhen: (a, b) => a.latest?.id != b.latest?.id && b.latest != null,
      listener: (context, state) => _schedule(context.read<ActivityCubit>()),
      buildWhen: (a, b) => a.latest != b.latest,
      builder: (context, state) {
        final entry = state.latest;
        return AnimatedSwitcher(
          duration: context.motion(t.motion.medium),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(a), child: child),
          ),
          child: entry == null ? const SizedBox.shrink() : _Card(key: ValueKey(entry.id), entry: entry),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final ActivityEntry entry;
  const _Card({super.key, required this.entry});

  Future<void> _undo(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.undoFailed;
    if (!await context.read<ActivityCubit>().undo(entry)) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.symmetric(horizontal: t.space.lg, vertical: t.space.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.space.radius),
        side: BorderSide(color: entry.undone ? t.colors.border : t.colors.success),
      ),
      color: t.colors.card,
      child: ListTile(
        leading: Icon(activityIcon(entry.kind), color: t.colors.accent),
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: entry.detail == null ? null : Text(entry.detail!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: entry.undone
            ? Text(l10n.undone, style: TextStyle(color: t.colors.textMuted))
            : entry.canUndo
                ? TextButton(onPressed: () => _undo(context), child: Text(l10n.undo))
                : null,
      ),
    );
  }
}
