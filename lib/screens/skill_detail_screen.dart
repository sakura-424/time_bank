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
  int touchedIndex = -1;

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

  void _openDetailDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => HistoryDetailDialog(
        item: historyList[index],
        onEdit: () {
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
          content: const Text("Are you sure you want to delete this record? Time will be subtracted."),
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

  // ★追加: カレンダーの日付タップ時のダイアログ
  void _showCalendarDayDialog(DateTime date, int dailyMinutes, int weeklyMinutes) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(DateFormat('yyyy/MM/dd (E)').format(date)), // 例: 2026/01/20 (Tue)
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // その日の時間
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Daily Total:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    AppUtils.formatMinutes(dailyMinutes),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              // 週の合計
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Weekly Total:", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(
                    AppUtils.formatMinutes(weeklyMinutes),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  List<PieChartSectionData> _getPieChartSections(Map<String, int> tagTotals, int totalSeconds) {
    if (totalSeconds == 0) return [];

    int index = 0;
    return tagTotals.entries.map((entry) {
      final isTouched = index == touchedIndex;
      final percentage = (entry.value / totalSeconds) * 100;
      final isLarge = percentage > 10;

      final double radius = isTouched ? 60 : 50;
      final String text = isLarge ? '${percentage.toStringAsFixed(0)}%' : '';

      final section = PieChartSectionData(
        color: AppUtils.getTagColor(entry.key),
        value: entry.value.toDouble(),
        title: text,
        radius: radius,
        titleStyle: TextStyle(
          fontSize: isTouched ? 16 : 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        borderSide: isTouched ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
      );

      index++;
      return section;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {

    Map<String, int> tagTotals = {};
    int totalSeconds = 0;
    for (var item in historyList) {
      tagTotals[item.tag] = (tagTotals[item.tag] ?? 0) + item.durationSeconds;
      totalSeconds += item.durationSeconds;
    }
    final pieSections = _getPieChartSections(tagTotals, totalSeconds);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.skill.name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _openTagManager),
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
                height: 250,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                touchedIndex = -1;
                                return;
                              }
                              touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sections: pieSections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                    if (touchedIndex != -1 && touchedIndex < tagTotals.length)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tagTotals.keys.elementAt(touchedIndex),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Text("Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
            ),
            const SizedBox(height: 10),
            HeatMapCalendar(
              defaultColor: Colors.grey[200],
              flexible: true,
              colorMode: ColorMode.opacity,
              datasets: heatmapDataset,
              colorsets: const { 1: Colors.teal },
              // ★ここを変更: SnackBarではなくDialogを表示する関数を呼ぶ
              onClick: (value) {
                if (value != null) {
                  final dailyMinutes = heatmapDataset[value] ?? 0;
                  final weeklyMinutes = SkillService.getWeeklyTotal(value, heatmapDataset);

                  _showCalendarDayDialog(value, dailyMinutes, weeklyMinutes);
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
