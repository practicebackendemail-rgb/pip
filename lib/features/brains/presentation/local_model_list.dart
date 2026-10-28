import 'package:flutter/material.dart';
import '../../../core/localization/l10n_extension.dart';
import '../../../core/theme/pip_theme.dart';
import '../data/local_brain.dart';
import '../domain/local_model.dart';

/// The downloadable on-device models, each with its size, needs, ratings and
/// how well it fits this device. Used in settings and onboarding.
class LocalModelList extends StatelessWidget {
  const LocalModelList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brain = LocalBrain.instance;
    return ListenableBuilder(
      listenable: brain,
      builder: (context, _) {
        if (!LocalBrain.supported) return _Note(l10n.brainsNotSupported);
        final rec = brain.recommended;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (brain.ramGb != null) _Note(l10n.brainsYourDevice(brain.ramGb!.toStringAsFixed(0))),
            if (brain.lastError != null) _Note(brain.lastError!, error: true),
            for (final m in brain.catalog) _ModelCard(model: m, fit: DeviceFit.of(m, brain.ramGb, recommendedId: rec?.id)),
          ],
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  final bool error;
  const _Note(this.text, {this.error = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: context.tokens.space.sm),
        child: Text(text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: error ? context.tokens.colors.danger : null)),
      );
}

class _ModelCard extends StatelessWidget {
  final LocalModelSpec model;
  final ModelFit fit;
  const _ModelCard({required this.model, required this.fit});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final brain = LocalBrain.instance;
    final active = brain.active?.id == model.id;
    final installed = brain.isInstalled(model);
    final progress = brain.progressOf(model);
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.sm),
      child: Container(
        padding: EdgeInsets.all(t.space.md),
        decoration: BoxDecoration(
          color: t.colors.card,
          borderRadius: BorderRadius.circular(t.space.radius),
          border: Border.all(color: active ? t.colors.accent : t.colors.border, width: active ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${model.name}  ·  ${model.maker}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                FitBadge(fit),
              ],
            ),
            SizedBox(height: t.space.sm),
            SpecLine(l10n.modelGoodAt, model.goodAt),
            SpecLine(l10n.modelSize, model.sizeLabel),
            SpecLine(l10n.modelMemory, l10n.modelMemoryValue(model.ramGb)),
            SpecLine(l10n.modelSmarts, '', dots: model.smarts),
            SpecLine(l10n.modelSpeed, '', dots: model.speed),
            SpecLine(l10n.modelCost, '${l10n.modelFree} · ${l10n.modelLicense} ${model.license}'),
            SizedBox(height: t.space.sm),
            if (progress != null) ...[
              LinearProgressIndicator(value: progress / 100),
              SizedBox(height: t.space.xs),
              Text(l10n.modelDownloading(progress), style: Theme.of(context).textTheme.bodySmall),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (installed)
                    TextButton(onPressed: () => brain.remove(model), child: Text(l10n.modelRemove)),
                  SizedBox(width: t.space.sm),
                  active
                      ? Chip(avatar: const Icon(Icons.check, size: 16), label: Text(l10n.modelInUse))
                      : FilledButton.tonal(
                          onPressed: fit == ModelFit.tooBig || brain.isDownloading ? null : () => brain.use(model),
                          child: Text(installed ? l10n.modelUse : l10n.modelDownload(model.sizeLabel)),
                        ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class FitBadge extends StatelessWidget {
  final ModelFit fit;
  const FitBadge(this.fit, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final l10n = context.l10n;
    final (label, color) = switch (fit) {
      ModelFit.recommended => (l10n.fitRecommended, c.accent),
      ModelFit.good => (l10n.fitGood, c.success),
      ModelFit.heavy => (l10n.fitHeavy, c.warning),
      ModelFit.tooBig => (l10n.fitTooBig, c.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(context.tokens.space.pill)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// "Label   value" row; with [dots] it shows a 1–5 rating instead.
class SpecLine extends StatelessWidget {
  final String label;
  final String value;
  final int? dots;
  const SpecLine(this.label, this.value, {super.key, this.dots});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: style?.copyWith(color: t.colors.textMuted))),
          Expanded(
            child: dots == null
                ? Text(value, style: style)
                : Semantics(
                    label: '$dots of 5',
                    child: Text('●' * dots! + '○' * (5 - dots!), style: TextStyle(color: t.colors.accent, letterSpacing: 2)),
                  ),
          ),
        ],
      ),
    );
  }
}
