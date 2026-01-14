import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const TimeBankApp());
}

class TimeBankApp extends StatelessWidget {
  const TimeBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '10,000 Hours',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.black,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class Skill {
  String name;
  Duration totalTime;
  Skill({required this.name, this.totalTime = Duration.zero});
}

// --- ホーム画面 ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Skill> mySkills = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      List<String>? savedSkillNames = prefs.getStringList('skill_names');
      if (savedSkillNames != null) {
        mySkills = savedSkillNames.map((name) => Skill(name: name)).toList();
      } else {
        mySkills = [Skill(name: "Programming"), Skill(name: "English")];
      }
      for (var skill in mySkills) {
        int seconds = prefs.getInt(skill.name) ?? 0;
        skill.totalTime = Duration(seconds: seconds);
      }
    });
  }

  Future<void> _addNewSkill(String newSkillName) async {
    if (newSkillName.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      mySkills.add(Skill(name: newSkillName));
    });
    List<String> nameList = mySkills.map((skill) => skill.name).toList();
    await prefs.setStringList('skill_names', nameList);
  }

  String _formatTotalTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = d.inHours.toString();
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return '${hours}h ${minutes}m ${seconds}s';
  }

  void _showAddSkillDialog() {
    String newName = "";
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("New Skill"),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter skill name"),
            onChanged: (value) => newName = value,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () {
                _addNewSkill(newName);
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Time Assets')),
      body: mySkills.isEmpty
          ? const Center(child: Text("Press + to add a skill"))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: mySkills.length,
              separatorBuilder: (context, index) => const Divider(height: 30),
              itemBuilder: (context, index) {
                final skill = mySkills[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(skill.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  trailing: Text(
                    _formatTotalTime(skill.totalTime),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SkillDetailScreen(skill: skill)),
                    );
                    _loadData();
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: _showAddSkillDialog,
      ),
    );
  }
}

// --- 履歴データクラス ---
class HistoryItem {
  final DateTime date;
  final int durationSeconds;
  final String memo;

  HistoryItem({required this.date, required this.durationSeconds, required this.memo});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'durationSeconds': durationSeconds,
    'memo': memo,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      date: DateTime.parse(json['date']),
      durationSeconds: json['durationSeconds'],
      memo: json['memo'] ?? '',
    );
  }
}

// --- 詳細画面 ---
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

  // セッション保存（新規）
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

    await _saveHistoryToPrefs(); // リスト保存処理を共通化
    _loadData();
  }

  // ★履歴リストだけを保存する共通関数
  Future<void> _saveHistoryToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonList = historyList.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('${widget.skill.name}_history', jsonList);
  }

  // ★メモの更新機能
  void _updateMemo(int index, String newMemo) {
    setState(() {
      final oldItem = historyList[index];
      // 同じ内容でメモだけ書き換えた新しいアイテムに入れ替える
      historyList[index] = HistoryItem(
        date: oldItem.date,
        durationSeconds: oldItem.durationSeconds,
        memo: newMemo,
      );
    });
    _saveHistoryToPrefs(); // 保存
  }

  String _formatMinutes(int minutes) {
    if (minutes == 0) return "0m";
    int h = minutes ~/ 60;
    int m = minutes % 60;
    if (h > 0) {
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
    for (int i = 0; i < 7; i++) {
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

  // ★編集用ダイアログ
  void _showEditDialog(int index) {
    final TextEditingController controller = TextEditingController(text: historyList[index].memo);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Memo"),
          content: TextField(
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
                Navigator.pop(context); // 編集ダイアログを閉じる
                Navigator.pop(context); // 詳細ダイアログも閉じる（画面更新のため）
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ★詳細表示ダイアログ（編集ボタン付き）
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
            // ★編集ボタン
            TextButton.icon(
              onPressed: () {
                // 詳細画面の上に編集画面を出す
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
                       content: Text("Daily: ${_formatMinutes(dailyMinutes)}  (Weekly: ${_formatMinutes(weeklyMinutes)})"),
                       duration: const Duration(seconds: 2),
                       behavior: SnackBarBehavior.floating,
                     ),
                   );
                }
              },
            ),
            const Divider(height: 40, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      // ★indexを渡して詳細を開く
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

// --- タイマー画面 ---
class TimerScreen extends StatefulWidget {
  final String skillName;
  const TimerScreen({super.key, required this.skillName});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  late Stopwatch _stopwatch;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => setState(() {}));
  }

  void _stopTimer() {
    _stopwatch.stop();
    _timer?.cancel();
    setState(() {});
  }

  void _finishAndSave() {
    String memo = "";
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Well done!"),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Memo (Optional)",
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => memo = value,
          ),
          actions: [
            TextButton(
              onPressed: () {
                 Navigator.pop(context);
                 Navigator.pop(context);
              },
              child: const Text("Don't Save", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, {
                  'seconds': _stopwatch.elapsed.inSeconds,
                  'memo': memo,
                });
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _formatStopwatchTime() {
    final duration = _stopwatch.elapsed;
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.skillName, style: const TextStyle(fontSize: 20, color: Colors.grey)),
            const SizedBox(height: 40),
            Text(_formatStopwatchTime(), style: const TextStyle(fontSize: 80, fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 80),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: const CircleBorder(), padding: const EdgeInsets.all(30)),
                  onPressed: _stopwatch.isRunning ? _stopTimer : _startTimer,
                  child: Icon(_stopwatch.isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 30),
                if (_stopwatch.elapsed.inSeconds > 0 && !_stopwatch.isRunning)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: const CircleBorder(), padding: const EdgeInsets.all(30)),
                    onPressed: _finishAndSave,
                    child: const Icon(Icons.check, color: Colors.white, size: 30),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
