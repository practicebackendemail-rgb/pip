import 'package:flutter/foundation.dart';

/// Which screen the user is looking at, so short commands are understood in
/// context: "move it to 7" means a task on Tasks and an alarm on Alarms.
/// The app shell sets this when the visible tab or screen changes.
class PipScreenContext {
  PipScreenContext._();

  /// A short description for Pip, e.g. "the Tasks screen". Null on home.
  static final ValueNotifier<String?> current = ValueNotifier(null);

  /// [query] with the screen prefixed, the form the chat engine expects.
  static String withContext(String query) {
    final where = current.value;
    return where == null ? query : '(The user is on $where.) $query';
  }
}
