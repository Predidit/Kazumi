import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

class DanmakuShieldSettingsSheet extends StatefulWidget {
  const DanmakuShieldSettingsSheet({super.key});

  @override
  State<DanmakuShieldSettingsSheet> createState() =>
      _DanmakuShieldSettingsSheetState();
}

class _DanmakuShieldSettingsSheetState
    extends State<DanmakuShieldSettingsSheet> {
  final MyController myController = inject<MyController>();
  final TextEditingController textEditingController = TextEditingController();

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          MaterialBottomSheetHeader(
            title: '弹幕屏蔽',
            description: '使用关键词或正则表达式过滤弹幕',
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: materialBottomSheetContentPadding,
              children: [
                MaterialBottomSheetSection(
                  title: '添加屏蔽规则',
                  description: '以“/”开头和结尾将视作正则表达式，如“/\\d+/”表示屏蔽所有数字',
                  icon: Icons.add_circle_outline_rounded,
                  child: TextField(
                    controller: textEditingController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: '输入关键词或正则表达式',
                      suffixIcon: TextButton.icon(
                        onPressed: () {
                          myController.addShieldList(
                            textEditingController.text.trim(),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('添加'),
                      ),
                    ),
                    onSubmitted: (_) {
                      myController.addShieldList(
                        textEditingController.text.trim(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Observer(builder: (context) {
                  return MaterialBottomSheetSection(
                    title: '已添加${myController.shieldList.length}个关键词',
                    icon: Icons.shield_outlined,
                    child: Wrap(
                      runSpacing: 12,
                      spacing: 12,
                      children: myController.shieldList
                          .map(
                            (item) => Chip(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide.none,
                              label: Text(
                                item,
                                style: const TextStyle(fontSize: 14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              deleteButtonTooltipMessage: '',
                              onDeleted: () {
                                myController.removeShieldList(item);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
