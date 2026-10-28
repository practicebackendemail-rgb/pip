import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../features/presence/presence_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Service responsible for managing Pip's desktop window modes on Windows.
/// The three Windows sizes: the whole app, a small always-on-top card, and
/// just Pip's eyes resting above the taskbar.
enum DesktopSize { full, mini, peek }

class PipDesktopWindowManager with TrayListener, WindowListener {
  PipDesktopWindowManager._();
  static final PipDesktopWindowManager instance = PipDesktopWindowManager._();

  static bool _isClickThroughActive = false;

  /// Current size; the app swaps its UI when this changes.
  static final ValueNotifier<DesktopSize> size = ValueNotifier(DesktopSize.full);

  static const Size fullSize = Size(1180, 780);
  static const Size miniSize = Size(380, 230);
  static const Size peekSize = Size(150, 64);

  /// Mini or Peek: frameless, always on top, out of the taskbar.
  static bool get isPetModeActive => size.value != DesktopSize.full;
  static bool get isClickThroughActive => _isClickThroughActive;
  static bool get isDoNotDisturb => PresenceSettings.instance.mode == PresenceMode.quiet;

  static const String _prefPosX = 'pip_window_pos_x';
  static const String _prefPosY = 'pip_window_pos_y';
  static const String _prefLaunchStartup = 'pip_launch_at_startup';

  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isWindows) return;

    try {
      await windowManager.ensureInitialized();
      await hotKeyManager.unregisterAll();

      // Launch at startup setup
      try {
        LaunchAtStartup.instance.setup(
          appName: 'Pip Desk Companion',
          appPath: Platform.resolvedExecutable,
        );
        final prefs = await SharedPreferences.getInstance();
        final shouldLaunch = prefs.getBool(_prefLaunchStartup) ?? false;
        if (shouldLaunch) {
          await LaunchAtStartup.instance.enable();
        } else {
          await LaunchAtStartup.instance.disable();
        }
      } catch (e) {
        debugPrint('Launch at startup initialization warning: $e');
      }

      const windowOptions = WindowOptions(
        size: Size(1180, 780),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      // Register Tray Menu with non-fatal safety catch
      try {
        trayManager.addListener(instance);
        await _setupTray();
      } catch (e) {
        debugPrint('System tray setup warning (non-fatal): $e');
      }

      // Register Global HotKey (Ctrl + Shift + P)
      final hotKey = HotKey(
        key: PhysicalKeyboardKey.keyP,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      // Summon Pip from anywhere, already listening. Pet mode stays in the tray.
      await hotKeyManager.register(hotKey, keyDownHandler: (_) => summon());
    } catch (e) {
      debugPrint("Desktop windowManager initialize error: $e");
    }
  }

  static Future<void> _setupTray() async {
    try {
      await trayManager.setIcon('assets/icons/app_icon.ico');
      final menu = Menu(items: [
        MenuItem(key: 'show_pip', label: 'Show Pip'),
        MenuItem(key: 'talk', label: 'Talk to Pip (Ctrl+Shift+P)'),
        MenuItem.separator(),
        MenuItem(key: 'size_full', label: 'Full window'),
        MenuItem(key: 'size_mini', label: 'Mini (always on top)'),
        MenuItem(key: 'size_peek', label: 'Peek (eyes on the taskbar)'),
        MenuItem.separator(),
        MenuItem(key: 'toggle_dnd', label: 'Toggle Do Not Disturb'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Exit Application'),
      ]);
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint("Tray setup warning: $e");
    }
  }

  static Future<void> setLaunchAtStartup(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefLaunchStartup, enable);
    if (kIsWeb || !Platform.isWindows) return;
    try {
      if (enable) {
        await LaunchAtStartup.instance.enable();
      } else {
        await LaunchAtStartup.instance.disable();
      }
    } catch (e) {
      debugPrint('Error toggling launch at startup: $e');
    }
  }

  static Future<bool> isLaunchAtStartupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefLaunchStartup) ?? false;
  }

  /// True while Mini is showing because the mouse hovered Peek; Mini then
  /// sinks back to Peek when the mouse leaves.
  static bool raisedFromPeek = false;

  static Future<void> raiseFromPeek() async {
    await setDesktopSize(DesktopSize.mini);
    raisedFromPeek = true;
  }

  /// Switches between Full, Mini and Peek.
  static Future<void> setDesktopSize(DesktopSize next) async {
    if (kIsWeb || !Platform.isWindows || next == size.value) return;
    raisedFromPeek = false;
    final from = size.value;
    try {
      if (from == DesktopSize.mini) await saveCurrentPosition();
      if (next == DesktopSize.full) {
        size.value = next;
        await windowManager.setIgnoreMouseEvents(false);
        await windowManager.setSkipTaskbar(false);
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
        await windowManager.setHasShadow(true);
        await windowManager.setSize(fullSize);
        await windowManager.center();
      } else {
        if (from == DesktopSize.full) {
          await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
          await windowManager.setSkipTaskbar(true);
          await windowManager.setAlwaysOnTop(true);
          await windowManager.setBackgroundColor(Colors.transparent);
          await windowManager.setHasShadow(false);
        }
        size.value = next;
        if (next == DesktopSize.mini) {
          await windowManager.setSize(miniSize);
          await _restorePositionOrAlign();
        } else {
          await windowManager.setSize(peekSize);
          await _restOnTaskbar();
        }
      }
      await windowManager.show();
    } catch (e) {
      debugPrint('Changing desktop size failed: $e');
    }
  }

  /// Bottom-right corner of the work area, so Pip sits right on the taskbar.
  static Future<void> _restOnTaskbar() async {
    final d = await screenRetriever.getPrimaryDisplay();
    final pos = d.visiblePosition ?? Offset.zero;
    final area = d.visibleSize ?? d.size;
    await windowManager.setPosition(Offset(
      pos.dx + area.width - peekSize.width - 24,
      pos.dy + area.height - peekSize.height,
    ));
  }

  static Future<void> enterAmbientPetMode() => setDesktopSize(DesktopSize.mini);

  static Future<void> exitAmbientPetMode() => setDesktopSize(DesktopSize.full);

  static Future<void> _restorePositionOrAlign() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_prefPosX);
    final y = prefs.getDouble(_prefPosY);

    if (x != null && y != null) {
      final displays = await screenRetriever.getAllDisplays();
      bool isVisible = false;
      for (final d in displays) {
        if (x >= d.visiblePosition!.dx &&
            x <= d.visiblePosition!.dx + d.size.width &&
            y >= d.visiblePosition!.dy &&
            y <= d.visiblePosition!.dy + d.size.height) {
          isVisible = true;
          break;
        }
      }

      if (isVisible) {
        await windowManager.setPosition(Offset(x, y));
        return;
      }
    }
    await windowManager.setAlignment(Alignment.bottomRight);
  }

  static Future<void> saveCurrentPosition() async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      final pos = await windowManager.getPosition();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefPosX, pos.dx);
      await prefs.setDouble(_prefPosY, pos.dy);
    } catch (e) {
      debugPrint("Error saving window position: $e");
    }
  }

  static Future<void> setClickThrough(bool enable) async {
    if (kIsWeb || !Platform.isWindows || !isPetModeActive) return;
    _isClickThroughActive = enable;
    await windowManager.setIgnoreMouseEvents(enable, forward: true);
  }

  /// Called after [summon] brings Pip forward; the app opens the mic.
  static VoidCallback? onSummon;

  /// Brings Pip to the front (from the tray, behind other windows, or pet
  /// mode) and asks the app to start listening.
  static Future<void> summon() async {
    try {
      // Peek rises to Mini; Mini and Full stay as they are.
      if (size.value == DesktopSize.peek) await setDesktopSize(DesktopSize.mini);
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Summon failed: $e');
    }
    onSummon?.call();
  }

  static Future<void> togglePetMode() =>
      setDesktopSize(isPetModeActive ? DesktopSize.full : DesktopSize.mini);

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_pip') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'talk') {
      await summon();
    } else if (menuItem.key == 'size_full') {
      await setDesktopSize(DesktopSize.full);
    } else if (menuItem.key == 'size_mini') {
      await setDesktopSize(DesktopSize.mini);
    } else if (menuItem.key == 'size_peek') {
      await setDesktopSize(DesktopSize.peek);
    } else if (menuItem.key == 'toggle_dnd') {
      await PresenceSettings.instance.toggleQuiet();
    } else if (menuItem.key == 'quit') {
      await windowManager.destroy();
    }
  }
}
