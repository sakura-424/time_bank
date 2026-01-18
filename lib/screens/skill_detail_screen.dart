import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/skill.dart';
import '../models/history_time.dart';
import '../utils/app_utils.dart';
import '../services/skill_service.dart';
import 'timer_screen.dart';

import '../widgets/tag_management_dialog.dart';
import '../widgets/edit_memo_dialog.dart';
import '../widgets/history_detail_dialog.dart';

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

  Future<void> _handleSaveSession(int durationSeconds, String memo, String tag) async {
    await SkillService.saveSession(widget.skill, durationSeconds);
    final newItem = HistoryItem(
      date: DateTime.now(),
      durationSeconds: durationSeconds,
      memo: memo,
      tag: tag
    );
    historyList.insert(0, newItem);
    await SkillService.saveHistory(widget.skill.name, historyList);
    _refreshAllData();
  }

  Future<void> _handleDeleteSession(HistoryItem item) async {
    await SkillService.deleteSession(widget.skill, item, historyList);
    _refreshAllData();
  }

  // --- UI表示ロジック ---

  // タグ管理ダイアログを表示
  void _openTagManager() {
    showDialog(
      context: context,
      builder: (context) => TagManagementDialog(
        tags: myTags,
        onAdd: (newTag) async {
          setState(() => myTags.add(newTag));
          await SkillService.saveTags(widget.skill.name, myTags);
        },
        onRemove: (index) async {
          setState(() => myTags.removeAt(index));
          await SkillService.saveTags(widget.skill.name, myTags);
        },
      ),
    );
  }

  // 詳細ダイアログを表示（そこから編集へも飛べる）
  void _openDetailDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => HistoryDetailDialog(
        item: historyList[index],
        onEdit: () {
          // 詳細を閉じた後に編集ダイアログを開く
          _openEditDialog(index);
        },
        onDelete: () {
          _confirmDelete(index);
        },
      ),
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete History"),
          content: const Text("Are you sure you want to delete this record? Time will be subtraced."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _handleDeleteSession(historyList[index]);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 編集ダイアログを表示
  void _openEditDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => EditMemoDialog(
        currentMemo: historyList[index].memo,
        onSave: (newMemo) async {
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
        },
      ),
    );
  }

  // 円グラフデータ生成
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
      return PieChartSectionData(
        color: AppUtils.getTagColor(entry.key),
        value: entry.value.toDouble(),
        title: isLarge ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
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
          IconButton(icon: const Icon(Icons.settings), onPressed: _openTagManager), // 切り出した関数を呼ぶ
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
                  final weeklyMinutes = SkillService.getWeeklyTotal(value, heatmapDataset);
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
                    leading: Icon(Icons.check_circle, color: AppUtils.getTagColor(item.tag)),
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
                    onTap: () => _openDetailDialog(index),
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
