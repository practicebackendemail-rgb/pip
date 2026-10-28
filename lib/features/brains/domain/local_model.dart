import 'dart:convert';

/// One model Pip can download and run on this device. The list lives in
/// assets/brains/local_models.json so it can change without code changes.
class LocalModelSpec {
  final String id;
  final String name;
  final String maker;
  final String url;

  /// flutter_gemma ModelType name (gemmaIt, qwen, qwen3, general…).
  final String type;
  final int sizeMb;

  /// RAM the device should have for this model to feel usable.
  final int ramGb;

  /// 1–5 ratings shown as dots.
  final int smarts;
  final int speed;
  final String goodAt;
  final String license;

  const LocalModelSpec({
    required this.id,
    required this.name,
    required this.maker,
    required this.url,
    required this.type,
    required this.sizeMb,
    required this.ramGb,
    required this.smarts,
    required this.speed,
    required this.goodAt,
    required this.license,
  });

  factory LocalModelSpec.fromJson(Map<String, dynamic> j) => LocalModelSpec(
        id: j['id'] as String,
        name: j['name'] as String,
        maker: j['maker'] as String? ?? '',
        url: j['url'] as String,
        type: j['type'] as String? ?? 'general',
        sizeMb: j['sizeMb'] as int,
        ramGb: j['ramGb'] as int,
        smarts: j['smarts'] as int,
        speed: j['speed'] as int,
        goodAt: j['goodAt'] as String? ?? '',
        license: j['license'] as String? ?? '',
      );

  static List<LocalModelSpec> parseCatalog(String json) {
    try {
      final models = (jsonDecode(json) as Map<String, dynamic>)['models'] as List;
      return [for (final m in models) LocalModelSpec.fromJson(m as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  String get sizeLabel => sizeMb >= 1000 ? '${(sizeMb / 1000).toStringAsFixed(1)} GB' : '$sizeMb MB';

  /// Downloaded file name (flutter_gemma keys installs by it).
  String get fileName => url.split('/').last;
}

enum ModelFit { recommended, good, heavy, tooBig }

/// How well a model suits a device, from its RAM. Unknown RAM (desktop
/// without a probe) is treated as a mid-range 8 GB machine.
abstract final class DeviceFit {
  static ModelFit of(LocalModelSpec m, double? ramGb, {String? recommendedId}) {
    final ram = ramGb ?? 8;
    if (ram < m.ramGb - 2) return ModelFit.tooBig;
    if (ram < m.ramGb) return ModelFit.heavy;
    return m.id == recommendedId ? ModelFit.recommended : ModelFit.good;
  }

  /// The smartest model that fits comfortably, preferring the faster one on ties.
  static LocalModelSpec? recommend(List<LocalModelSpec> catalog, double? ramGb) {
    final ram = ramGb ?? 8;
    final fitting = catalog.where((m) => m.ramGb <= ram).toList()
      ..sort((a, b) => b.smarts != a.smarts ? b.smarts.compareTo(a.smarts) : b.speed.compareTo(a.speed));
    return fitting.isEmpty ? null : fitting.first;
  }
}
