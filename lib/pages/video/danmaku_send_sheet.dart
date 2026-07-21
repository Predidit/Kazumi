import 'package:flutter/material.dart';

Future<String?> showMobileDanmakuInputSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    shape: const BeveledRectangleBorder(),
    isScrollControlled: true,
    builder: (context) => const _MobileDanmakuInputSheet(),
  );
}

class _MobileDanmakuInputSheet extends StatefulWidget {
  const _MobileDanmakuInputSheet();

  @override
  State<_MobileDanmakuInputSheet> createState() =>
      _MobileDanmakuInputSheetState();
}

class _MobileDanmakuInputSheetState extends State<_MobileDanmakuInputSheet> {
  String _danmakuText = '';

  void _submit([String? value]) {
    Navigator.of(context).pop(value ?? _danmakuText);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 34),
              child: TextField(
                style: const TextStyle(fontSize: 15),
                autofocus: true,
                textInputAction: TextInputAction.send,
                textAlignVertical: TextAlignVertical.center,
                onChanged: (value) => _danmakuText = value,
                onSubmitted: _submit,
                decoration: const InputDecoration(
                  filled: true,
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  hintText: '发个友善的弹幕见证当下',
                  hintStyle: TextStyle(fontSize: 14),
                  alignLabelWithHint: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '发送',
            onPressed: _submit,
            icon: Icon(
              Icons.send_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
