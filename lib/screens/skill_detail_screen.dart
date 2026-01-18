import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/skill.dart';
import '../models/history_time.dart';
import '../utils/app_utils.dart';
import '../services/skill_service.dart';
import 'timer_screen.dart';

import '../widgets/tag_management_dialog.dart';
import '../widgets/edit_memo_dialog.dart';
import '../widgets/history_detail_dialog.dart';
import '../widgets/skill_pie_chart.dart';
import '../widgets/skill_heatmap.dart';

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
    final syncResult = await SkillService.syncDataFromHistory(widget.skill, history);

    setState(() {
      myTags = tags;
      historyList = history;
      widget.skill.totalTime = Duration(seconds: syncResult['totalTime']);
      heatmapDataset = syncResult['heatmap'];
    });
  }

  Future<void> _handleSaveSession(int durationSeconds, String memo, String tag) async {
    // ★もしタイマー画面で新しいタグが作られていたら、タグリストにも保存しておく
    if (!myTags.contains(tag)) {
      myTags.add(tag);
      await SkillService.saveTags(widget.skill.name, myTags);
    }

    // リストに追加
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

  Future<void> _handleChangeHistoryTag(int index, String newTag) async {
    final oldItem = historyList[index];
    setState(() {
      historyList[index] = HistoryItem(
        date: oldItem.date,
        durationSeconds: oldItem.durationSeconds,
        memo: oldItem.memo,
        tag: newTag, // タグを更新
      );
    });
    await SkillService.saveHistory(widget.skill.name, historyList);
    _refreshAllData(); // グラフの色などを更新
  }

  // ★タグ変更ダイアログ
  void _showChangeTagDialog(int index) {
    String selectedTag = historyList[index].tag;
    // もし現在のタグがリストになければ（削除された場合など）、リストの最初かGeneralにする
    if (!myTags.contains(selectedTag)) {
       selectedTag = myTags.isNotEmpty ? myTags.first : "General";
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Change Tag"),
              content: DropdownButton<String>(
                value: selectedTag,
                isExpanded: true,
                items: myTags.map((String tag) {
                  return DropdownMenuItem<String>(
                    value: tag,
                    child: Text(tag),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setDialogState(() {
                      selectedTag = newValue;
                    });
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                    _handleChangeHistoryTag(index, selectedTag);
                  },
                  child: const Text("Update", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 詳細ダイアログ表示（タグの横に編集ボタンをつける）
  void _openDetailDialog(int index) {
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
              // タグ表示部分を修正: アイコンボタンを追加
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                    child: Text(item.tag, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  // タグ編集ボタン
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                    onPressed: () {
                      Navigator.pop(context); // 一旦詳細を閉じる
                      _showChangeTagDialog(index); // タグ変更ダイアログを開く
                    },
                    tooltip: "Change Tag",
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 時間
              Row(children: [
                  const Icon(Icons.timer, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(AppUtils.formatHistoryDuration(item.durationSeconds), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),
              // メモ
              const Text("Memo:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(item.memo.isEmpty ? "No memo" : item.memo, style: const TextStyle(fontSize: 16)),
            ],
          ),
          actions: [
            // メモ編集ボタン
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openEditDialog(index);
              },
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text("Edit Memo"),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
            // 削除ボタン
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(index);
              },
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              label: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ],
        );
      },
    );
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

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete History"),
          content: const Text("Are you sure you want to delete this record? Time will be subtracted."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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

  Future<void> _handleDeleteSession(HistoryItem item) async {
    // リストから削除
    historyList.remove(item);

    // 削除後のリストを保存
    await SkillService.saveHistory(widget.skill.name, historyList);
    await _refreshAllData();
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

  @override
  Widget build(BuildContext context) {
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
                "${widget.skill.totalTime.inHours}h ${widget.skill.totalTime.inMinutes.remainder(60).toString().padLeft(2, '0')}m ${widget.skill.totalTime.inSeconds.remainder(60).toString().padLeft(2, '0')}s",
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 30),
            // ★ 円グラフ部品
            SkillPieChart(historyList: historyList),

            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Text("Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
            ),
            const SizedBox(height: 10),

            // ★ カレンダー部品
            SkillHeatMap(datasets: heatmapDataset, historyList: historyList),

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
                          decoration: BoxDecoration(color: AppUtils.getTagColor(item.tag).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)),
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
