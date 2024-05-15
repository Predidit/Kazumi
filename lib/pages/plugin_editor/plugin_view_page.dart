import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

class PluginViewPage extends StatefulWidget {
  const PluginViewPage({super.key});

  @override
  State<PluginViewPage> createState() => _PluginViewPageState();
}

class _PluginViewPageState extends State<PluginViewPage> {
  final PluginsController pluginsController = Modular.get<PluginsController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件管理'),
      ),
      body: ListView.builder(
        itemCount: pluginsController.pluginList.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              title: Text(
                pluginsController.pluginList[index].name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Version: ${pluginsController.pluginList[index].version}',
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (String result) {
                  if (result == 'Delete') {
                    setState(() {
                      // 删除待完成
                      // pluginsController.pluginList.removeAt(index);
                    });
                  } else if (result == 'Edit') {
                    // 编辑待完成
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'Edit',
                    child: Text('编辑'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'Delete',
                    child: Text('删除'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            // 新建插件
          },
          child: const Icon(Icons.add),
        ),
    );
  }
}
