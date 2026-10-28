import 'package:equatable/equatable.dart';

enum ActivityKind { alarm, reminder, task, calendar, email, note, briefing, memory, other }

/// How an action can be reversed: which kind of thing, and its id.
class ActivityUndo extends Equatable {
  final String type; // 'schedule' (alarm/reminder) | 'task'
  final String ref;

  const ActivityUndo(this.type, this.ref);

  Map<String, dynamic> toJson() => {'type': type, 'ref': ref};
  factory ActivityUndo.fromJson(Map<String, dynamic> j) => ActivityUndo(j['type'] as String, j['ref'] as String);

  @override
  List<Object?> get props => [type, ref];
}

/// One thing Pip actually did. Not a message: there is no "what you said /
/// what Pip said" here, only actions and their outcome.
class ActivityEntry extends Equatable {
  final String id;
  final ActivityKind kind;
  final String title;
  final String? detail;
  final DateTime at;
  final ActivityUndo? undo;
  final bool undone;

  const ActivityEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.detail,
    required this.at,
    this.undo,
    this.undone = false,
  });

  bool get canUndo => undo != null && !undone;

  ActivityEntry markUndone() =>
      ActivityEntry(id: id, kind: kind, title: title, detail: detail, at: at, undo: undo, undone: true);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'detail': detail,
        'at': at.toIso8601String(),
        'undo': undo?.toJson(),
        'undone': undone,
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
        id: j['id'] as String,
        kind: ActivityKind.values.asNameMap()[j['kind']] ?? ActivityKind.other,
        title: j['title'] as String,
        detail: j['detail'] as String?,
        at: DateTime.parse(j['at'] as String),
        undo: j['undo'] == null ? null : ActivityUndo.fromJson(j['undo'] as Map<String, dynamic>),
        undone: j['undone'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, kind, title, detail, at, undo, undone];
}
