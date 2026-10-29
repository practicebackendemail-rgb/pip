import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/local_model.dart';
import 'local_llm_provider.dart';
import 'pip_brains.dart';

/// Pip's on-device brain: which models are downloaded, which one is in use,
/// and download progress. Runs through flutter_gemma (LiteRT-LM files work
/// on Android, iOS and desktop).
class LocalBrain extends ChangeNotifier {
  LocalBrain._();
  static final LocalBrain instance = LocalBrain._();

  static const _activeKey = 'brain_local_model';
  static const _device = MethodChannel('com.pip.companion/device');

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  List<LocalModelSpec> catalog = const [];
  double? ramGb;
  final Set<String> _installed = {};
  final Map<String, int> _progress = {};
  String? _activeId;
  String? lastError;
  bool _loaded = false;
  bool _initialized = false;

  bool isInstalled(LocalModelSpec m) => _installed.contains(m.fileName);
  int? progressOf(LocalModelSpec m) => _progress[m.id];
  bool get isDownloading => _progress.isNotEmpty;
  LocalModelSpec? get active => catalog.where((m) => m.id == _activeId && isInstalled(m)).firstOrNull;
  LocalModelSpec? get recommended => DeviceFit.recommend(catalog, ramGb);

  /// True when a downloaded model is selected and can answer.
  bool get ready => supported && active != null;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    catalog = LocalModelSpec.parseCatalog(await rootBundle.loadString('assets/brains/local_models.json'));
    _activeId = (await SharedPreferences.getInstance()).getString(_activeKey);
    ramGb = await _readRam();
    await _refreshInstalled();
  }

  Future<void> _init() async {
    if (_initialized) return;
    await FlutterGemma.initialize();
    _initialized = true;
  }

  Future<double?> _readRam() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final bytes = await _device.invokeMethod<int>('totalRam');
      return bytes == null ? null : bytes / (1024 * 1024 * 1024);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshInstalled() async {
    if (!supported) return;
    try {
      await _init();
      _installed
        ..clear()
        ..addAll(await FlutterGemma.listInstalledModels());
    } catch (e) {
      debugPrint('LocalBrain: listing models failed: $e');
    }
    notifyListeners();
  }

  /// Downloads [m] (if needed) and makes it the on-device brain.
  Future<bool> use(LocalModelSpec m) async {
    if (!supported || _progress.containsKey(m.id)) return false;
    lastError = null;
    _progress[m.id] = 0;
    notifyListeners();
    try {
      await _init();
      await FlutterGemma.installModel(
        modelType: ModelType.values.asNameMap()[m.type] ?? ModelType.general,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(m.url).withProgress((p) {
        _progress[m.id] = p;
        notifyListeners();
      }).install();
      _installed.add(m.fileName);
      _activeId = m.id;
      await (await SharedPreferences.getInstance()).setString(_activeKey, m.id);
      LocalLlmProvider.reset();
      await PipBrains.instance.onLocalReady();
      return true;
    } catch (e) {
      lastError = "Couldn't download ${m.name}. Check your connection and space, then try again.";
      debugPrint('LocalBrain: install failed: $e');
      return false;
    } finally {
      _progress.remove(m.id);
      notifyListeners();
    }
  }

  Future<void> remove(LocalModelSpec m) async {
    try {
      if (_activeId == m.id) await LocalLlmProvider.reset();
      await FlutterGemma.uninstallModel(m.fileName);
    } catch (e) {
      debugPrint('LocalBrain: uninstall failed: $e');
    }
    _installed.remove(m.fileName);
    if (_activeId == m.id) {
      _activeId = null;
      await (await SharedPreferences.getInstance()).remove(_activeKey);
    }
    notifyListeners();
  }

  LocalLlmProvider provider() => LocalLlmProvider(
        label: active?.name ?? 'On-device',
        modelType: ModelType.values.asNameMap()[active?.type] ?? ModelType.general,
        replyLanguage: replyLanguageFor(PlatformDispatcher.instance.locale),
      );

  /// The device language as a name a small model understands.
  @visibleForTesting
  static String replyLanguageFor(Locale locale) => switch (locale.languageCode) {
        'hi' => 'Hindi',
        'mr' => 'Marathi',
        'es' => 'Spanish',
        'fr' => 'French',
        'de' => 'German',
        'pt' => 'Portuguese',
        'ja' => 'Japanese',
        'zh' => 'Chinese',
        _ => 'English',
      };
}
