import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class EditMemoDialog extends StatelessWidget {
  final String currentMemo;
  final Function(String) onSave;

  const EditMemoDialog({
    super.key,
    required this.currentMemo,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController(text: currentMemo);

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
            onSave(controller.text);
            Navigator.pop(context);
          },
          child: const Text("Save", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
