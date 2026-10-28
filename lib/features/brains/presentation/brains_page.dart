import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/localization/l10n_extension.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/llm_registry_service.dart';
import '../../../core/theme/pip_theme.dart';
import '../../../widgets/pip_guide.dart';
import '../../../widgets/pip_params.dart';
import '../data/pip_brains.dart';
import '../domain/brain_routing.dart';
import '../domain/cloud_model_info.dart';
import 'local_model_list.dart';

/// Settings → Brains: the on-device model, the cloud model, and which one
/// handles each kind of job.
class BrainsPage extends StatelessWidget {
  const BrainsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.brainsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.fromLTRB(t.space.lg, 0, t.space.lg, t.space.xxl),
            children: [
              PipGuide(message: l10n.brainsIntro, mood: PipMood.happy, pipWidth: 88),
              _Heading(l10n.brainsLocalHeading, l10n.brainsLocalDetail),
              const LocalModelList(),
              _Heading(l10n.brainsCloudHeading, l10n.brainsCloudDetail),
              const _CloudCard(),
              _Heading(l10n.brainsRoutingHeading, l10n.brainsRoutingDetail),
              const _RoutingCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String title;
  final String detail;
  const _Heading(this.title, this.detail);

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: context.tokens.space.xl, bottom: context.tokens.space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.all(t.space.md),
      decoration: BoxDecoration(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(t.space.radius),
        border: Border.all(color: t.colors.border),
      ),
      child: child,
    );
  }
}

class _CloudCard extends StatelessWidget {
  const _CloudCard();

  static const _names = {'gemini': 'Gemini', 'openai': 'OpenAI', 'anthropic': 'Anthropic', 'groq': 'Groq', 'ollama': 'Ollama'};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final llm = getIt<LlmRegistryService>();
    return ListenableBuilder(
      listenable: Listenable.merge([llm, PipBrains.instance]),
      builder: (context, _) {
        final ready = PipBrains.cloudReady(llm);
        final change = Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push(AppRoutes.settingsAiModel),
            child: Text(ready ? l10n.cloudChange : l10n.cloudAddKey),
          ),
        );
        if (!ready) return _Card(child: Column(children: [Text(l10n.cloudNoKey), change]));

        final model = llm.chatModel(llm.activeProviderId);
        final info = CloudModelInfo.lookup(model);
        final count = PipBrains.instance.cloudRequestsThisMonth;
        final small = Theme.of(context).textTheme.bodySmall;
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${_names[llm.activeProviderId] ?? llm.activeProviderId}  ·  $model',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (info?.freeTier == true)
                    Text(l10n.cloudFreeTier,
                        style: TextStyle(color: t.colors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              SizedBox(height: t.space.sm),
              if (info == null)
                Text(l10n.cloudUnknownModel, style: small)
              else ...[
                SpecLine(l10n.modelGoodAt, info.goodAt),
                SpecLine(l10n.modelSmarts, '', dots: info.smarts),
                SpecLine(l10n.modelCost,
                    l10n.cloudPrice(info.inPerMillion.toStringAsFixed(2), info.outPerMillion.toStringAsFixed(2))),
                SpecLine('', l10n.cloudPerRequest(CloudModelInfo.formatUsd(info.costPerRequest()))),
                SizedBox(height: t.space.xs),
                Text(l10n.cloudMonthly(count, CloudModelInfo.formatUsd(info.monthlyEstimate(count))), style: small),
              ],
              change,
            ],
          ),
        );
      },
    );
  }
}

class _RoutingCard extends StatelessWidget {
  const _RoutingCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final brains = PipBrains.instance;
    String jobLabel(BrainJob j) => switch (j) {
          BrainJob.privateData => l10n.jobPrivate,
          BrainJob.commands => l10n.jobCommands,
          BrainJob.briefing => l10n.jobBriefing,
          BrainJob.bigJobs => l10n.jobBigJobs,
        };
    String presetLabel(BrainPreset p) => switch (p) {
          BrainPreset.private => l10n.presetPrivate,
          BrainPreset.balanced => l10n.presetBalanced,
          BrainPreset.maxSmarts => l10n.presetMaxSmarts,
        };
    return ListenableBuilder(
      listenable: brains,
      builder: (context, _) {
        final r = brains.routing;
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.presetLabel, style: Theme.of(context).textTheme.labelMedium),
              SizedBox(height: t.space.xs),
              Wrap(
                spacing: t.space.sm,
                children: [
                  for (final p in BrainPreset.values)
                    ChoiceChip(
                      label: Text(presetLabel(p)),
                      selected: r.matchingPreset == p,
                      onSelected: (_) => brains.setRouting(BrainRouting.preset(p)),
                    ),
                ],
              ),
              const Divider(height: 24),
              for (final job in BrainJob.values)
                Padding(
                  padding: EdgeInsets.only(bottom: t.space.sm),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: t.space.xs,
                    children: [
                      Text(jobLabel(job)),
                      SegmentedButton<Brain>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                              value: Brain.local,
                              label: Text(l10n.brainLocal),
                              icon: const Icon(Icons.lock_outline, size: 16)),
                          ButtonSegment(
                              value: Brain.cloud,
                              label: Text(l10n.brainCloud),
                              icon: const Icon(Icons.cloud_outlined, size: 16)),
                        ],
                        selected: {r.brainFor(job)},
                        onSelectionChanged: (s) => brains.setRouting(r.withJob(job, s.first)),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Text(l10n.fallbackLabel, style: Theme.of(context).textTheme.labelMedium),
              DropdownButton<BrainFallback>(
                value: r.fallback,
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: BrainFallback.ask, child: Text(l10n.fallbackAsk)),
                  DropdownMenuItem(value: BrainFallback.useOther, child: Text(l10n.fallbackUseOther)),
                  DropdownMenuItem(value: BrainFallback.fail, child: Text(l10n.fallbackFail)),
                ],
                onChanged: (f) {
                  if (f != null) brains.setRouting(r.withFallback(f));
                },
              ),
              Text(l10n.fallbackNote, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}
