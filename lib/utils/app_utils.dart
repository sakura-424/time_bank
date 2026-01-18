import 'package:flutter/material.dart';
import 'package:time_bank/models/history_time.dart';

class AppUtils {
  static Color getTagColor(String tag) {
    final List<Color> palette = [
      Colors.blue, Colors.red, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
      Colors.brown, Colors.cyan,
    ];
    return palette[tag.hashCode.abs() % palette.length];
  }

  static String formatMinutes(int minutes) {
    if (minutes == 0) return "0m";
    int h = minutes ~/ 60;
    int m = minutes % 60;
    if (h > 0){
      return "${h}h ${m.toString().padLeft(2, '0')}m";
    } else {
      return "${m}m";
    }
  }

  static String formatHistoryDuration(int seconds) {
    Duration d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
    }
    return "${d.inMinutes}m ${d.inSeconds.remainder(60)}s";
  }

    // 秒まで含めたフォーマット
  static String formatExactTime(int totalSeconds) {
    Duration d = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${d.inHours}h ${twoDigits(d.inMinutes.remainder(60))}m ${twoDigits(d.inSeconds.remainder(60))}s";
  }

    // 指定した日付(date)の合計秒数を履歴リストから計算
  static int getExactDailySeconds(DateTime date, List<HistoryItem> historyList) {
    return historyList
        .where((item) =>
            item.date.year == date.year &&
            item.date.month == date.month &&
            item.date.day == date.day)
        .fold(0, (sum, item) => sum + item.durationSeconds);
  }

    // その週の合計秒数を履歴から正確に計算する
  static int getExactWeeklySeconds(DateTime date, List<HistoryItem> historyList) {
    // 週の始まり（日曜日）を計算
    int difference = date.weekday == 7 ? 0 : date.weekday;
    DateTime startOfWeek = DateTime(date.year, date.month, date.day).subtract(Duration(days: difference));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 7)); // 次の日曜日0:00

    return historyList
        .where((item) =>
            item.date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
            item.date.isBefore(endOfWeek))
        .fold(0, (sum, item) => sum + item.durationSeconds);
  }
}
