import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for IMAP email access.
/// Note: The password is NEVER serialized in toJson() to prevent credential leakage.
class EmailConfig {
  final String imapServer;
  final int imapPort;
  final bool isSecure;
  final String username;
  final String password;

  const EmailConfig({
    required this.imapServer,
    this.imapPort = 993,
    this.isSecure = true,
    required this.username,
    required this.password,
  });

  /// Serializes non-sensitive fields only.
  Map<String, dynamic> toJson() => {
        'imapServer': imapServer,
        'imapPort': imapPort,
        'isSecure': isSecure,
        'username': username,
      };

  factory EmailConfig.fromJson(Map<String, dynamic> json, {String password = ''}) =>
      EmailConfig(
        imapServer: json['imapServer'] as String,
        imapPort: json['imapPort'] as int? ?? 993,
        isSecure: json['isSecure'] as bool? ?? true,
        username: json['username'] as String,
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

  /// Loads configuration and executes a one-time migration if plain-text password exists in SharedPreferences.
  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();

    // One-time migration: check if unencrypted SharedPreferences has mail_pass
    if (prefs.containsKey('mail_pass')) {
      final legacyPass = prefs.getString('mail_pass');
      if (legacyPass != null && legacyPass.isNotEmpty) {
        await _secureStorage.write(key: _securePasswordKey, value: legacyPass);
      }
      await prefs.remove('mail_pass');
    }

    final server = prefs.getString('mail_server');
    final port = prefs.getInt('mail_port') ?? 993;
    final user = prefs.getString('mail_user');
    final pass = await _secureStorage.read(key: _securePasswordKey);

    if (server != null && user != null && pass != null && pass.isNotEmpty) {
      _config = EmailConfig(
        imapServer: server,
        imapPort: port,
        username: user,
        password: pass,
      );
      notifyListeners();
    }
  }

  /// Connects, validates IMAP credentials, and persists securely on success.
  Future<bool> saveAndTestConfig({
    required String server,
    required int port,
    required String user,
    required String pass,
    bool isSecure = true,
  }) async {
    _isConnecting = true;
    _statusMessage = "Testing connection to $server...";
    notifyListeners();

    try {
      final client = ImapClient(isLogEnabled: false);
      await client.connectToServer(server, port, isSecure: isSecure);
      await client.login(user, pass);
      await client.selectInbox();

      // Fetch top 5 unread/recent message headers
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

      // Persist configuration: non-sensitive metadata in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mail_server', server);
      await prefs.setInt('mail_port', port);
      await prefs.setString('mail_user', user);

      // Persist sensitive credential strictly in hardware-backed FlutterSecureStorage
      await _secureStorage.write(key: _securePasswordKey, value: pass);

      // Clean up legacy key if lingering
      if (prefs.containsKey('mail_pass')) {
        await prefs.remove('mail_pass');
      }

      _config = EmailConfig(
        imapServer: server,
        imapPort: port,
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

  /// Clears credentials completely from both secure storage and SharedPreferences.
  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mail_server');
    await prefs.remove('mail_port');
    await prefs.remove('mail_user');
    await prefs.remove('mail_pass');
    await _secureStorage.delete(key: _securePasswordKey);
    _config = null;
    _recentHeaders = [];
    _statusMessage = null;
    notifyListeners();
  }

  /// Fetches unread message headers.
  Future<List<String>> fetchUnreadSummaries() async {
    if (_config == null) return [];
    try {
      final client = ImapClient(isLogEnabled: false);
      await client.connectToServer(
        _config!.imapServer,
        _config!.imapPort,
        isSecure: _config!.isSecure,
      );
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
