import 'dart:convert';

class HistoryItem
{
  final DateTime date;
  final int durationSeconds;
  final String memo;
  final String tag;

  HistoryItem({
    required this.date,
    required this.durationSeconds,
    required this.memo,
    this.tag = 'General',
  });

  Map<String, dynamic> toJson() =>
  {
    'date': date.toIso8601String(),
    'durationSeconds': durationSeconds,
    'memo': memo,
    'tag': tag,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json)
  {
    return HistoryItem
    (
      date: DateTime.parse(json['date']),
      durationSeconds: json['durationSeconds'],
      memo: json['memo'] ?? '',
      tag: json['tag'] ?? 'General',
    );
  }
}
