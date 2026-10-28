import 'package:flutter/material.dart';
import '../domain/activity_entry.dart';

IconData activityIcon(ActivityKind kind) => switch (kind) {
      ActivityKind.alarm => Icons.alarm,
      ActivityKind.reminder => Icons.notifications_none,
      ActivityKind.task => Icons.task_alt,
      ActivityKind.calendar => Icons.event_outlined,
      ActivityKind.email => Icons.mail_outline,
      ActivityKind.note => Icons.sticky_note_2_outlined,
      ActivityKind.briefing => Icons.wb_sunny_outlined,
      ActivityKind.memory => Icons.psychology_outlined,
      ActivityKind.other => Icons.bolt,
    };
