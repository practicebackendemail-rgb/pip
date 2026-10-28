/// The kinds of work Pip routes between its two brains.
enum BrainJob {
  /// Anything that reads notifications or Pip's memories.
  privateData,

  /// Everyday spoken or typed commands.
  commands,

  /// The daily briefing.
  briefing,

  /// Planning, email drafts and other long jobs.
  bigJobs,
}

enum Brain { local, cloud }

enum BrainPreset { private, balanced, maxSmarts }

/// What to do when the chosen brain can't run (no model, no key, offline).
enum BrainFallback { ask, useOther, fail }

/// Who handles each job. Pure data; persisted by BrainSettings.
class BrainRouting {
  final Map<BrainJob, Brain> jobs;
  final BrainFallback fallback;

  const BrainRouting({required this.jobs, this.fallback = BrainFallback.ask});

  static BrainRouting preset(BrainPreset p) => switch (p) {
        BrainPreset.private => const BrainRouting(jobs: {
            BrainJob.privateData: Brain.local,
            BrainJob.commands: Brain.local,
            BrainJob.briefing: Brain.local,
            BrainJob.bigJobs: Brain.local,
          }, fallback: BrainFallback.fail),
        BrainPreset.balanced => const BrainRouting(jobs: {
            BrainJob.privateData: Brain.local,
            BrainJob.commands: Brain.local,
            BrainJob.briefing: Brain.cloud,
            BrainJob.bigJobs: Brain.cloud,
          }),
        BrainPreset.maxSmarts => const BrainRouting(jobs: {
            BrainJob.privateData: Brain.cloud,
            BrainJob.commands: Brain.cloud,
            BrainJob.briefing: Brain.cloud,
            BrainJob.bigJobs: Brain.cloud,
          }, fallback: BrainFallback.useOther),
      };

  Brain brainFor(BrainJob job) => jobs[job] ?? Brain.cloud;

  BrainRouting withJob(BrainJob job, Brain brain) => BrainRouting(jobs: {...jobs, job: brain}, fallback: fallback);
  BrainRouting withFallback(BrainFallback f) => BrainRouting(jobs: jobs, fallback: f);

  BrainPreset? get matchingPreset {
    for (final p in BrainPreset.values) {
      final r = preset(p);
      if (r.fallback == fallback && BrainJob.values.every((j) => r.brainFor(j) == brainFor(j))) return p;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'jobs': {for (final e in jobs.entries) e.key.name: e.value.name},
        'fallback': fallback.name,
      };

  factory BrainRouting.fromJson(Map<String, dynamic> j) {
    final base = preset(BrainPreset.balanced);
    final saved = (j['jobs'] as Map?) ?? const {};
    return BrainRouting(
      jobs: {
        for (final job in BrainJob.values)
          job: Brain.values.asNameMap()[saved[job.name]] ?? base.brainFor(job),
      },
      fallback: BrainFallback.values.asNameMap()[j['fallback']] ?? base.fallback,
    );
  }
}

/// The outcome of routing one job.
sealed class BrainDecision {
  const BrainDecision();
}

class UseBrain extends BrainDecision {
  final Brain brain;

  /// True when this isn't the brain the routing asked for.
  final bool isFallback;
  const UseBrain(this.brain, {this.isFallback = false});
}

/// Neither brain may run this; [reason] is said to the user.
class CannotRun extends BrainDecision {
  final String reason;
  const CannotRun(this.reason);
}

/// Decides which brain runs a job given what's available. Private data never
/// silently falls back to the cloud: with fallback "ask" the user is asked.
BrainDecision decideBrain(
  BrainRouting routing,
  BrainJob job, {
  required bool localReady,
  required bool cloudReady,
}) {
  final want = routing.brainFor(job);
  final ready = want == Brain.local ? localReady : cloudReady;
  if (ready) return UseBrain(want);

  final other = want == Brain.local ? Brain.cloud : Brain.local;
  final otherReady = other == Brain.local ? localReady : cloudReady;
  final missing = want == Brain.local
      ? "My on-device brain isn't downloaded yet."
      : "My cloud brain has no working key.";

  if (!otherReady) return CannotRun('$missing Set one up in Settings, Brains.');
  final leavesDevice = other == Brain.cloud && job == BrainJob.privateData;
  return switch (routing.fallback) {
    BrainFallback.useOther when !leavesDevice => UseBrain(other, isFallback: true),
    BrainFallback.fail => CannotRun('$missing You asked me to keep this on your device.'),
    _ => CannotRun(other == Brain.cloud
        ? "$missing To let the cloud do it, change the fallback in Settings, Brains."
        : "$missing I can use the on-device brain instead; switch it in Settings, Brains."),
  };
}
