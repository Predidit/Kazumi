import 'package:flutter/material.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class DanmakuShieldSettings extends StatefulWidget {
  const DanmakuShieldSettings({
    super.key,
    this.isSidebar = false,
  });

  final bool isSidebar;

  @override
  State<DanmakuShieldSettings> createState() => _DanmakuShieldSettingsState();
}

class _DanmakuShieldSettingsState extends State<DanmakuShieldSettings> {
  final MyController myController = Modular.get<MyController>();
  final TextEditingController textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {

    return Scaffold(
        appBar: widget.isSidebar
          ? null
          : SysAppBar(
              title: Text(
                "弹幕屏蔽",
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: textEditingController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color:  Colors.blue),
              ),
              hintText: "输入关键词或正则表达式",
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              suffixIcon: TextButton.icon(
                onPressed: () {
                  myController.addShieldList(
                    textEditingController.text.trim(),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
                icon: const Icon(Icons.add),
                label: const Text("添加"),
              ),
            ),
            onSubmitted: (_) {
              myController.addShieldList(
                textEditingController.text.trim(),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            '以"/"开头和结尾将视作正则表达式, 如"/\\d+/"表示屏蔽所有数字',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          Observer(builder: (context) {
            return Text(
              "已添加${myController.shieldList.length}个关键词",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            );
          }),
          const SizedBox(height: 12),
          Observer(builder: (context) {
            return Wrap(
              runSpacing: 12,
              spacing: 12,
              children: myController.shieldList
                  .map(
                    (item) => Chip(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide.none,
                      label: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      deleteIcon: Icon(
                        Icons.close,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      deleteButtonTooltipMessage: '',
                      onDeleted: () {
                        myController.removeShieldList(item);
                      },
                    ),
                  )
                  .toList(),
            );
          })
        ],
      ),
    );
  }
}
