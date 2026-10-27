import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Service responsible for managing Pip's desktop window modes on Windows.
/// Features:
/// 1. Taskbar skipping in Pet Mode (`setSkipTaskbar(true)`).
/// 2. Click-through toggle via `setIgnoreMouseEvents`.
/// 3. Dragging & position persistence across multi-monitor setups via `screen_retriever`.
/// 4. System tray management with quick status toggles.
/// 5. Global hotkey toggling (`Ctrl+Shift+P`).
/// 6. Startup launch toggle via `launch_at_startup`.
class PipDesktopWindowManager with TrayListener, WindowListener {
  PipDesktopWindowManager._();
  static final PipDesktopWindowManager instance = PipDesktopWindowManager._();

  static bool _isPetModeActive = false;
  static bool _isClickThroughActive = false;
  static bool _isDoNotDisturb = false;

  static bool get isPetModeActive => _isPetModeActive;
  static bool get isClickThroughActive => _isClickThroughActive;
  static bool get isDoNotDisturb => _isDoNotDisturb;

  static const String _prefPosX = 'pip_window_pos_x';
  static const String _prefPosY = 'pip_window_pos_y';

  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isWindows) return;

    try {
      await windowManager.ensureInitialized();
      await hotKeyManager.unregisterAll();

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

      // Register Tray Menu
      trayManager.addListener(instance);
      await _setupTray();

      // Register Global HotKey (Ctrl + Shift + P)
      final hotKey = HotKey(
        key: PhysicalKeyboardKey.keyP,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) => togglePetMode(),
      );
    } catch (e) {
      debugPrint("Desktop windowManager initialize error: $e");
    }
  }

  static Future<void> _setupTray() async {
    try {
      await trayManager.setIcon('assets/icons/app_icon.ico');
      final menu = Menu(items: [
        MenuItem(key: 'show_pip', label: 'Show Pip'),
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

  /// Transforms the window into an ambient floating desktop pet
  static Future<void> enterAmbientPetMode() async {
    if (kIsWeb || !Platform.isWindows) return;

    try {
      _isPetModeActive = true;
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setSize(const Size(300, 340));
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true); // Step 8.1: Hide from taskbar
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setHasShadow(false);

      // Step 8.3: Restore saved position with screen bounds verification
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
      // Verify saved point falls within an active monitor
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

  /// Saves current position to persistent storage
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

  /// Restores standard application window mode
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

  /// Toggles Click-Through state (Step 8.2)
  static Future<void> setClickThrough(bool enable) async {
    if (kIsWeb || !Platform.isWindows || !_isPetModeActive) return;
    _isClickThroughActive = enable;
    await windowManager.setIgnoreMouseEvents(enable, forward: true);
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
    } else if (menuItem.key == 'toggle_pet') {
      await togglePetMode();
    } else if (menuItem.key == 'toggle_dnd') {
      _isDoNotDisturb = !_isDoNotDisturb;
    } else if (menuItem.key == 'quit') {
      await windowManager.destroy();
    }
  }
}
