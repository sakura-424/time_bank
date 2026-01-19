import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/history_time.dart';
import '../utils/app_utils.dart';
import 'floating_tooltip.dart';

class SkillPieChart extends StatefulWidget {
  final List<HistoryItem> historyList;
  const SkillPieChart({super.key, required this.historyList});

  @override
  State<SkillPieChart> createState() => _SkillPieChartState();
}

class _SkillPieChartState extends State<SkillPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    // データを集計
    Map<String, int> tagTotals = {};
    int totalSeconds = 0;
    for (var item in widget.historyList) {
      tagTotals[item.tag] = (tagTotals[item.tag] ?? 0) + item.durationSeconds;
      totalSeconds += item.durationSeconds;
    }

    if (totalSeconds == 0) return const SizedBox.shrink();

    final pieSections = _getSections(tagTotals, totalSeconds);

    return Column(
      children: [
        // --- 円グラフ本体 ---
        SizedBox(
          height: 250,
          child: Stack(
            alignment: Alignment.center,
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
              // 触った時のポップアップ
              if (touchedIndex != -1 && touchedIndex < tagTotals.length)
                FloatingTooltip(text: tagTotals.keys.elementAt(touchedIndex)),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildLegend(tagTotals),
      ],
    );
  }

  // ★凡例を作るパーツ
  Widget _buildLegend(Map<String, int> tagTotals) {
    // ★現在のテーマがダークモードかどうか判定
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ★文字色を動的に決める（ダークなら白、ライトなら黒）
    final textColor = isDark ? Colors.white70 : Colors.black87;
    return Wrap(
      alignment: WrapAlignment.center, // 中央揃え
      spacing: 16, // 横の間隔
      runSpacing: 8, // 縦の間隔
      children: tagTotals.keys.map((tag) {
        final color = AppUtils.getTagColor(tag);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 色の丸ポチ
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            // タグ名
            Text(
              tag,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  List<PieChartSectionData> _getSections(Map<String, int> tagTotals, int totalSeconds) {
    int index = 0;
    return tagTotals.entries.map((entry) {
      final isTouched = index == touchedIndex;
      final percentage = (entry.value / totalSeconds) * 100;
      final isLarge = percentage > 10;

      final double radius = isTouched ? 60 : 50;
      // グラフの中は％表示だけにしてスッキリさせる
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
}
