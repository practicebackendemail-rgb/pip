/// Provider preset configuration for IMAP and SMTP settings
class EmailProviderPreset {
  final String id;
  final String label;
  final List<String> domains;
  final String imapServer;
  final int imapPort;
  final String smtpServer;
  final int smtpPort;

  /// Where the user creates the app password most of these providers require.
  final String? appPasswordHelp;

  const EmailProviderPreset({
    required this.id,
    required this.label,
    required this.domains,
    required this.imapServer,
    this.imapPort = 993,
    required this.smtpServer,
    this.smtpPort = 465,
    this.appPasswordHelp,
  });

  /// Kept for older callers: the first domain this preset matches.
  String get domain => domains.first;

  static const List<EmailProviderPreset> presets = [
    EmailProviderPreset(
      id: 'gmail',
      label: 'Gmail',
      domains: ['gmail.com', 'googlemail.com'],
      imapServer: 'imap.gmail.com',
      smtpServer: 'smtp.gmail.com',
      smtpPort: 465,
      appPasswordHelp: 'Google Account → Security → App passwords',
    ),
    EmailProviderPreset(
      id: 'outlook',
      label: 'Outlook',
      domains: ['outlook.com', 'hotmail.com', 'live.com', 'msn.com'],
      imapServer: 'outlook.office365.com',
      smtpServer: 'smtp-mail.outlook.com',
      smtpPort: 587,
      appPasswordHelp: 'Microsoft account → Security → App passwords',
    ),
    EmailProviderPreset(
      id: 'yahoo',
      label: 'Yahoo',
      domains: ['yahoo.com', 'ymail.com'],
      imapServer: 'imap.mail.yahoo.com',
      smtpServer: 'smtp.mail.yahoo.com',
      smtpPort: 465,
      appPasswordHelp: 'Yahoo Account security → Generate app password',
    ),
    EmailProviderPreset(
      id: 'icloud',
      label: 'iCloud',
      domains: ['icloud.com', 'me.com', 'mac.com'],
      imapServer: 'imap.mail.me.com',
      smtpServer: 'smtp.mail.me.com',
      smtpPort: 587,
      appPasswordHelp: 'appleid.apple.com → Sign-In and Security → App-specific passwords',
    ),
  ];

  static EmailProviderPreset? findForEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return null;
    final domain = parts[1].toLowerCase().trim();
    for (final preset in presets) {
      if (preset.domains.contains(domain)) return preset;
    }
    return null;
  }

  static EmailProviderPreset? byId(String id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}

/// TLS mode follows the port: 993 (IMAP) and 465 (SMTP) use implicit TLS,
/// other ports (143, 587, 25) start plain and must upgrade with STARTTLS.
bool usesImplicitTls(int port) => port == 993 || port == 465;
