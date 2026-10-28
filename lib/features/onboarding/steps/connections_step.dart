import 'dart:io';
import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/email_service.dart';
import '../../../core/services/pip_audio_coordinator.dart';
import '../../../core/services/pip_desktop_window_manager.dart';
import '../../../core/services/pip_overlay_manager.dart';
import '../../../core/services/tools/calendar_tools.dart';
import '../../../core/services/tools/reminder_tool.dart';
import '../../../core/theme/pip_theme.dart';
import '../../notifications/data/notification_inbox.dart';
import '../../../widgets/pip_params.dart';
import '../email_setup_sheet.dart';
import '../onboarding_flow.dart';

enum ConnectionStatus { off, on, unavailable }

/// Optional connections. Each row asks for its permission only when tapped,
/// and rows a platform cannot support say so instead of failing later.
class ConnectionsStep extends StatefulWidget {
  final ValueChanged<PipStepState> onState;

  const ConnectionsStep({super.key, required this.onState});

  @override
  State<ConnectionsStep> createState() => _ConnectionsPipStepState();
}

class _ConnectionsPipStepState extends State<ConnectionsStep> {
  static bool get _android => !kIsWeb && Platform.isAndroid;
  static bool get _windows => !kIsWeb && Platform.isWindows;
  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  final _calendar = DeviceCalendarService();
  ConnectionStatus _calendarStatus = ConnectionStatus.off;
  ConnectionStatus _remindersStatus = ConnectionStatus.off;
  ConnectionStatus _voiceStatus = ConnectionStatus.off;
  ConnectionStatus _floatingStatus = ConnectionStatus.off;
  ConnectionStatus _notificationsStatus = ConnectionStatus.off;

  /// Notification access is granted in Android settings, outside the app:
  /// re-check when the user comes back.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _refresh);

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!_mobile) {
      _calendarStatus = ConnectionStatus.unavailable;
    } else {
      final p = await _calendar.checkPermission();
      _calendarStatus = _granted(p) ? ConnectionStatus.on : ConnectionStatus.off;
    }
    if (!_android && !_windows) _floatingStatus = ConnectionStatus.unavailable;
    if (_android && await PipOverlayManager.isPermissionGranted()) _floatingStatus = ConnectionStatus.on;
    if (_windows && await PipDesktopWindowManager.isLaunchAtStartupEnabled()) _floatingStatus = ConnectionStatus.on;
    if (getIt<PipAudioCoordinator>().isInitialized) _voiceStatus = ConnectionStatus.on;
    _notificationsStatus = !NotificationInbox.supported
        ? ConnectionStatus.unavailable
        : (await NotificationInbox.instance.isEnabled() ? ConnectionStatus.on : ConnectionStatus.off);
    if (mounted) setState(() {});
  }

  bool _granted(CalendarPermissionStatus p) =>
      p == CalendarPermissionStatus.granted || p == CalendarPermissionStatus.writeOnly;

  void _say(String message, {PipMood mood = PipMood.happy}) => widget.onState(PipStepState(message, mood: mood));

  Future<void> _connectEmail() async {
    final ok = await EmailSetupSheet.show(context);
    if (!mounted) return;
    setState(() {});
    if (ok == true) _say("Inbox connected! I'll only send mail after you confirm.", mood: PipMood.excited);
  }

  Future<void> _connectCalendar() async {
    final p = await _calendar.requestPermission();
    setState(() => _calendarStatus = _granted(p) ? ConnectionStatus.on : ConnectionStatus.off);
    _granted(p) ? _say('I can see your calendar now.') : _say('No calendar for now. That is fine.', mood: PipMood.idle);
  }

  Future<void> _connectReminders() async {
    await ReminderTool.ensureInitialized();
    setState(() => _remindersStatus = ConnectionStatus.on);
    _say("I'll nudge you even when the app is closed.");
  }

  Future<void> _connectVoice() async {
    final audio = getIt<PipAudioCoordinator>();
    await audio.init();
    setState(() => _voiceStatus = audio.isInitialized ? ConnectionStatus.on : ConnectionStatus.off);
    audio.isInitialized
        ? _say('I can hear you now. Hold the mic button to talk.', mood: PipMood.listening)
        : _say("I couldn't get the microphone. You can allow it later.", mood: PipMood.unsure);
  }

  Future<void> _connectFloating() async {
    if (_android) {
      final ok = await PipOverlayManager.requestPermission() ?? false;
      setState(() => _floatingStatus = ok ? ConnectionStatus.on : ConnectionStatus.off);
    } else if (_windows) {
      final enable = _floatingStatus != ConnectionStatus.on;
      await PipDesktopWindowManager.setLaunchAtStartup(enable);
      setState(() => _floatingStatus = enable ? ConnectionStatus.on : ConnectionStatus.off);
    }
    if (_floatingStatus == ConnectionStatus.on) _say("I'll keep you company on the desktop.", mood: PipMood.excited);
  }

  @override
  Widget build(BuildContext context) {
    final email = getIt<EmailService>();
    return ListView(
      padding: const EdgeInsets.all(PipSpace.xl),
      children: [
        ListenableBuilder(
          listenable: email,
          builder: (context, _) => ConnectionRow(
            icon: Icons.mail_outline,
            title: 'Email',
            detail: email.isConfigured ? email.config!.username : 'Read your inbox and send mail you approve',
            status: email.isConfigured ? ConnectionStatus.on : ConnectionStatus.off,
            action: email.isConfigured ? 'Change' : 'Connect',
            onTap: _connectEmail,
          ),
        ),
        ConnectionRow(
          icon: Icons.calendar_month_outlined,
          title: 'Calendar',
          detail: _mobile ? 'See and add events' : 'Not on this platform yet',
          status: _calendarStatus,
          action: 'Allow',
          onTap: _connectCalendar,
        ),
        ConnectionRow(
          icon: Icons.notifications_none,
          title: 'Reminders',
          detail: _windows ? 'Works while Pip is running' : 'Notifications, even when closed',
          status: _remindersStatus,
          action: 'Allow',
          onTap: _connectReminders,
        ),
        ConnectionRow(
          icon: Icons.mic_none,
          title: 'Voice',
          detail: 'Talk to Pip with the mic button',
          status: _voiceStatus,
          action: 'Allow',
          onTap: _connectVoice,
        ),
        ConnectionRow(
          icon: _windows ? Icons.desktop_windows_outlined : Icons.picture_in_picture_alt_outlined,
          title: _windows ? 'Start with Windows' : 'Floating Pip',
          detail: _windows ? 'Pip sits on your desktop after you sign in' : 'Pip stays visible over other apps',
          status: _floatingStatus,
          action: _windows && _floatingStatus == ConnectionStatus.on ? 'Turn off' : 'Set up',
          onTap: _connectFloating,
        ),
        ConnectionRow(
          icon: Icons.notifications_active_outlined,
          title: 'Notifications',
          detail: _android ? 'Lets Pip tell you what you missed' : 'Android only for now',
          status: _notificationsStatus,
          action: _notificationsStatus == ConnectionStatus.on ? 'Change' : 'Allow',
          onTap: NotificationInbox.instance.openSettings,
        ),
      ],
    );
  }
}

class ConnectionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final ConnectionStatus status;
  final String action;
  final VoidCallback onTap;

  const ConnectionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unavailable = status == ConnectionStatus.unavailable;
    final on = status == ConnectionStatus.on;
    return Padding(
      padding: const EdgeInsets.only(bottom: PipSpace.sm),
      child: Opacity(
        opacity: unavailable ? .55 : 1,
        child: Material(
          color: PipColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PipSpace.radius),
            side: BorderSide(color: on ? PipColors.ok.withValues(alpha: .5) : PipColors.border),
          ),
          child: ListTile(
            onTap: unavailable ? null : onTap,
            leading: Icon(icon, color: PipColors.amber),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            trailing: unavailable
                ? null
                : on
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: PipColors.ok, size: 18),
                          if (action == 'Change' || action == 'Turn off') ...[
                            const SizedBox(width: 6),
                            Text(action, style: const TextStyle(color: PipColors.muted, fontSize: 12)),
                          ],
                        ],
                      )
                    : Text(action, style: const TextStyle(color: PipColors.amber, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
