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
class PipDesktopWindowManager with TrayListener, WindowListener {
  PipDesktopWindowManager._();
  static final PipDesktopWindowManager instance = PipDesktopWindowManager._();

  static bool _isPetModeActive = false;
  static bool _isClickThroughActive = false;

  static bool get isPetModeActive => _isPetModeActive;
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
        MenuItem(key: 'toggle_pet', label: 'Toggle Pet Mode'),
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

  static Future<void> enterAmbientPetMode() async {
    if (kIsWeb || !Platform.isWindows) return;

    try {
      _isPetModeActive = true;
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setSize(const Size(300, 340));
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setHasShadow(false);

      await _restorePositionOrAlign();
    } catch (e) {
      debugPrint("Error entering ambient pet mode: $e");
    }
  }

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

  static Future<void> exitAmbientPetMode() async {
    if (kIsWeb || !Platform.isWindows) return;

    try {
      _isPetModeActive = false;
      await windowManager.setSkipTaskbar(false);
      await windowManager.setIgnoreMouseEvents(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setSize(const Size(1180, 780));
      await windowManager.setAlwaysOnTop(false);
      await windowManager.center();
    } catch (e) {
      debugPrint("Error exiting ambient pet mode: $e");
    }
  }

  static Future<void> setClickThrough(bool enable) async {
    if (kIsWeb || !Platform.isWindows || !_isPetModeActive) return;
    _isClickThroughActive = enable;
    await windowManager.setIgnoreMouseEvents(enable, forward: true);
  }

  /// Called after [summon] brings Pip forward; the app opens the mic.
  static VoidCallback? onSummon;

  /// Brings Pip to the front (from the tray, behind other windows, or pet
  /// mode) and asks the app to start listening.
  static Future<void> summon() async {
    try {
      if (_isPetModeActive) await exitAmbientPetMode();
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Summon failed: $e');
    }
    onSummon?.call();
  }

  static Future<void> togglePetMode() async {
    if (_isPetModeActive) {
      await exitAmbientPetMode();
    } else {
      await enterAmbientPetMode();
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_pip') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'talk') {
      await summon();
    } else if (menuItem.key == 'toggle_pet') {
      await togglePetMode();
    } else if (menuItem.key == 'toggle_dnd') {
      await PresenceSettings.instance.toggleQuiet();
    } else if (menuItem.key == 'quit') {
      await windowManager.destroy();
    }
  }
}
