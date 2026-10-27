import '../../../core/services/pip_notification_service.dart' show ReminderPermissions;
import '../../../core/services/tools/schedule_store.dart' show ScheduledItem;

export '../../../core/services/pip_notification_service.dart' show ReminderPermissions;
export '../../../core/services/tools/schedule_store.dart' show ScheduledItem;

/// Alarms and reminders, whether made by hand or by Pip.
abstract class ReminderRepository {
  /// Fires whenever the list changes, including when Pip's tools change it.
  Stream<void> get changes;

  Future<List<ScheduledItem>> upcoming();

  /// Adds or replaces [item] and (re)schedules its notifications.
  Future<void> save(ScheduledItem item);

  Future<void> delete(ScheduledItem item);

  Future<ReminderPermissions> permissions();

  Future<ReminderPermissions> requestPermissions();
}
