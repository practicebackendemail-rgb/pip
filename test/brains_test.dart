import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/brains/data/pip_brains.dart';
import 'package:personal_assistant/features/brains/domain/brain_routing.dart';
import 'package:personal_assistant/features/brains/domain/cloud_model_info.dart';
import 'package:personal_assistant/features/brains/domain/local_model.dart';

void main() {
  final catalog = LocalModelSpec.parseCatalog(File('assets/brains/local_models.json').readAsStringSync());

  group('Local catalogue', () {
    test('the shipped catalogue parses and every model is a LiteRT-LM file', () {
      expect(catalog, isNotEmpty);
      for (final m in catalog) {
        expect(m.url, endsWith('.litertlm'));
        expect(m.smarts, inInclusiveRange(1, 5));
      }
    });

    test('a broken catalogue reads as empty', () => expect(LocalModelSpec.parseCatalog('nope'), isEmpty));

    test('recommends the smartest model that fits the RAM', () {
      expect(DeviceFit.recommend(catalog, 6)!.id, 'gemma-4-e2b');
      expect(DeviceFit.recommend(catalog, 3)!.id, 'qwen3-0.6b');
      expect(DeviceFit.recommend(catalog, 1), isNull);
    });

    test('fit labels follow RAM', () {
      final big = catalog.firstWhere((m) => m.id == 'gemma-4-e4b');
      expect(DeviceFit.of(big, 12), ModelFit.good);
      expect(DeviceFit.of(big, 9), ModelFit.heavy);
      expect(DeviceFit.of(big, 4), ModelFit.tooBig);
      expect(DeviceFit.of(big, 12, recommendedId: big.id), ModelFit.recommended);
    });
  });

  group('Routing', () {
    final balanced = BrainRouting.preset(BrainPreset.balanced);

    test('uses the chosen brain when it is ready', () {
      final d = decideBrain(balanced, BrainJob.briefing, localReady: true, cloudReady: true);
      expect((d as UseBrain).brain, Brain.cloud);
    });

    test('private data never silently falls back to the cloud', () {
      final r = balanced.withFallback(BrainFallback.useOther);
      expect(decideBrain(r, BrainJob.privateData, localReady: false, cloudReady: true), isA<CannotRun>());
      final cmd = decideBrain(r, BrainJob.commands, localReady: false, cloudReady: true) as UseBrain;
      expect(cmd.brain, Brain.cloud);
      expect(cmd.isFallback, isTrue);
    });

    test('"ask" explains instead of switching', () {
      final d = decideBrain(balanced, BrainJob.commands, localReady: false, cloudReady: true);
      expect((d as CannotRun).reason, contains('on-device'));
    });

    test('presets are recognised and survive a save', () {
      final custom = balanced.withJob(BrainJob.briefing, Brain.local);
      expect(balanced.matchingPreset, BrainPreset.balanced);
      expect(custom.matchingPreset, isNull);
      final back = BrainRouting.fromJson(custom.toJson());
      expect(back.brainFor(BrainJob.briefing), Brain.local);
      expect(back.fallback, BrainFallback.ask);
    });
  });

  test('jobs are guessed from what was asked', () {
    expect(PipBrains.jobFor('What did I miss?'), BrainJob.privateData);
    expect(PipBrains.jobFor('Draft an email to Sam'), BrainJob.bigJobs);
    expect(PipBrains.jobFor('Set an alarm for 7'), BrainJob.commands);
  });

  test('cloud prices match by family and estimate a month', () {
    final flash = CloudModelInfo.lookup('gemini-3-flash-preview')!;
    expect(flash.family, 'Gemini Flash');
    expect(CloudModelInfo.lookup('gemini-2.5-flash-lite')!.family, 'Gemini Flash-Lite');
    expect(CloudModelInfo.lookup('claude-sonnet-5-5')!.smarts, 5);
    expect(CloudModelInfo.lookup('mystery-model'), isNull);
    expect(flash.monthlyEstimate(100), closeTo(100 * flash.costPerRequest(), 1e-9));
    expect(CloudModelInfo.formatUsd(0.001), 'under \$0.01');
  });
}
