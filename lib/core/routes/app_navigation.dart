import 'package:go_router/go_router.dart';

/// Lets non-widget code (tools) open a screen. Set once in main.
abstract final class AppNavigation {
  static GoRouter? router;

  static bool push(String location) {
    final r = router;
    if (r == null) return false;
    r.push(location);
    return true;
  }
}
