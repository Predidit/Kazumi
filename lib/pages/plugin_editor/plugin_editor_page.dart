import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class PluginEditorPage extends StatefulWidget {
  const PluginEditorPage({
    super.key,
  });

  @override
  State<PluginEditorPage> createState() => _PluginEditorPageState();
}

class _PluginEditorPageState extends State<PluginEditorPage> {
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final TextEditingController apiController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController versionController = TextEditingController();
  final TextEditingController userAgentController = TextEditingController();
  final TextEditingController baseURLController = TextEditingController();
  final TextEditingController searchURLController = TextEditingController();
  final TextEditingController searchListController = TextEditingController();
  final TextEditingController searchNameController = TextEditingController();
  final TextEditingController searchResultController = TextEditingController();
  final TextEditingController chapterRoadsController = TextEditingController();
  final TextEditingController chapterResultController = TextEditingController();
  final TextEditingController refererController = TextEditingController();
  bool muliSources = true;
  bool useWebview = true;
  bool useNativePlayer = false;
  bool usePost = false;
  bool useLegacyParser = false;

  @override
  void initState() {
    super.initState();
    final Plugin plugin = Modular.args.data as Plugin;
    apiController.text = plugin.api;
    typeController.text = plugin.type;
    nameController.text = plugin.name;
    versionController.text = plugin.version;
    userAgentController.text = plugin.userAgent;
    baseURLController.text = plugin.baseUrl;
    searchURLController.text = plugin.searchURL;
    searchListController.text = plugin.searchList;
    searchNameController.text = plugin.searchName;
    searchResultController.text = plugin.searchResult;
    chapterRoadsController.text = plugin.chapterRoads;
    chapterResultController.text = plugin.chapterResult;
    refererController.text = plugin.referer;
    muliSources = plugin.muliSources;
    useWebview = plugin.useWebview;
    useNativePlayer = plugin.useNativePlayer;
    usePost = plugin.usePost;
    useLegacyParser = plugin.useLegacyParser;
  }

  @override
  Widget build(BuildContext context) {
    final Plugin plugin = Modular.args.data as Plugin;

    return Scaffold(
      appBar: const SysAppBar(
        title: Text('规则编辑器'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('内置播放器'),
              subtitle: const Text('调试时保持禁用'),
              value: useNativePlayer,
              onChanged: (bool value) {
                setState(() {
                  useNativePlayer = value;
                });
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: versionController,
              decoration: const InputDecoration(labelText: 'Version'),
            ),
            TextField(
              controller: baseURLController,
              decoration: const InputDecoration(labelText: 'BaseURL'),
            ),
            TextField(
              controller: searchURLController,
              decoration: const InputDecoration(labelText: 'SearchURL'),
            ),
            TextField(
              controller: searchListController,
              decoration: const InputDecoration(labelText: 'SearchList'),
            ),
            TextField(
              controller: searchNameController,
              decoration: const InputDecoration(labelText: 'SearchName'),
            ),
            TextField(
              controller: searchResultController,
              decoration: const InputDecoration(labelText: 'SearchResult'),
            ),
            TextField(
              controller: chapterRoadsController,
              decoration: const InputDecoration(labelText: 'ChapterRoads'),
            ),
            TextField(
              controller: chapterResultController,
              decoration: const InputDecoration(labelText: 'ChapterResult'),
            ),
            const SizedBox(height: 20),
            ExpansionTile(
              title: const Text('高级选项'),
              children: [
                SwitchListTile(
                  title: const Text('简易解析'),
                  subtitle: const Text('使用简易解析器而不是现代解析器'),
                  value: useLegacyParser,
                  onChanged: (bool value) {
                    setState(() {
                      useLegacyParser = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('POST'),
                  subtitle: const Text('使用POST而不是GET进行检索'),
                  value: usePost,
                  onChanged: (bool value) {
                    setState(() {
                      usePost = value;
                    });
                  },
                ),
                TextField(
                  controller: userAgentController,
                  decoration: const InputDecoration(labelText: 'UserAgent'),
                ),
                TextField(
                  controller: refererController,
                  decoration: const InputDecoration(labelText: 'Referer'),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.save),
        onPressed: () async {
          plugin.api = apiController.text;
          plugin.type = apiController.text;
          plugin.name = nameController.text;
          plugin.version = versionController.text;
          plugin.userAgent = userAgentController.text;
          plugin.baseUrl = baseURLController.text;
          plugin.searchURL = searchURLController.text;
          plugin.searchList = searchListController.text;
          plugin.searchName = searchNameController.text;
          plugin.searchResult = searchResultController.text;
          plugin.chapterRoads = chapterRoadsController.text;
          plugin.chapterResult = chapterResultController.text;
          plugin.muliSources = muliSources;
          plugin.useWebview = useWebview;
          plugin.useNativePlayer = useNativePlayer;
          plugin.usePost = usePost;
          plugin.useLegacyParser = useLegacyParser;
          plugin.referer = refererController.text;
          await pluginsController.savePluginToJsonFile(plugin);
          await pluginsController.loadPlugins();
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
