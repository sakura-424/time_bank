import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/skill.dart';
import '../models/history_time.dart';
import '../utils/app_utils.dart';
import '../services/skill_service.dart';
import 'timer_screen.dart';

class SkillDetailScreen extends StatefulWidget {
  final Skill skill;
  const SkillDetailScreen({super.key, required this.skill});

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  Map<DateTime, int> heatmapDataset = {};
  List<HistoryItem> historyList = [];
  List<String> myTags = [];

  @override
  void initState() {
    super.initState();
    _refreshAllData();
  }

  // 画面全体のデータを再読み込み
  Future<void> _refreshAllData() async {
    final tags = await SkillService.loadTags(widget.skill.name);
    final history = await SkillService.loadHistory(widget.skill.name);
    final heatmap = await SkillService.loadHeatmapData(widget.skill.name);

    setState(() {
      myTags = tags;
      historyList = history;
      heatmapDataset = heatmap;
    });
  }

  // タイマー終了後の保存処理
  Future<void> _handleSaveSession(int durationSeconds, String memo, String tag) async {
    // 1. 合計時間などの保存
    await SkillService.saveSession(widget.skill, durationSeconds);

    // 2. 履歴リストへの追加と保存
    final newItem = HistoryItem(
      date: DateTime.now(),
      durationSeconds: durationSeconds,
      memo: memo,
      tag: tag
    );
    // リストの先頭に追加して保存
    historyList.insert(0, newItem);
    await SkillService.saveHistory(widget.skill.name, historyList);

    // 3. 画面更新
    _refreshAllData();
  }

  // メモ更新処理
  Future<void> _handleUpdateMemo(int index, String newMemo) async {
    setState(() {
      final oldItem = historyList[index];
      historyList[index] = HistoryItem(
        date: oldItem.date,
        durationSeconds: oldItem.durationSeconds,
        memo: newMemo,
        tag: oldItem.tag,
      );
    });
    await SkillService.saveHistory(widget.skill.name, historyList);
  }

  // タグ追加削除処理
  Future<void> _handleAddTag(String newTag) async {
    setState(() {
      myTags.add(newTag);
    });
    await SkillService.saveTags(widget.skill.name, myTags);
  }

  Future<void> _handleRemoveTag(int index) async {
    setState(() {
      myTags.removeAt(index);
    });
    await SkillService.saveTags(widget.skill.name, myTags);
  }

  // 円グラフのデータ生成
  List<PieChartSectionData> _getPieChartSections() {
    Map<String, int> tagTotals = {};
    int total = 0;
    for (var item in historyList) {
      tagTotals[item.tag] = (tagTotals[item.tag] ?? 0) + item.durationSeconds;
      total += item.durationSeconds;
    }

    if (total == 0) return [];

    return tagTotals.entries.map((entry) {
      final percentage = (entry.value / total) * 100;
      final isLarge = percentage > 10;
      final color = AppUtils.getTagColor(entry.key); // Utilsを使用

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: isLarge ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  // --- ダイアログ表示系 ---

  void _showTagManageDialog() {
    TextEditingController tagController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Manage Tags"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                        Expanded(child: TextField(controller: tagController, decoration: const InputDecoration(hintText: "New Tag Name"))),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.black),
                          onPressed: () {
                            if (tagController.text.isNotEmpty) {
                              _handleAddTag(tagController.text); // ロジック呼び出し
                              setDialogState(() => tagController.clear());
                            }
                          },
                        ),
                    ]),
                    const SizedBox(height: 20),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: myTags.length,
                        itemBuilder: (context, index) {
                          final tag = myTags[index];
                          return ListTile(
                            leading: Icon(Icons.label, color: AppUtils.getTagColor(tag)),
                            title: Text(tag),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () {
                                _handleRemoveTag(index); // ロジック呼び出し
                                setDialogState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
            );
          },
        );
      }
    );
  }

  void _showEditDialog(int index) {
    final controller = TextEditingController(text: historyList[index].memo);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Memo"),
          content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: "Enter memo")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () {
                _handleUpdateMemo(index, controller.text); // ロジック呼び出し
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDetailDialog(int index) {
    final item = historyList[index];
    final color = AppUtils.getTagColor(item.tag);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(DateFormat('yyyy/MM/dd HH:mm').format(item.date), style: const TextStyle(fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(item.tag, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                  const Icon(Icons.timer, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(AppUtils.formatHistoryDuration(item.durationSeconds), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),
              const Text("Memo:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(item.memo.isEmpty ? "No memo" : item.memo, style: const TextStyle(fontSize: 16)),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => _showEditDialog(index),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Edit"),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pieSections = _getPieChartSections();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.skill.name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _showTagManageDialog),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Text(
                "${widget.skill.totalTime.inHours}h ${widget.skill.totalTime.inMinutes.remainder(60).toString().padLeft(2, '0')}m",
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),
            if (pieSections.isNotEmpty) ...[
              const SizedBox(height: 30),
              SizedBox(
                height: 200,
                child: PieChart(PieChartData(sections: pieSections, centerSpaceRadius: 40, sectionsSpace: 2)),
              ),
            ],
            const SizedBox(height: 30),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: const Text("Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            HeatMapCalendar(
              defaultColor: Colors.grey[200],
              flexible: true,
              colorMode: ColorMode.opacity,
              datasets: heatmapDataset,
              colorsets: const { 1: Colors.teal },
              onClick: (value) {
                if (value != null) {
                  final dailyMinutes = heatmapDataset[value] ?? 0;
                  final weeklyMinutes = SkillService.getWeeklyTotal(value, heatmapDataset); // Serviceを使用
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Daily: ${AppUtils.formatMinutes(dailyMinutes)} (Weekly: ${AppUtils.formatMinutes(weeklyMinutes)})"),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const Divider(height: 40, thickness: 1),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: const Text("History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            if (historyList.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No history yet.", style: TextStyle(color: Colors.grey))))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: historyList.length,
                itemBuilder: (context, index) {
                  final item = historyList[index];
                  return ListTile(
                    leading: Icon(Icons.check_circle, color: AppUtils.getTagColor(item.tag)), // Utilsを使用
                    title: Text(DateFormat('yyyy/MM/dd HH:mm').format(item.date), style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: AppUtils.getTagColor(item.tag).withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
                          child: Text(item.tag, style: TextStyle(fontSize: 10, color: AppUtils.getTagColor(item.tag), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        if (item.memo.isNotEmpty) Expanded(child: Text(item.memo, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    trailing: Text(AppUtils.formatHistoryDuration(item.durationSeconds), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onTap: () => _showDetailDialog(index),
                  );
                },
              ),
              const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black,
        icon: const Icon(Icons.timer, color: Colors.white),
        label: const Text("Start Timer", style: TextStyle(color: Colors.white)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TimerScreen(skillName: widget.skill.name, availableTags: myTags)),
          );
          if (result != null && result is Map) {
            _handleSaveSession(result['seconds'], result['memo'], result['tag']);
          }
        },
      ),
    );
  }
}
