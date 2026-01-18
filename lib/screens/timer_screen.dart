import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

class TimerScreen extends StatefulWidget {
  final String skillName;
  final List<String> availableTags;

  const TimerScreen({
    super.key,
    required this.skillName,
    required this.availableTags,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  late Stopwatch _stopwatch;
  Timer? _timer;

  // 画面内で一時的にタグリストを管理する（追加できるようにするため）
  late List<String> currentTags;
  late String selectedTag;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    // 親から受け取ったタグリストをコピーして使う
    currentTags = List.from(widget.availableTags);
    selectedTag = currentTags.isNotEmpty ? currentTags.first : "General";

    // もしタグが空ならGeneralを入れておく
    if (currentTags.isEmpty) {
      currentTags.add("General");
      selectedTag = "General";
    }
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

  // ★追加: その場でタグを追加するダイアログ
  void _showAddTagDialogInTimer(Function(String) onAdd) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add New Tag"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Tag name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  onAdd(controller.text);
                  Navigator.pop(context);
                }
              },
              child: const Text("Add", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _finishAndSave() {
    String memo = "";
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // ダイアログ内で状態(タグリスト更新)を反映させるためにStatefulBuilderを使う
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Well done!"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ドロップダウンと追加ボタンを横並びにする
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            value: selectedTag,
                            isExpanded: true,
                            items: currentTags.map((String tag) {
                              return DropdownMenuItem<String>(
                                value: tag,
                                child: Text(tag),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setDialogState(() { // ダイアログ内の再描画
                                  selectedTag = newValue;
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            _showAddTagDialogInTimer((newTag) {
                              // 新しいタグが追加されたらリストに加え、それを選択状態にする
                              setDialogState(() {
                                if (!currentTags.contains(newTag)) {
                                  currentTags.add(newTag);
                                }
                                selectedTag = newTag;
                              });
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: "Memo (Optional)",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => memo = value,
                    ),
                  ],
                ),
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
                      'tag': selectedTag, // 新しく追加されたタグかもしれない
                    });
                  },
                  child: const Text("Save", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
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
            Text(
              _formatStopwatchTime(),
              style: const TextStyle(
                fontSize: 80,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 80),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(30),
                  ),
                  onPressed: _stopwatch.isRunning ? _stopTimer : _startTimer,
                  child: Icon(
                    _stopwatch.isRunning ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 30),
                if (_stopwatch.elapsed.inSeconds > 0 && !_stopwatch.isRunning)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(30),
                    ),
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
