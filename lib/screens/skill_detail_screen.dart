import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _saveSession(int durationSeconds, String memo) async {
    final prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();

    widget.skill.totalTime += Duration(seconds: durationSeconds);
    await prefs.setInt(widget.skill.name, widget.skill.totalTime.inSeconds);

    String dateKey = "${widget.skill.name}_${DateFormat('yyyyMMdd').format(now)}";
    int todaySeconds = prefs.getInt(dateKey) ?? 0;
    await prefs.setInt(dateKey, todaySeconds + durationSeconds);

    final newItem = HistoryItem(date: now, durationSeconds: durationSeconds, memo: memo);
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
      );
    });
    _saveHistoryToPrefs();
  }

  String _formatMinutes(int minutes) {
    if (minutes == 0)
      return "0m";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.skill.name)),
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
                    leading: const Icon(Icons.check_circle_outline, color: Colors.teal),
                    title: Text(
                      DateFormat('yyyy/MM/dd HH:mm').format(item.date),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: item.memo.isNotEmpty
                      ? Text(item.memo, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
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
            MaterialPageRoute(builder: (context) => TimerScreen(skillName: widget.skill.name)),
          );
          if (result != null && result is Map) {
            _saveSession(result['seconds'], result['memo']);
          }
        },
      ),
    );
  }
}
