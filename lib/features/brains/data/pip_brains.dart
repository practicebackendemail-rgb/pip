import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/domain/llm_provider.dart';
import '../../../core/services/llm_registry_service.dart';
import '../domain/brain_routing.dart';
import 'local_brain.dart';

/// Thrown when routing forbids or can't find a brain; the message is for the user.
class BrainUnavailable implements Exception {
  final String message;
  const BrainUnavailable(this.message);
  @override
  String toString() => message;
}

/// Picks the local or cloud brain for each job, following the user's routing.
class PipBrains extends ChangeNotifier {
  PipBrains._();
  static final PipBrains instance = PipBrains._();

  static const _key = 'brain_routing';

  /// Until the user picks, everything goes to the cloud; the first on-device
  /// download switches to Balanced (see [onLocalReady]).
  BrainRouting routing = BrainRouting.preset(BrainPreset.maxSmarts);
  bool _customised = false;

  /// Which brain answered last; shown on activity entries.
  Brain? lastUsed;

  /// Cloud requests this calendar month, for the cost estimate.
  int cloudRequestsThisMonth = 0;

  static String get _countKey {
    final n = DateTime.now();
    return 'brain_cloud_count_${n.year}-${n.month}';
  }

  Future<void> _countCloud() async {
    cloudRequestsThisMonth++;
    await (await SharedPreferences.getInstance()).setInt(_countKey, cloudRequestsThisMonth);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    cloudRequestsThisMonth = prefs.getInt(_countKey) ?? 0;
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        routing = BrainRouting.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _customised = true;
      } catch (_) {}
    }
    await LocalBrain.instance.load();
    notifyListeners();
  }

  /// Called after an on-device model is ready: if the user never chose a
  /// routing, private jobs move onto the device.
  Future<void> onLocalReady() async {
    if (!_customised) await setRouting(BrainRouting.preset(BrainPreset.balanced));
  }

  Future<void> setRouting(BrainRouting r) async {
    routing = r;
    _customised = true;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(r.toJson()));
  }

  static bool cloudReady(LlmRegistryService llm) => switch (llm.activeProviderId) {
        'gemini' => llm.geminiKey.isNotEmpty,
        'openai' => llm.openAiKey.isNotEmpty,
        'anthropic' => llm.anthropicKey.isNotEmpty,
        'groq' => llm.groqKey.isNotEmpty,
        _ => true,
      };

  /// Guesses the job from what was asked.
  static BrainJob jobFor(String text) {
    final t = text.toLowerCase();
    if (RegExp(r'notification|what did i miss|missed|remember|memor|forget|about me').hasMatch(t)) {
      return BrainJob.privateData;
    }
    if (t.length > 160 || RegExp(r'\b(plan|draft|write|email|summari[sz]e|explain|compare|research)\b').hasMatch(t)) {
      return BrainJob.bigJobs;
    }
    return BrainJob.commands;
  }

  /// True when the last job went to the cloud but private data is meant to
  /// stay on-device, so only counts (not contents) may be sent.
  bool get cloudMustNotSeePrivate => lastUsed == Brain.cloud && routing.brainFor(BrainJob.privateData) == Brain.local;

  /// The provider for [job], or throws [BrainUnavailable].
  LlmProvider providerFor(BrainJob job, LlmRegistryService llm) {
    final decision = decideBrain(routing, job, localReady: LocalBrain.instance.ready, cloudReady: cloudReady(llm));
    switch (decision) {
      case UseBrain(:final brain):
        lastUsed = brain;
        if (brain == Brain.cloud) _countCloud();
        return brain == Brain.local ? LocalBrain.instance.provider() : llm.getActiveProvider();
      case CannotRun(:final reason):
        throw BrainUnavailable(reason);
    }
  }
}
