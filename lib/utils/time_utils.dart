import 'package:flutter/material.dart';

class TimeUtils {
  static TimeOfDay? parseStoredTime(String? value) {
    if (value == null || value.isEmpty) return null;

    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  static TimeOfDay parseStoredTimeOrDefault(
    String? value,
    TimeOfDay fallback,
  ) {
    return parseStoredTime(value) ?? fallback;
  }

  static String formatStoredTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatStoredTimeForDisplay(
    BuildContext context,
    String? value, {
    TimeOfDay? fallback,
    String? emptyLabel,
  }) {
    final parsed = parseStoredTime(value) ?? fallback;
    if (parsed == null) return emptyLabel ?? '';
    return formatTimeOfDay(context, parsed);
  }

  static String formatTimeOfDay(BuildContext context, TimeOfDay time) {
    final alwaysUse24HourFormat =
        MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false;

    return MaterialLocalizations.of(context).formatTimeOfDay(
      time,
      alwaysUse24HourFormat: alwaysUse24HourFormat,
    );
  }

  static String formatDateTimeTime(BuildContext context, DateTime dateTime) {
    return formatTimeOfDay(context, TimeOfDay.fromDateTime(dateTime));
  }
}
