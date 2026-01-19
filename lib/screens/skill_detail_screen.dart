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

  // 複数選択用の変数
  bool _isSelectionMode = false;
  final Set<HistoryItem> _selectedItems = {};

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
      // データ更新時は選択モードを解除
      _isSelectionMode = false;
      _selectedItems.clear();
    });
  }

  Future<void> _handleSaveSession(int durationSeconds, String memo, String tag) async {
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
    historyList.remove(item);
    await SkillService.saveHistory(widget.skill.name, historyList);
    _refreshAllData();
  }

  // 一括削除ロジック
  Future<void> _handleBulkDelete() async {
    // 選択されたアイテムをリストから除外
    historyList.removeWhere((item) => _selectedItems.contains(item));

    // 保存して再計算
    await SkillService.saveHistory(widget.skill.name, historyList);
    await _refreshAllData();
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
        onEdit: () => _openEditDialog(index),
        onDelete: () => _confirmDelete(index),
      ),
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete History"),
        content: const Text("Are you sure you want to delete this record?"),
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
      ),
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
          _refreshAllData();
        },
      ),
    );
  }

  // 一括削除確認ダイアログ
  void _confirmBulkDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete ${_selectedItems.length} items"),
        content: const Text("Are you sure you want to delete these records?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _handleBulkDelete();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 選択モードの切り替え処理
  void _toggleSelection(HistoryItem item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
        // 全部選択解除されたら通常モードに戻る
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItems.add(item);
      }
    });
  }

  // 全選択・全解除の切り替えロジック
  void _toggleSelectAll() {
    setState(() {
      if (_selectedItems.length == historyList.length) {
        // すでに全選択されていたら -> 全解除
        _selectedItems.clear();
      } else {
        // それ以外なら -> 全選択
        _selectedItems.clear(); // 重複防止のため一旦クリア
        _selectedItems.addAll(historyList); // リストの中身を全部セットに追加
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ★AppBarを動的に切り替える
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.black),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedItems.clear();
                  });
                },
              ),
              title: Text("${_selectedItems.length} selected", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              actions: [
                // 全選択ボタン
                IconButton(
                  // 全選択状態なら「選択解除アイコン」、そうでなければ「全選択アイコン」
                  icon: Icon(
                    _selectedItems.length == historyList.length && historyList.isNotEmpty
                        ? Icons.deselect_outlined // 全解除っぽいアイコン
                        : Icons.select_all,       // 全選択アイコン
                  ),
                  tooltip: _selectedItems.length == historyList.length
                      ? "Deselect All"
                      : "Select All",
                  onPressed: _toggleSelectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _selectedItems.isEmpty ? null : _confirmBulkDelete,
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.black),
              title: Text(widget.skill.name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              actions: [
                // ★ここを変更: 設定アイコン1つではなく、メニューボタン(PopupMenuButton)にする
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'tags') {
                      _openTagManager();
                    } else if (value == 'select') {
                      // メニューから選択モードを開始できる
                      setState(() {
                        _isSelectionMode = true;
                      });
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    // タグ管理メニュー
                    const PopupMenuItem<String>(
                      value: 'tags',
                      child: ListTile(
                        leading: Icon(Icons.label),
                        title: Text('Manage Tags'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuDivider(),
                    // 履歴選択メニュー（ここから一括削除へ）
                    const PopupMenuItem<String>(
                      value: 'select',
                      child: ListTile(
                        leading: Icon(Icons.checklist), // チェックリストのアイコン
                        title: Text('Select History'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
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
            SkillPieChart(historyList: historyList),

            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Text("Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
            ),
            const SizedBox(height: 10),

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
                  // ★選択されているかどうか
                  final isSelected = _selectedItems.contains(item);

                  final listTile = ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.grey.withOpacity(0.1),
                    leading: _isSelectionMode
                        ? Icon(
                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isSelected ? Colors.black : Colors.grey,
                          )
                        : Icon(Icons.check_circle, color: AppUtils.getTagColor(item.tag)),
                    title: Text(DateFormat('yyyy/MM/dd HH:mm').format(item.date), style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Row(children: [
                        if (!_isSelectionMode) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: AppUtils.getTagColor(item.tag).withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
                            child: Text(item.tag, style: TextStyle(fontSize: 10, color: AppUtils.getTagColor(item.tag), fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (item.memo.isNotEmpty) Expanded(child: Text(item.memo, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    trailing: Text(AppUtils.formatHistoryDuration(item.durationSeconds), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(item);
                      } else {
                        _openDetailDialog(index);
                      }
                    },
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                          _toggleSelection(item);
                        });
                      }
                    },
                  );

                  // ★選択モード中はスワイプさせない
                  if (_isSelectionMode) {
                    return listTile;
                  }

                  // ★通常時はDismissibleで囲んでスワイプ削除可能にする
                  return Dismissible(
                    key: ObjectKey(item), // そのアイテム固有のキー
                    direction: DismissDirection.endToStart, // 右から左へのスワイプのみ許可

                    // スワイプした時の背景（赤いゴミ箱）
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),

                    // スワイプした瞬間の確認ロジック
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Delete History"),
                            content: const Text("Are you sure you want to delete this record?"),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false), // キャンセル
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.of(context).pop(true), // 削除実行
                                child: const Text("Delete", style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          );
                        },
                      );
                    },

                    // 削除が確定した後の処理
                    onDismissed: (direction) {
                      _handleDeleteSession(item);
                    },

                    child: listTile,
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      // ★選択モード中は「Start Timer」ボタンを隠す
      floatingActionButton: _isSelectionMode
        ? null
        : FloatingActionButton.extended(
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
