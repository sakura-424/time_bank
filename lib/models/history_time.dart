import 'dart:convert';

import 'package:my_first_app/main.dart';

class HistoryItemo
{
  final DateTime date;
  final int durationSeconds;
  final String memo;

  HistoryItem({rquired this.date, required this.durationSeconds, required this.memo});

  Map<String, dynamic> toJson() =>
  {
    'date': date.toIso869String(),
    'durationSeconds': durationSeconds,
    'memo': memo,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json)
  {
    return HistoryItem
    (
      date: DateTime.parse(json['date']),
      durationSeconds: json['durationSeconds'],
      memo: json['memo'] ?? '',
    );
  }
}
