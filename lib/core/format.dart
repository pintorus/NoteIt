import 'package:flutter/material.dart';

/// « 14:05 » aujourd'hui, « 12 janv. » cette année, sinon « 12/01/2025 ».
String formatDate(BuildContext context, DateTime d) {
  final l = MaterialLocalizations.of(context);
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return l.formatTimeOfDay(TimeOfDay.fromDateTime(d),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
  }
  if (d.year == now.year) return l.formatShortMonthDay(d);
  return l.formatCompactDate(d);
}

String formatDateTime(BuildContext context, DateTime d) {
  final l = MaterialLocalizations.of(context);
  final time = l.formatTimeOfDay(TimeOfDay.fromDateTime(d),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
  return '${l.formatMediumDate(d)} $time';
}
