import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/services/pip_desktop_window_manager.dart';
import '../../core/theme/apple_theme.dart';
import 'pip_sync_panel.dart';

/// Settings section: sync and backups, plus launch-at-startup on Windows.
class PipDeviceSettingsSection extends StatefulWidget {
  const PipDeviceSettingsSection({super.key});

  @override
  State<PipDeviceSettingsSection> createState() => _PipDeviceSettingsSectionState();
}

class _PipDeviceSettingsSectionState extends State<PipDeviceSettingsSection> {
  bool? _launchAtStartup;

  bool get _isWindows => !kIsWeb && Platform.isWindows;

  @override
  void initState() {
    super.initState();
    if (_isWindows) {
      PipDesktopWindowManager.isLaunchAtStartupEnabled().then((v) {
        if (mounted) setState(() => _launchAtStartup = v);
      });
    }
  }

  Future<void> _toggleStartup(bool value) async {
    setState(() => _launchAtStartup = value);
    await PipDesktopWindowManager.setLaunchAtStartup(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(CupertinoIcons.cloud, color: AppleTheme.accentTeal, size: 18),
            SizedBox(width: 8),
            Text(
              'SYNC & BACKUP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppleTheme.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const PipSyncPanel(),
        if (_isWindows && _launchAtStartup != null) ...[
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Launch Pip when Windows starts',
                style: TextStyle(fontSize: 14, color: AppleTheme.textPrimary)),
            value: _launchAtStartup!,
            onChanged: _toggleStartup,
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}
