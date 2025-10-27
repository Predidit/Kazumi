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
  bool useNativePlayer = true;
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
        child: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: versionController,
                  decoration: const InputDecoration(
                      labelText: 'Version', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: baseURLController,
                  decoration: const InputDecoration(
                      labelText: 'BaseURL', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: searchURLController,
                  decoration: const InputDecoration(
                      labelText: 'SearchURL', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: searchListController,
                  decoration: const InputDecoration(
                      labelText: 'SearchList', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: searchNameController,
                  decoration: const InputDecoration(
                      labelText: 'SearchName', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: searchResultController,
                  decoration: const InputDecoration(
                      labelText: 'SearchResult', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: chapterRoadsController,
                  decoration: const InputDecoration(
                      labelText: 'ChapterRoads', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: chapterResultController,
                  decoration: const InputDecoration(
                      labelText: 'ChapterResult', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                ExpansionTile(
                  title: const Text('高级选项'),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
                    SwitchListTile(
                      title: const Text('内置播放器'),
                      subtitle: const Text('使用内置播放器播放视频'),
                      value: useNativePlayer,
                      onChanged: (bool value) {
                        setState(() {
                          useNativePlayer = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: userAgentController,
                      decoration: const InputDecoration(
                          labelText: 'UserAgent', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: refererController,
                      decoration: const InputDecoration(
                          labelText: 'Referer', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: null,
            child: const Icon(Icons.bug_report),
            onPressed: () async {
              Plugin pluginText = Plugin(
                  api: apiController.text,
                  type: typeController.text,
                  name: nameController.text,
                  version: versionController.text,
                  muliSources: muliSources,
                  useWebview: useWebview,
                  useNativePlayer: useNativePlayer,
                  usePost: usePost,
                  useLegacyParser: useLegacyParser,
                  userAgent: userAgentController.text,
                  baseUrl: baseURLController.text,
                  searchURL: searchURLController.text,
                  searchList: searchListController.text,
                  searchName: searchNameController.text,
                  searchResult: searchResultController.text,
                  chapterRoads: chapterRoadsController.text,
                  chapterResult: chapterResultController.text,
                  referer: refererController.text);
              Modular.to.pushNamed('/settings/plugin/test', arguments: pluginText);
            },
          ),
          SizedBox(width: 15),
          FloatingActionButton(
            heroTag: null,
            child: const Icon(Icons.save),
            onPressed: () async {
              plugin.api = apiController.text;
              plugin.type = typeController.text;
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
              pluginsController.updatePlugin(plugin);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
