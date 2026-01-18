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
  late String selectedTag;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    // タグリストが空なら "General" をデフォルトにする
    selectedTag = widget.availableTags.isNotEmpty ? widget.availableTags.first : "General";
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
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Well done!"),
              // ★修正点1: キーボードが出てもエラーにならないようにスクロール可能にする
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.availableTags.isNotEmpty)
                      DropdownButton<String>(
                        value: selectedTag,
                        isExpanded: true,
                        items: widget.availableTags.map((String tag) {
                          return DropdownMenuItem<String>(
                            value: tag,
                            child: Text(tag),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedTag = newValue;
                            });
                          }
                        },
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
                      'tag': selectedTag,
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
                  // ★修正点2: const を追加
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
