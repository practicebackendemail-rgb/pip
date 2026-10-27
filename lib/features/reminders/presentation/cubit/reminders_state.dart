import 'package:equatable/equatable.dart';
import '../../domain/reminder_repository.dart';

class RemindersState extends Equatable {
  final bool isLoading;
  final List<ScheduledItem> items;
  final ReminderPermissions permissions;
  final String? error;

  const RemindersState({
    this.isLoading = true,
    this.items = const [],
    this.permissions = ReminderPermissions.granted,
    this.error,
  });

  List<ScheduledItem> get alarms => items.where((e) => e.isAlarm).toList();
  List<ScheduledItem> get reminders => items.where((e) => !e.isAlarm).toList();

  RemindersState copyWith({
    bool? isLoading,
    List<ScheduledItem>? items,
    ReminderPermissions? permissions,
    String? error,
    bool clearError = false,
  }) {
    return RemindersState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      permissions: permissions ?? this.permissions,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [isLoading, items, permissions, error];
}
