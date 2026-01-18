import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import '../models/history_time.dart';
import '../utils/app_utils.dart';
import 'floating_tooltip.dart';

class SkillHeatMap extends StatefulWidget {
  final Map<DateTime, int> datasets;
  final List<HistoryItem> historyList;

  const SkillHeatMap({
    super.key,
    required this.datasets,
    required this.historyList,
  });

  @override
  State<SkillHeatMap> createState() => _SkillHeatMapState();
}

class _SkillHeatMapState extends State<SkillHeatMap> {
  Timer? _tooltipTimer;
  bool _showTooltip = false;
  String _tooltipText = "";

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }

  void _triggerTooltip(DateTime date) {
    _tooltipTimer?.cancel();

    // 正確な時間を計算
    final dailySeconds = AppUtils.getExactDailySeconds(date, widget.historyList);
    final weeklySeconds = AppUtils.getExactWeeklySeconds(date, widget.historyList);

    setState(() {
      _showTooltip = true;
      _tooltipText = "${DateFormat('MM/dd').format(date)}\n"
          "Day: ${AppUtils.formatExactTime(dailySeconds)}\nWeek: ${AppUtils.formatExactTime(weeklySeconds)}";
    });

    _tooltipTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showTooltip = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollStartNotification) {
          _tooltipTimer?.cancel();
          setState(() => _showTooltip = false);
        }
        return false;
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          HeatMapCalendar(
            defaultColor: Colors.grey[200],
            flexible: true,
            colorMode: ColorMode.opacity,
            datasets: widget.datasets,
            colorsets: const { 1: Colors.teal },
            onClick: (value) {
              if (value != null) _triggerTooltip(value);
            },
          ),
          if (_showTooltip)
            Positioned(
              bottom: 10,
              child: AnimatedOpacity(
                opacity: _showTooltip ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingTooltip(text: _tooltipText),
              ),
            ),
        ],
      ),
    );
  }
}
