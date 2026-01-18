import 'package:flutter/material.dart';

class AppUtils {
  static Color getTagColor(String tag) {
    final List<Color> palette = [
      Colors.blue, Colors.red, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
      Colors.brown, Colors.cyan,
    ];
    return palette[tag.hashCode.abs() % palette.length];
  }

  static String formatMinutes(int minutes) {
    if (minutes == 0) return "0m";
    int h = minutes ~/ 60;
    int m = minutes % 60;
    if (h > 0){
      return "${h}h ${m.toString().padLeft(2, '0')}m";
    } else {
      return "${m}m";
    }
  }

  static String formatHistoryDuration(int seconds) {
    Duration d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
    }
    return "${d.inMinutes}m ${d.inSeconds.remainder(60)}s";
  }
}
