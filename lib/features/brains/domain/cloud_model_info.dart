/// What a cloud model costs and is good at, matched loosely by name so new
/// versions ("gemini-3-flash-preview") still find their family. Prices are
/// USD per million tokens and only a guide; providers change them.
class CloudModelInfo {
  final String family;
  final double inPerMillion;
  final double outPerMillion;
  final int smarts;
  final bool freeTier;
  final String goodAt;

  const CloudModelInfo({
    required this.family,
    required this.inPerMillion,
    required this.outPerMillion,
    required this.smarts,
    required this.goodAt,
    this.freeTier = false,
  });

  static const _families = <(String, CloudModelInfo)>[
    ('flash-lite', CloudModelInfo(family: 'Gemini Flash-Lite', inPerMillion: .10, outPerMillion: .40, smarts: 3, freeTier: true, goodAt: 'Cheap, fast everyday asks')),
    ('flash', CloudModelInfo(family: 'Gemini Flash', inPerMillion: .30, outPerMillion: 2.50, smarts: 4, freeTier: true, goodAt: 'Planning, briefings, listening to audio')),
    ('gemini', CloudModelInfo(family: 'Gemini Pro', inPerMillion: 1.25, outPerMillion: 10, smarts: 5, freeTier: true, goodAt: 'Hard reasoning, long documents')),
    ('haiku', CloudModelInfo(family: 'Claude Haiku', inPerMillion: 1, outPerMillion: 5, smarts: 4, goodAt: 'Fast, reliable tool use')),
    ('opus', CloudModelInfo(family: 'Claude Opus', inPerMillion: 5, outPerMillion: 25, smarts: 5, goodAt: 'The deepest thinking; costs the most')),
    ('claude', CloudModelInfo(family: 'Claude Sonnet', inPerMillion: 3, outPerMillion: 15, smarts: 5, goodAt: 'Best reasoning and writing')),
    ('mini', CloudModelInfo(family: 'GPT mini', inPerMillion: .25, outPerMillion: 2, smarts: 4, goodAt: 'Good value all-rounder')),
    ('gpt', CloudModelInfo(family: 'GPT', inPerMillion: 1.25, outPerMillion: 10, smarts: 5, goodAt: 'Strong all-round reasoning')),
    ('llama', CloudModelInfo(family: 'Llama on Groq', inPerMillion: .59, outPerMillion: .79, smarts: 3, freeTier: true, goodAt: 'Very fast replies')),
  ];

  static CloudModelInfo? lookup(String model) {
    final m = model.toLowerCase();
    for (final (key, info) in _families) {
      if (m.contains(key)) return info;
    }
    return null;
  }

  /// Rough USD cost of one request with typical Pip prompt sizes.
  double costPerRequest({int inTokens = 2500, int outTokens = 300}) =>
      (inTokens * inPerMillion + outTokens * outPerMillion) / 1e6;

  /// Monthly estimate from how many requests Pip made in the last 30 days.
  double monthlyEstimate(int requestsPerMonth) => costPerRequest() * requestsPerMonth;

  static String formatUsd(double v) => v < .01 ? 'under \$0.01' : '\$${v.toStringAsFixed(2)}';
}
