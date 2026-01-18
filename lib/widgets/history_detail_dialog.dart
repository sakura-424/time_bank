import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/history_time.dart';
import '../utils/app_utils.dart';

class HistoryDetailDialog extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HistoryDetailDialog({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppUtils.getTagColor(item.tag);

    return AlertDialog(
      title: Text(DateFormat('yyyy/MM/dd HH:mm').format(item.date), style: const TextStyle(fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
            child: Text(item.tag, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.timer, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(AppUtils.formatHistoryDuration(item.durationSeconds), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          const Text("Memo:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(item.memo.isEmpty ? "No memo" : item.memo, style: const TextStyle(fontSize: 16)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
        ),
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onEdit();
          },
          icon: const Icon(Icons.edit, size: 18),
          label: const Text("Edit"),
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
      ],
    );
  }
}
