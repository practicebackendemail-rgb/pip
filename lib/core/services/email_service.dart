import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'email_provider_preset.dart';

/// Configuration for IMAP and SMTP email access.
/// Note: The password is NEVER serialized in toJson() to prevent credential leakage.
class EmailConfig {
  final String imapServer;
  final int imapPort;
  final String smtpServer;
  final int smtpPort;
  final bool isSecure;
  final String username;
  final String password;

  const EmailConfig({
    required this.imapServer,
    this.imapPort = 993,
    required this.smtpServer,
    this.smtpPort = 465,
    this.isSecure = true,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'imapServer': imapServer,
        'imapPort': imapPort,
        'smtpServer': smtpServer,
        'smtpPort': smtpPort,
        'isSecure': isSecure,
        'username': username,
      };

  factory EmailConfig.fromJson(Map<String, dynamic> json, {String password = ''}) =>
      EmailConfig(
        imapServer: json['imapServer'] as String? ?? 'imap.gmail.com',
        imapPort: json['imapPort'] as int? ?? 993,
        smtpServer: json['smtpServer'] as String? ?? 'smtp.gmail.com',
        smtpPort: json['smtpPort'] as int? ?? 465,
        isSecure: json['isSecure'] as bool? ?? true,
        username: json['username'] as String? ?? '',
        password: password,
      );
}

class EmailService extends ChangeNotifier {
  static const String _securePasswordKey = 'pip_mail_password';

  final FlutterSecureStorage _secureStorage;
  EmailConfig? _config;
  bool _isConnecting = false;
  String? _statusMessage;
  List<String> _recentHeaders = [];

  EmailConfig? get config => _config;
  bool get isConnecting => _isConnecting;
  String? get statusMessage => _statusMessage;
  List<String> get recentHeaders => List.unmodifiable(_recentHeaders);
  bool get isConfigured => _config != null && _config!.username.isNotEmpty && _config!.password.isNotEmpty;

  EmailService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey('mail_pass')) {
      final legacyPass = prefs.getString('mail_pass');
      if (legacyPass != null && legacyPass.isNotEmpty) {
        await _secureStorage.write(key: _securePasswordKey, value: legacyPass);
      }
      await prefs.remove('mail_pass');
    }

    final server = prefs.getString('mail_server');
    final port = prefs.getInt('mail_port') ?? 993;
    final smtpHost = prefs.getString('mail_smtp_server');
    final smtpP = prefs.getInt('mail_smtp_port');
    final user = prefs.getString('mail_user');
    final pass = await _secureStorage.read(key: _securePasswordKey);

    if (server != null && user != null && pass != null && pass.isNotEmpty) {
      final preset = EmailProviderPreset.findForEmail(user);
      _config = EmailConfig(
        imapServer: server,
        imapPort: port,
        smtpServer: smtpHost ?? preset?.smtpServer ?? server.replaceFirst('imap.', 'smtp.'),
        smtpPort: smtpP ?? preset?.smtpPort ?? 465,
        isSecure: usesImplicitTls(smtpP ?? preset?.smtpPort ?? 465),
        username: user,
        password: pass,
      );
      notifyListeners();
    }
  }

  Future<bool> saveAndTestConfig({
    required String server,
    required int port,
    required String user,
    required String pass,
    String? smtpServer,
    int? smtpPort,
    bool isSecure = true,
  }) async {
    _isConnecting = true;
    _statusMessage = "Testing connection to $server...";
    notifyListeners();

    try {
      final preset = EmailProviderPreset.findForEmail(user);
      final derivedSmtpServer = smtpServer ?? preset?.smtpServer ?? server.replaceFirst('imap.', 'smtp.');
      final derivedSmtpPort = smtpPort ?? preset?.smtpPort ?? 465;
      final derivedIsSecure = usesImplicitTls(derivedSmtpPort);

      final client = ImapClient(isLogEnabled: false);
      await client.connectToServer(server, port, isSecure: usesImplicitTls(port));
      if (!usesImplicitTls(port)) await client.startTls();
      await client.login(user, pass);
      await client.selectInbox();

      final fetchResult = await client.fetchRecentMessages(
        messageCount: 5,
        criteria: 'BODY.PEEK[HEADER.FIELDS (SUBJECT FROM DATE)]',
      );
      _recentHeaders = fetchResult.messages.map((m) {
        final subject = m.decodeSubject() ?? 'No Subject';
        final from = m.fromEmail ?? 'Unknown Sender';
        return "From: $from | Subject: $subject";
      }).toList();

      await client.logout();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mail_server', server);
      await prefs.setInt('mail_port', port);
      await prefs.setString('mail_smtp_server', derivedSmtpServer);
      await prefs.setInt('mail_smtp_port', derivedSmtpPort);
      await prefs.setString('mail_user', user);

      await _secureStorage.write(key: _securePasswordKey, value: pass);
      if (prefs.containsKey('mail_pass')) await prefs.remove('mail_pass');

      _config = EmailConfig(
        imapServer: server,
        imapPort: port,
        smtpServer: derivedSmtpServer,
        smtpPort: derivedSmtpPort,
        isSecure: derivedIsSecure,
        username: user,
        password: pass,
      );
      _statusMessage = "Connected successfully! ${_recentHeaders.length} recent emails fetched.";
      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _statusMessage = "Connection failed: $e";
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  /// Transmits real RFC 822 email message using SMTP client
  Future<Map<String, dynamic>> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    if (!isConfigured || _config == null) {
      return {'error': 'Mail service is not configured. Setup credentials first.'};
    }

    final toAddress = to.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(toAddress)) {
      return {'error': 'Invalid recipient email address format: $toAddress'};
    }

    final client = SmtpClient('pip.desktop.client', isLogEnabled: false);
    try {
      final implicitTls = usesImplicitTls(_config!.smtpPort);
      await client.connectToServer(
        _config!.smtpServer,
        _config!.smtpPort,
        isSecure: implicitTls,
      );
      await client.ehlo();

      if (!implicitTls) {
        // Never send credentials over a plain connection.
        if (!client.serverInfo.supportsStartTls) {
          await client.quit();
          return {'error': 'Your mail server does not offer encryption (STARTTLS), so Pip will not send.'};
        }
        await client.startTls();
        await client.ehlo();
      }

      final authMechanism = client.serverInfo.supportsAuth(AuthMechanism.plain)
          ? AuthMechanism.plain
          : AuthMechanism.login;
      await client.authenticate(_config!.username, _config!.password, authMechanism);

      final builder = MessageBuilder()
        ..from = [MailAddress(null, _config!.username)]
        ..to = [MailAddress(null, toAddress)]
        ..subject = subject
        ..text = body;

      final message = builder.buildMimeMessage();
      final response = await client.sendMessage(message);

      await client.quit();

      if (response.isOkStatus) {
        return {
          'status': 'sent',
          'recipient': toAddress,
          'subject': subject,
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        return {'error': 'SMTP rejected message: ${response.errorMessage}'};
      }
    } catch (e) {
      return {'error': 'SMTP delivery failed: $e'};
    }
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mail_server');
    await prefs.remove('mail_port');
    await prefs.remove('mail_smtp_server');
    await prefs.remove('mail_smtp_port');
    await prefs.remove('mail_user');
    await prefs.remove('mail_pass');
    await _secureStorage.delete(key: _securePasswordKey);
    _config = null;
    _recentHeaders = [];
    _statusMessage = null;
    notifyListeners();
  }

  Future<List<String>> fetchUnreadSummaries() async {
    if (_config == null) return [];
    try {
      final client = ImapClient(isLogEnabled: false);
      await client.connectToServer(
        _config!.imapServer,
        _config!.imapPort,
        isSecure: usesImplicitTls(_config!.imapPort),
      );
      if (!usesImplicitTls(_config!.imapPort)) await client.startTls();
      await client.login(_config!.username, _config!.password);
      await client.selectInbox();

      final fetchResult = await client.fetchRecentMessages(
        messageCount: 7,
        criteria: 'BODY.PEEK[HEADER.FIELDS (SUBJECT FROM DATE)]',
      );
      _recentHeaders = fetchResult.messages.map((m) {
        final subject = m.decodeSubject() ?? 'No Subject';
        final from = m.fromEmail ?? 'Unknown Sender';
        return "From: $from | Subject: $subject";
      }).toList();

      await client.logout();
      notifyListeners();
      return _recentHeaders;
    } catch (e) {
      debugPrint("Error fetching emails: $e");
      return [];
    }
  }
}
