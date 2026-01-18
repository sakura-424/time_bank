import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../models/skill.dart';
import '../models/history_time.dart';

class SkillService {

  // タグの読み込み
  static Future<List<String>> loadTags(String skillName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? savedTags = prefs.getStringList('tags_$skillName');
    return (savedTags != null && savedTags.isNotEmpty) ? savedTags : ["General"];
  }

  // タグの保存
  static Future<void> saveTags(String skillName, List<String> tags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tags_$skillName', tags);
  }

  // 履歴リストの読み込み
  static Future<List<HistoryItem>> loadHistory(String skillName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyJsonList = prefs.getStringList('${skillName}_history') ?? [];

    List<HistoryItem> list = historyJsonList.map((jsonStr) {
      return HistoryItem.fromJson(jsonDecode(jsonStr));
    }).toList();

    // 日付順に並び替え
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // 履歴リストの保存
  static Future<void> saveHistory(String skillName, List<HistoryItem> historyList) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonList = historyList.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('${skillName}_history', jsonList);
  }

  // セッションの保存（合計時間の更新含む）
  static Future<void> saveSession(Skill skill, int durationSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();

    // 合計時間の更新
    skill.totalTime += Duration(seconds: durationSeconds);
    await prefs.setInt(skill.name, skill.totalTime.inSeconds);

    // カレンダー用データの更新（日付ごとの秒数）
    String dateKey = "${skill.name}_${DateFormat('yyyyMMdd').format(now)}";
    int todaySeconds = prefs.getInt(dateKey) ?? 0;
    await prefs.setInt(dateKey, todaySeconds + durationSeconds);
  }

  // カレンダー用データの作成
  static Future<Map<DateTime, int>> loadHeatmapData(String skillName) async {
    final prefs = await SharedPreferences.getInstance();
    Map<DateTime, int> dataset = {};
    DateTime date = DateTime.now().subtract(const Duration(days: 365));
    DateTime end = DateTime.now();

    while (date.isBefore(end) || date.isAtSameMomentAs(end)) {
      String key = "${skillName}_${DateFormat('yyyyMMdd').format(date)}";
      int seconds = prefs.getInt(key) ?? 0;
      if (seconds > 0) {
        dataset[DateTime(date.year, date.month, date.day)] = (seconds / 60).ceil();
      }
      date = date.add(const Duration(days: 1));
    }
    return dataset;
  }

  // 週の合計時間を計算
  static int getWeeklyTotal(DateTime date, Map<DateTime, int> heatmapDataset) {
    int difference = date.weekday == 7 ? 0 : date.weekday;
    DateTime startOfWeek = date.subtract(Duration(days: difference));
    startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    int totalMinutes = 0;
    for (int i = 0; i < 7; i++)
    {
      DateTime checkDate = startOfWeek.add(Duration(days: i));
      if (heatmapDataset.containsKey(checkDate)) {
        totalMinutes += heatmapDataset[checkDate]!;
      }
    }
    return totalMinutes;
  }

  // 履歴作所と時間の巻き戻し
  static Future<void> deleteSession(Skill skill, HistoryItem item, List<HistoryItem> currentList) async {
    final prefs = await SharedPreferences.getInstance();

    // リストから削除
    currentList.remove(item);
    List<String> jsonList = currentList.map((i) => jsonEncode(i.toJson())).toList();
    await prefs.setStringList('${skill.name}_history', jsonList);

    // 合計時間からマイナスして保存
    skill.totalTime -= Duration(seconds: item.durationSeconds);
    if (skill.totalTime.isNegative) {
      skill.totalTime = Duration.zero;
    }
    await prefs.setInt(skill.name, skill.totalTime.inSeconds);

    // カレンダーからマイナスして保存
    String dateKey = "${skill.name}_${DateFormat('yyyyMMdd').format(item.date)}";
    int currentDaySeconds = prefs.getInt(dateKey) ?? 0;
    int newDaySeconds = currentDaySeconds - item.durationSeconds;

    if (newDaySeconds < 0) newDaySeconds = 0;
    await prefs.setInt(dateKey, newDaySeconds);
  }
}
