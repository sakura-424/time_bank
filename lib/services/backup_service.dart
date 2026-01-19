import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class BackupService {

  // バックアップファイルを作成して共有/保存する
  static Future<void> exportData(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, dynamic> backupData = {};

      // アプリに関連するデータだけを抽出
      final systemPrefixes = ['tags_', 'flutter.']; // flutter.は除外しないとシステム設定まで混ざる

      for (String key in keys) {
        // キーワードでフィルタリングして、必要なデータだけ集める
        // "flutter." で始まる内部データ以外は基本的に全部バックアップ対象にする
        if (!key.startsWith('flutter.')) {
           final value = prefs.get(key);
           backupData[key] = value;
        }
      }

      // JSONに変換
      String jsonString = jsonEncode(backupData);

      // 一時ファイルとして保存
      final directory = await getTemporaryDirectory();
      final fileName = "time_bank_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json";
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      // Share機能を使って、ユーザーに保存先を選ばせる（Google Driveやファイルアプリなど）
      // iPadなどではboxの位置指定が必要なため、contextを使って位置を指定
      final box = context.findRenderObject() as RenderBox?;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Time Bank Backup Data',
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export failed: $e")),
      );
    }
  }

  // ファイルを選択して復元する
  static Future<bool> importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();

        Map<String, dynamic> data = jsonDecode(jsonString);
        final prefs = await SharedPreferences.getInstance();

        // データの復元処理
        for (var entry in data.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is double) {
            await prefs.setDouble(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          } else if (value is String) {
            await prefs.setString(key, value);
          } else if (value is List) {
            List<String> stringList = value.map((e) => e.toString()).toList();
            await prefs.setStringList(key, stringList);
          }
        }

        // ★ここではスナックバーを出さず、成功したことだけを返す
        return true;

      } else {
        // キャンセルされた場合
        return false;
      }
    } catch (e) {
      // エラーは呼び出し元でキャッチしてもらうために投げる
      throw Exception("Import failed: $e");
    }
  }
}
