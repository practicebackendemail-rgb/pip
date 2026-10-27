import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/reminder_repository.dart';
import 'reminders_state.dart';

/// The Alarms & reminders screen. Reloads whenever the list changes, so
/// items Pip adds by voice or chat appear without a refresh.
class RemindersCubit extends Cubit<RemindersState> {
  final ReminderRepository _repository;
  StreamSubscription<void>? _changes;

  RemindersCubit(this._repository) : super(const RemindersState()) {
    _changes = _repository.changes.listen((_) => load());
  }

  Future<void> load() async {
    try {
      final items = await _repository.upcoming();
      final permissions = await _repository.permissions();
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, items: items, permissions: permissions, clearError: true));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(isLoading: false, error: "Couldn't load alarms and reminders."));
    }
  }

  Future<void> save(ScheduledItem item) => _run(() => _repository.save(item), "Couldn't save that.");

  Future<void> setEnabled(ScheduledItem item, bool enabled) =>
      _run(() => _repository.save(item.copyWith(enabled: enabled)), "Couldn't update that.");

  /// Removes the item from the list at once (a swiped tile must leave the
  /// tree immediately), then deletes it for real.
  Future<void> delete(ScheduledItem item) {
    emit(state.copyWith(items: state.items.where((e) => e.id != item.id).toList()));
    return _run(() => _repository.delete(item), "Couldn't delete that.");
  }

  Future<void> requestPermissions() async {
    final permissions = await _repository.requestPermissions();
    if (!isClosed) emit(state.copyWith(permissions: permissions));
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    try {
      await action();
      await load();
    } catch (e) {
      if (!isClosed) emit(state.copyWith(error: failure));
    }
  }

  @override
  Future<void> close() {
    _changes?.cancel();
    return super.close();
  }
}
