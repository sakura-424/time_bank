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

  // ★修正: 古いデータを削除してから再計算する
  static Future<Map<String, dynamic>> syncDataFromHistory(Skill skill, List<HistoryItem> historyList) async {
    final prefs = await SharedPreferences.getInstance();

    // --- 【追加】クリーンアップ処理 開始 ---

    final allKeys = prefs.getKeys(); // 保存されている全キーを取得
    final String prefix = "${skill.name}_";

    for (String key in allKeys) {
      // このスキルのキーかチェック
      if (key.startsWith(prefix)) {
        // キーの末尾（日付部分）を取り出す
        String suffix = key.substring(prefix.length);

        // 末尾が8桁の数字（yyyyMMdd）であれば、それはカレンダー用のデータなので削除する
        if (suffix.length == 8 && int.tryParse(suffix) != null) {
          await prefs.remove(key);
        }
      }
    }

    //  合計時間をゼロから再計算
    int totalSeconds = 0;
    // カレンダーデータもゼロから再計算
    Map<DateTime, int> newHeatmap = {};

    // 履歴を全件回して集計しなおす
    for (var item in historyList) {
      totalSeconds += item.durationSeconds;

      // 日付ごとの集計
      DateTime dateKey = DateTime(item.date.year, item.date.month, item.date.day);

      // 分単位で加算 (カレンダーライブラリの仕様)
      int minutes = (item.durationSeconds / 60).ceil();
      newHeatmap[dateKey] = (newHeatmap[dateKey] ?? 0) + minutes;
    }

    // 合計時間を保存
    skill.totalTime = Duration(seconds: totalSeconds);
    await prefs.setInt(skill.name, totalSeconds);

    // カレンダー用データを保存
    for (var entry in newHeatmap.entries) {
      String key = "${skill.name}_${DateFormat('yyyyMMdd').format(entry.key)}";

      // その日の合計秒数を計算
      int dayTotalSeconds = historyList
          .where((item) =>
              item.date.year == entry.key.year &&
              item.date.month == entry.key.month &&
              item.date.day == entry.key.day)
          .fold(0, (sum, item) => sum + item.durationSeconds);

      await prefs.setInt(key, dayTotalSeconds);
    }

    return {
      'totalTime': totalSeconds,
      'heatmap': newHeatmap,
    };
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
    DateTime startOfWeek = DateTime(date.year, date.month, date.day).subtract(Duration(days: difference));
    int totalMinutes = 0;
    for (int i = 0; i < 7; i++) {
      DateTime checkDate = startOfWeek.add(Duration(days: i));
      if (heatmapDataset.containsKey(checkDate)) {
        totalMinutes += heatmapDataset[checkDate]!;
      }
    }
    return totalMinutes;
  }

  // スキルを完全に削除する
  static Future<void> deleteSkill(String skillName) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 基本データの削除
    await prefs.remove(skillName); // 合計時間
    await prefs.remove('${skillName}_history'); // 履歴リスト
    await prefs.remove('tags_$skillName'); // タグリスト

    // 2. カレンダーデータの削除（キー検索して削除）
    final allKeys = prefs.getKeys();
    final String prefix = "${skillName}_";
    for (String key in allKeys) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
  }

  // スキルの名前を変更する（データ移行）
  static Future<void> renameSkill(Skill skill, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    String oldName = skill.name;

    if (oldName == newName) return;

    // 1. 古いデータを全部読み込む
    int totalTime = prefs.getInt(oldName) ?? 0;
    List<String> tags = await loadTags(oldName);
    List<HistoryItem> history = await loadHistory(oldName);

    // 2. 新しい名前で保存し直す
    skill.name = newName; // オブジェクトの名前更新
    await prefs.setInt(newName, totalTime);
    await saveTags(newName, tags);
    await saveHistory(newName, history);

    // syncDataFromHistory を呼んでカレンダーデータを新しい名前で展開・再構築
    await syncDataFromHistory(skill, history);

    // 3. 古いデータを削除する
    await deleteSkill(oldName);
  }
}
