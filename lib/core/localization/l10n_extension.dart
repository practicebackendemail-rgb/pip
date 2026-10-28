import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension L10nContext on BuildContext {
  /// User-facing strings for the current locale. Add new strings to
  /// `lib/core/localization/l10n/app_en.arb`, then run `flutter gen-l10n`.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
