import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/tools/schedule_store.dart';

/// The form behind the add/edit sheet.
class ReminderDraft extends Equatable {
  final int? id;
  final String kind;
  final String title;
  final int hour;
  final int minute;

  /// The day a one-off fires. Ignored when [days] is set.
  final DateTime date;
  final List<int> days;
  final bool enabled;

  const ReminderDraft({
    this.id,
    required this.kind,
    required this.title,
    required this.hour,
    required this.minute,
    required this.date,
    this.days = const [],
    this.enabled = true,
  });

  bool get isAlarm => kind == ScheduledItem.alarm;
  bool get isNew => id == null;

  DateTime get at => DateTime(date.year, date.month, date.day, hour, minute);

  /// A one-off must be in the future; a repeating one needs at least one day.
  bool isValid({DateTime? now}) => days.isNotEmpty || at.isAfter(now ?? DateTime.now());

  ScheduledItem toItem() => ScheduledItem(
        id: id ?? newScheduleId(),
        kind: kind,
        title: title.trim().isEmpty ? (isAlarm ? 'Alarm' : 'Reminder') : title.trim(),
        at: at,
        days: [...days]..sort(),
        enabled: enabled,
      );

  ReminderDraft copyWith({String? kind, String? title, int? hour, int? minute, DateTime? date, List<int>? days}) =>
      ReminderDraft(
        id: id,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        date: date ?? this.date,
        days: days ?? this.days,
        enabled: enabled,
      );

  @override
  List<Object?> get props => [id, kind, title, hour, minute, date, days, enabled];
}

class ReminderEditorCubit extends Cubit<ReminderDraft> {
  ReminderEditorCubit(super.initial);

  /// A new alarm or reminder an hour from now, rounded to the next 5 minutes.
  factory ReminderEditorCubit.create({required String kind, DateTime? now}) {
    final t = (now ?? DateTime.now()).add(const Duration(hours: 1));
    final rounded = DateTime(t.year, t.month, t.day, t.hour, (t.minute / 5).ceil() * 5);
    return ReminderEditorCubit(ReminderDraft(
      kind: kind,
      title: '',
      hour: rounded.hour,
      minute: rounded.minute,
      date: DateTime(rounded.year, rounded.month, rounded.day),
    ));
  }

  factory ReminderEditorCubit.edit(ScheduledItem item) {
    final next = item.nextOccurrence() ?? item.at;
    return ReminderEditorCubit(ReminderDraft(
      id: item.id,
      kind: item.kind,
      title: item.title,
      hour: item.at.hour,
      minute: item.at.minute,
      date: DateTime(next.year, next.month, next.day),
      days: item.days,
      enabled: item.enabled,
    ));
  }

  void setKind(String kind) => emit(state.copyWith(kind: kind));

  void setTitle(String title) => emit(state.copyWith(title: title));

  /// A time already past on the chosen day moves a one-off to tomorrow.
  void setTime(int hour, int minute, {DateTime? now}) {
    var draft = state.copyWith(hour: hour, minute: minute);
    if (draft.days.isEmpty && !draft.at.isAfter(now ?? DateTime.now())) {
      final next = nextClockTime(hour, minute, now: now);
      draft = draft.copyWith(date: DateTime(next.year, next.month, next.day));
    }
    emit(draft);
  }

  void setDate(DateTime date) => emit(state.copyWith(date: DateTime(date.year, date.month, date.day)));

  void toggleDay(int day) {
    final days = state.days.contains(day) ? state.days.where((d) => d != day).toList() : [...state.days, day];
    emit(state.copyWith(days: days));
  }
}
