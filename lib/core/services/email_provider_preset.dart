/// Provider preset configuration for IMAP and SMTP settings
class EmailProviderPreset {
  final String domain;
  final String imapServer;
  final int imapPort;
  final String smtpServer;
  final int smtpPort;
  final bool isSecure;

  const EmailProviderPreset({
    required this.domain,
    required this.imapServer,
    this.imapPort = 993,
    required this.smtpServer,
    this.smtpPort = 465,
    this.isSecure = true,
  });

  static const List<EmailProviderPreset> presets = [
    EmailProviderPreset(
      domain: 'gmail.com',
      imapServer: 'imap.gmail.com',
      imapPort: 993,
      smtpServer: 'smtp.gmail.com',
      smtpPort: 465,
      isSecure: true,
    ),
    EmailProviderPreset(
      domain: 'outlook.com',
      imapServer: 'outlook.office365.com',
      imapPort: 993,
      smtpServer: 'smtp-mail.outlook.com',
      smtpPort: 587,
      isSecure: false,
    ),
    EmailProviderPreset(
      domain: 'hotmail.com',
      imapServer: 'outlook.office365.com',
      imapPort: 993,
      smtpServer: 'smtp-mail.outlook.com',
      smtpPort: 587,
      isSecure: false,
    ),
    EmailProviderPreset(
      domain: 'yahoo.com',
      imapServer: 'imap.mail.yahoo.com',
      imapPort: 993,
      smtpServer: 'smtp.mail.yahoo.com',
      smtpPort: 465,
      isSecure: true,
    ),
    EmailProviderPreset(
      domain: 'icloud.com',
      imapServer: 'imap.mail.me.com',
      imapPort: 993,
      smtpServer: 'smtp.mail.me.com',
      smtpPort: 587,
      isSecure: false,
    ),
  ];

  static EmailProviderPreset? findForEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return null;
    final domain = parts[1].toLowerCase().trim();
    for (final preset in presets) {
      if (preset.domain == domain) return preset;
    }
    return null;
  }
}
