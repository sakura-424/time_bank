import 'dart:convert';

class HistoryItem
{
  final DateTime date;
  final int durationSeconds;
  final String memo;

  HistoryItem({required this.date, required this.durationSeconds, required this.memo});

  Map<String, dynamic> toJson() =>
  {
    'date': date.toIso8601String(),
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
