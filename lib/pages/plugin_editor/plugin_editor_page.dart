import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

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
  bool muliSources = true;
  bool useWebview = true;
  bool useNativePlayer = false;

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
    muliSources = plugin.muliSources;
    useWebview = plugin.useWebview;
    useNativePlayer = plugin.useNativePlayer;
  }

  @override
  Widget build(BuildContext context) {
    final Plugin plugin = Modular.args.data as Plugin;

    return Scaffold(
      appBar: AppBar(
        title: Text('规则编辑器'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: Text('内置播放器'),
              value: useNativePlayer,
              onChanged: (bool value) {
                setState(() {
                  useNativePlayer = value;
                });
              },
            ),
            SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: versionController,
              decoration: InputDecoration(labelText: 'Version'),
            ),
            TextField(
              controller: baseURLController,
              decoration: InputDecoration(labelText: 'BaseURL'),
            ),
            TextField(
              controller: searchURLController,
              decoration: InputDecoration(labelText: 'SearchURL'),
            ),
            TextField(
              controller: searchListController,
              decoration: InputDecoration(labelText: 'SearchList'),
            ),
            TextField(
              controller: searchNameController,
              decoration: InputDecoration(labelText: 'SearchName'),
            ),
            TextField(
              controller: searchResultController,
              decoration: InputDecoration(labelText: 'SearchResult'),
            ),
            TextField(
              controller: chapterRoadsController,
              decoration: InputDecoration(labelText: 'ChapterRoads'),
            ),
            TextField(
              controller: chapterResultController,
              decoration: InputDecoration(labelText: 'ChapterResult'),
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
          await pluginsController.savePluginToJsonFile(plugin);
          await pluginsController.loadPlugins();
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
