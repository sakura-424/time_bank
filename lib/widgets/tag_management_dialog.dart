import 'package:flutter/material.dart';
import '../utils/app_utils.dart';

class TagManagementDialog extends StatefulWidget {
  final List<String> tags;
  final Function(String) onAdd;
  final Function(int) onRemove;

  const TagManagementDialog({
    super.key,
    required this.tags,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<TagManagementDialog> createState() => _TagManagementDialogState();
}

class _TagManagementDialogState extends State<TagManagementDialog> {
  final TextEditingController _tagController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Manage Tags"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(child: TextField(controller: _tagController, decoration: const InputDecoration(hintText: "New Tag Name"))),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.black),
                onPressed: () {
                  if (_tagController.text.isNotEmpty) {
                    widget.onAdd(_tagController.text);
                    _tagController.clear();
                    setState(() {});
                  }
                },
              )
            ]),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.tags.length,
                itemBuilder: (context, index) {
                  final tag = widget.tags[index];
                  return ListTile(
                    leading: Icon(Icons.label, color: AppUtils.getTagColor(tag)),
                    title: Text(tag),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () {
                        widget.onRemove(index);
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
    );
  }
}
