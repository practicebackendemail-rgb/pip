import '../../../core/services/pip_notification_service.dart';
import '../../../core/services/tools/schedule_store.dart';
import '../domain/reminder_repository.dart';

/// The real repository: Pip's schedule store plus system notifications.
class ScheduledReminderRepository implements ReminderRepository {
  const ScheduledReminderRepository();

  @override
  Stream<void> get changes => ScheduleStore.changes;

  @override
  Future<List<ScheduledItem>> upcoming() => ScheduleStore.upcoming();

  @override
  Future<void> save(ScheduledItem item) async {
    await PipNotificationService.schedule(item);
    await ScheduleStore.upsert(item);
  }

  @override
  Future<void> delete(ScheduledItem item) async {
    await PipNotificationService.cancel(item);
    await ScheduleStore.remove(item.id);
  }

  @override
  Future<ReminderPermissions> permissions() => PipNotificationService.permissions();

  @override
  Future<ReminderPermissions> requestPermissions() => PipNotificationService.requestPermissions();
}
