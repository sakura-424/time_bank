import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/skill.dart';
import '../models/history_time.dart';
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
    _loadData();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? savedTags = prefs.getStringList('tags_${widget.skill.name}');

    if (savedTags != null && savedTags.isNotEmpty) {
      setState(() {
        myTags = savedTags;
      });
    } else {
      setState(() {
        myTags = ["General"];
      });
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    Map<DateTime, int> dataset = {};
    DateTime date = DateTime.now().subtract(const Duration(days: 365));
    DateTime end = DateTime.now();
    while (date.isBefore(end) || date.isAtSameMomentAs(end)) {
      String key = "${widget.skill.name}_${DateFormat('yyyyMMdd').format(date)}";
      int seconds = prefs.getInt(key) ?? 0;
      if (seconds > 0) {
        dataset[DateTime(date.year, date.month, date.day)] = (seconds / 60).ceil();
      }
      date = date.add(const Duration(days: 1));
    }

    List<String> historyJsonList = prefs.getStringList('${widget.skill.name}_history') ?? [];
    List<HistoryItem> loadedHistory = historyJsonList.map((jsonStr) {
      return HistoryItem.fromJson(jsonDecode(jsonStr));
    }).toList();

    loadedHistory.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      heatmapDataset = dataset;
      historyList = loadedHistory;
    });
  }

  Future<void> _saveTags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tags_${widget.skill.name}', myTags);
  }

  Future<void> _saveSession(int durationSeconds, String memo, String tag) async {
    final prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();

    widget.skill.totalTime += Duration(seconds: durationSeconds);
    await prefs.setInt(widget.skill.name, widget.skill.totalTime.inSeconds);

    String dateKey = "${widget.skill.name}_${DateFormat('yyyyMMdd').format(now)}";
    int todaySeconds = prefs.getInt(dateKey) ?? 0;
    await prefs.setInt(dateKey, todaySeconds + durationSeconds);

    final newItem = HistoryItem(date: now, durationSeconds: durationSeconds, memo: memo, tag: tag);
    historyList.insert(0, newItem);

    await _saveHistoryToPrefs();
    _loadData();
  }

  Future<void> _saveHistoryToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonList = historyList.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('${widget.skill.name}_history', jsonList);
  }

  void _updateMemo(int index, String newMemo) {
    setState(() {
      final oldItem = historyList[index];
      historyList[index] = HistoryItem(
        date: oldItem.date,
        durationSeconds: oldItem.durationSeconds,
        memo: newMemo,
        tag: oldItem.tag,
      );
    });
    _saveHistoryToPrefs();
  }

  Color _getTagColor(String tag) {
    final List<Color> palette = [
      Colors.blue, Colors.red, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
      Colors.brown, Colors.cyan,
    ];
    return palette[tag.hashCode.abs() % palette.length];
  }

  String _formatMinutes(int minutes) {
    if (minutes == 0) return "0m";
    int h = minutes ~/ 60;
    int m = minutes % 60;
    if (h > 0){
      return "${h}h ${m.toString().padLeft(2, '0')}m";
    } else {
      return "${m}m";
    }
  }

  int _getWeeklyTotal(DateTime date) {
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

  String _formatHistoryDuration(int seconds) {
    Duration d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
    }
    return "${d.inMinutes}m ${d.inSeconds.remainder(60)}s";
  }

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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: tagController,
                            decoration: const InputDecoration(hintText: "New Tag Name"),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.black),
                          onPressed: () {
                            if (tagController.text.isNotEmpty) {
                              setState(() {
                                myTags.add(tagController.text);
                                _saveTags();
                              });
                              setDialogState(() {
                                tagController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: myTags.length,
                        itemBuilder: (context, index) {
                          final tag = myTags[index];
                          return ListTile(
                            leading: Icon(Icons.label, color: _getTagColor(tag)),
                            title: Text(tag),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  myTags.removeAt(index);
                                  _saveTags();
                                });
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
    );
  }

  void _showEditDialog(int index) {
    final TextEditingController controller = TextEditingController(text: historyList[index].memo);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Memo"),
          content: TextField (
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter memo"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () {
                _updateMemo(index, controller.text);
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(DateFormat('yyyy/MM/dd HH:mm').format(item.date), style: const TextStyle(fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タグ表示を追加
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTagColor(item.tag).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(item.tag, style: TextStyle(color: _getTagColor(item.tag), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.timer, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatHistoryDuration(item.durationSeconds),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text("Memo:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(
                item.memo.isEmpty ? "No memo" : item.memo,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                _showEditDialog(index);
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Edit"),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

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
        color: _getTagColor(entry.key),
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
        title: Text(widget.skill.name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showTagManageDialog,
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
                "${widget.skill.totalTime.inHours}h ${widget.skill.totalTime.inMinutes.remainder(60).toString().padLeft(2, '0')}m",
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),

            if (pieSections.isNotEmpty) ...[
              const SizedBox(height: 30),
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: pieSections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              Center(
                child: Wrap(
                  spacing: 10,
                  children: pieSections.map((section) {
                    // 色からタグ名を逆引き
                    String tagName = "Other";
                    return const SizedBox.shrink();
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Text("Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
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
                  final weeklyMinutes = _getWeeklyTotal(value);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Daily: ${_formatMinutes(dailyMinutes)} (Weekly: ${_formatMinutes(weeklyMinutes)})"),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const Divider(height: 40, thickness: 1),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text("History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
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
                    leading: Icon(Icons.check_circle, color: _getTagColor(item.tag)),
                    title: Text(
                      DateFormat('yyyy/MM/dd HH:mm').format(item.date),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: _getTagColor(item.tag).withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
                          child: Text(item.tag, style: TextStyle(fontSize: 10, color: _getTagColor(item.tag), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        if (item.memo.isNotEmpty)
                          Expanded(child: Text(item.memo, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    trailing: Text(
                      _formatHistoryDuration(item.durationSeconds),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onTap: () {
                      _showDetailDialog(index);
                    },
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
            MaterialPageRoute(builder: (context) => TimerScreen(
              skillName: widget.skill.name,
              availableTags: myTags,
            )),
          );
          if (result != null && result is Map) {
            _saveSession(result['seconds'], result['memo'], result['tag']);
          }
        },
      ),
    );
  }
}
