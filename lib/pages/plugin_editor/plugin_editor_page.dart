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
  final TextEditingController searchImgController = TextEditingController();
  final TextEditingController searchResultController = TextEditingController();
  final TextEditingController chapterRoadsController = TextEditingController();
  final TextEditingController chapterItemsController = TextEditingController();
  final TextEditingController chapterResultController = TextEditingController();
  final TextEditingController chapterResultNameController =
      TextEditingController();
  final TextEditingController refererController = TextEditingController();
  // final TextEditingController cookieController = TextEditingController();
  // final TextEditingController htmlIdentifierController =
  //     TextEditingController();

  final Map<String, TagParser> _editedTags = {};
  final TextEditingController _tagKeyController = TextEditingController();
  final TextEditingController _tagUrlController = TextEditingController();
  final TextEditingController _tagXpathController = TextEditingController();
  bool _tagShow = false;

  bool muliSources = true;
  bool useWebview = true;
  bool useNativePlayer = true;
  // bool reloadWithWeb = true;
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
    searchImgController.text = plugin.searchImg;
    searchResultController.text = plugin.searchResult;
    chapterRoadsController.text = plugin.chapterRoads;
    chapterItemsController.text = plugin.chapterItems;
    chapterResultController.text = plugin.chapterResult;
    chapterResultNameController.text = plugin.chapterResultName;
    refererController.text = plugin.referer;
    // cookieController.text = plugin.cookie;
    // htmlIdentifierController.text = plugin.htmlIdentifier;
    muliSources = plugin.muliSources;
    useWebview = plugin.useWebview;
    useNativePlayer = plugin.useNativePlayer;
    // reloadWithWeb = plugin.reloadWithWeb;
    usePost = plugin.usePost;
    useLegacyParser = plugin.useLegacyParser;
    _editedTags.addAll(plugin.tags);
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
                  controller: searchImgController,
                  decoration: const InputDecoration(
                      labelText: 'SearchImg', border: OutlineInputBorder()),
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
                  controller: chapterItemsController,
                  decoration: const InputDecoration(
                      labelText: 'ChapterItems', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: chapterResultController,
                  decoration: const InputDecoration(
                      labelText: 'ChapterResult', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: chapterResultNameController,
                  decoration: const InputDecoration(
                      labelText: 'ChapterResultName',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                ExpansionTile(
                  title: const Text('标签管理'),
                  children: [
                    const SizedBox(height: 10),
                    _buildTagEditor(),
                    const SizedBox(height: 10),
                    _buildTagList(),
                  ],
                ),
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
                    // const SizedBox(height: 20),
                    // TextField(
                    //   controller: cookieController,
                    //   decoration: const InputDecoration(
                    //       labelText: 'cookie', border: OutlineInputBorder()),
                    // ),
                    // const SizedBox(height: 20),
                    // SwitchListTile(
                    //   title: const Text('webview'),
                    //   subtitle: const Text('使用webview监听获取html'),
                    //   value: reloadWithWeb,
                    //   onChanged: (bool value) {
                    //     setState(() {
                    //       reloadWithWeb = value;
                    //     });
                    //   },
                    // ),
                    // const SizedBox(height: 20),
                    // TextField(
                    //   controller: htmlIdentifierController,
                    //   decoration: const InputDecoration(
                    //       labelText: 'htmlIdentifier',
                    //       border: OutlineInputBorder()),
                    // ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.save),
        onPressed: () async {
          plugin.api = apiController.text;
          plugin.type = typeController.text;
          plugin.name = nameController.text;
          plugin.version = versionController.text;
          plugin.userAgent = userAgentController.text;
          // plugin.cookie = cookieController.text;
          plugin.baseUrl = baseURLController.text;
          plugin.searchURL = searchURLController.text;
          plugin.searchList = searchListController.text;
          plugin.searchName = searchNameController.text;
          plugin.searchImg = searchImgController.text;
          plugin.searchResult = searchResultController.text;
          plugin.chapterRoads = chapterRoadsController.text;
          plugin.chapterItems = chapterItemsController.text;
          plugin.chapterResult = chapterResultController.text;
          plugin.chapterResultName = chapterResultNameController.text;
          plugin.muliSources = muliSources;
          plugin.useWebview = useWebview;
          plugin.useNativePlayer = useNativePlayer;
          // plugin.reloadWithWeb = reloadWithWeb;
          plugin.usePost = usePost;
          plugin.useLegacyParser = useLegacyParser;
          plugin.referer = refererController.text;
          plugin.tags.clear();
          plugin.tags.addAll(_editedTags);
          // plugin.htmlIdentifier = htmlIdentifierController.text;
          pluginsController.updatePlugin(plugin);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildTagEditor() {
    return Column(
        children: [
          TextField(
            controller: _tagKeyController,
            decoration: const InputDecoration(
                labelText: 'key', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _tagUrlController,
            decoration: const InputDecoration(
                labelText: 'Url', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _tagXpathController,
            decoration: const InputDecoration(
                labelText: 'xpath', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // 原来的SwitchListTile拆解
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('show'),
                    Text('展示标签信息在搜索页面'),
                  ],
                ),
              ),
              Switch(
                value: _tagShow,
                onChanged: (bool value) {
                  setState(() {
                    _tagShow = value;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (_tagKeyController.text.isNotEmpty &&
                      _tagUrlController.text.isNotEmpty &&
                      _tagXpathController.text.isNotEmpty) {
                    setState(() {
                      _editedTags[_tagKeyController.text] = TagParser(
                          url: _tagUrlController.text,
                          xpath: _tagXpathController.text,
                          show: _tagShow);
                      _tagKeyController.clear();
                      _tagUrlController.clear();
                      _tagXpathController.clear();
                      _tagShow = false;
                    });
                  }
                },
              ),
            ],
          )
        ],
      );
  }

  // 修改 _buildTagList 方法
  Widget _buildTagList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView(
        shrinkWrap: true,
        children: _editedTags.entries
            .map((entry) => ListTile(
                  title: Text(
                      '${entry.key}: { url:${entry.value.url}, xpath:${entry.value.xpath}, show:${entry.value.show} }'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showEditTagDialog(entry.key, entry.value),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() => _editedTags.remove(entry.key));
                        },
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

// 添加新的编辑标签对话框方法
  void _showEditTagDialog(String oldKey, TagParser oldValue) {
    final TextEditingController keyController =
    TextEditingController(text: oldKey);
    final TextEditingController urlController =
    TextEditingController(text: oldValue.url);
    final TextEditingController xpathController =
    TextEditingController(text: oldValue.xpath);

    // 将 show 变量移到 StatefulBuilder 内部管理
    bool show = oldValue.show;

    showDialog(
      context: context,
      builder: (context) {
        // 使用 StatefulBuilder 来管理对话框内部的状态
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('编辑tag'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: keyController,
                    decoration: const InputDecoration(
                        labelText: 'key', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                        labelText: 'Url', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: xpathController,
                    decoration: const InputDecoration(
                        labelText: 'xpath', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('show'),
                    subtitle: const Text('展示标签信息在搜索页面'),
                    value: show,
                    onChanged: (bool value) {
                      // 使用 setDialogState 而不是 setState
                      setDialogState(() {
                        show = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    final newKey = keyController.text.trim();
                    final newValue = TagParser(
                        url: urlController.text.trim(),
                        xpath: xpathController.text.trim(),
                        show: show); // 使用更新后的 show 值

                    if (newKey.isNotEmpty &&
                        newValue.url.isNotEmpty &&
                        newValue.xpath.isNotEmpty) {
                      // 使用外部组件的 setState 来更新主界面的状态
                      setState(() {
                        // 处理键修改的情况
                        if (newKey != oldKey) {
                          _editedTags.remove(oldKey);
                        }
                        _editedTags[newKey] = newValue;
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
