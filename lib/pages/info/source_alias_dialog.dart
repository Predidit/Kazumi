import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';

/// Deletions edit [aliases] in place and then fire [onAliasesChanged], so the
/// caller can persist the list it passed in.
void showAliasPickerDialog({
  required List<String> aliases,
  required ValueChanged<String> onAliasSelected,
  required VoidCallback onAliasesChanged,
}) {
  KazumiDialog.show(
    builder: (context) => _AliasPickerDialog(
      aliases: aliases,
      onAliasSelected: onAliasSelected,
      onAliasesChanged: onAliasesChanged,
    ),
  );
}

/// [onSubmit] never sees a blank keyword.
void showCustomKeywordDialog({required ValueChanged<String> onSubmit}) {
  String keyword = '';

  void submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    KazumiDialog.dismiss();
    onSubmit(trimmed);
  }

  KazumiDialog.show(
    builder: (context) => AlertDialog(
      title: const Text('输入别名'),
      content: TextField(
        onChanged: (value) => keyword = value,
        onSubmitted: submit,
      ),
      actions: [
        TextButton(
          onPressed: KazumiDialog.dismiss,
          child: Text(
            '取消',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: () => submit(keyword),
          child: const Text('确认'),
        ),
      ],
    ),
  );
}

class _AliasPickerDialog extends StatefulWidget {
  const _AliasPickerDialog({
    required this.aliases,
    required this.onAliasSelected,
    required this.onAliasesChanged,
  });

  final List<String> aliases;
  final ValueChanged<String> onAliasSelected;
  final VoidCallback onAliasesChanged;

  @override
  State<_AliasPickerDialog> createState() => _AliasPickerDialogState();
}

class _AliasPickerDialogState extends State<_AliasPickerDialog> {
  late final ValueNotifier<List<String>> _aliasNotifier =
      ValueNotifier<List<String>>(List.from(widget.aliases));

  @override
  void dispose() {
    _aliasNotifier.dispose();
    super.dispose();
  }

  void _confirmDelete(int index) {
    KazumiDialog.show(
      builder: (context) => AlertDialog(
        title: const Text('删除确认'),
        content: const Text('删除后无法恢复，确认要永久删除这个别名吗？'),
        actions: [
          TextButton(
            onPressed: KazumiDialog.dismiss,
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              KazumiDialog.dismiss();
              widget.aliases.removeAt(index);
              _aliasNotifier.value = List.from(widget.aliases);
              widget.onAliasesChanged();
              if (widget.aliases.isEmpty) {
                Navigator.of(this.context).pop();
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 560,
        child: ValueListenableBuilder<List<String>>(
          valueListenable: _aliasNotifier,
          builder: (context, aliasList, child) {
            return ListView(
              shrinkWrap: true,
              children: [
                for (var index = 0; index < aliasList.length; index++)
                  ListTile(
                    title: Text(aliasList[index]),
                    trailing: IconButton(
                      onPressed: () => _confirmDelete(index),
                      icon: const Icon(Icons.delete),
                    ),
                    onTap: () => widget.onAliasSelected(aliasList[index]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
