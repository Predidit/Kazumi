import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:card_settings_ui/tile/settings_tile_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/anti_crawler_config.dart';
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
  bool adBlocker = false;

  // AntiCrawler fields
  final TextEditingController captchaImageController = TextEditingController();
  final TextEditingController captchaInputController = TextEditingController();
  final TextEditingController captchaButtonController = TextEditingController();
  final TextEditingController captchaDetectValueController =
      TextEditingController();
  final TextEditingController captchaScriptController = TextEditingController();
  bool antiCrawlerEnabled = false;
  int captchaType = CaptchaType.imageCaptcha;
  int captchaDetectType = CaptchaDetectType.xpath;
  final MenuController captchaTypeMenuController = MenuController();
  final MenuController captchaDetectTypeMenuController = MenuController();

  static const Map<int, String> _captchaTypeMap = {
    CaptchaType.imageCaptcha: 'Image captcha',
    CaptchaType.autoClickButton: 'Auto-click button',
    CaptchaType.customJavaScript: 'Custom JS verification',
  };

  static const Map<int, String> _captchaDetectTypeMap = {
    CaptchaDetectType.xpath: 'XPath',
    CaptchaDetectType.text: 'Text',
    CaptchaDetectType.regex: 'Regex',
  };

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
    adBlocker = plugin.adBlocker;
    antiCrawlerEnabled = plugin.antiCrawlerConfig.enabled;
    captchaType = plugin.antiCrawlerConfig.captchaType;
    captchaImageController.text = plugin.antiCrawlerConfig.captchaImage;
    captchaInputController.text = plugin.antiCrawlerConfig.captchaInput;
    captchaButtonController.text = plugin.antiCrawlerConfig.captchaButton;
    captchaDetectType = plugin.antiCrawlerConfig.captchaDetectType;
    captchaDetectValueController.text =
        plugin.antiCrawlerConfig.captchaDetectValue;
    captchaScriptController.text = plugin.antiCrawlerConfig.captchaScript;
  }

  @override
  void dispose() {
    apiController.dispose();
    typeController.dispose();
    nameController.dispose();
    versionController.dispose();
    userAgentController.dispose();
    baseURLController.dispose();
    searchURLController.dispose();
    searchListController.dispose();
    searchNameController.dispose();
    searchResultController.dispose();
    chapterRoadsController.dispose();
    chapterResultController.dispose();
    refererController.dispose();
    captchaImageController.dispose();
    captchaInputController.dispose();
    captchaButtonController.dispose();
    captchaDetectValueController.dispose();
    captchaScriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Plugin plugin = Modular.args.data as Plugin;
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return Scaffold(
      appBar: const SysAppBar(
        title: Text('Rule editor'),
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
                  title: const Text('Advanced options'),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                  children: [
                    SettingsSection(
                      title: Text('Behavior settings',
                          style: TextStyle(fontFamily: fontFamily)),
                      tiles: [
                        SettingsTile.switchTile(
                          title: Text('Simple parsing',
                              style: TextStyle(fontFamily: fontFamily)),
                          description: Text('Use the simple parser instead of the modern parser',
                              style: TextStyle(fontFamily: fontFamily)),
                          initialValue: useLegacyParser,
                          onToggle: (v) => setState(
                              () => useLegacyParser = v ?? !useLegacyParser),
                        ),
                        SettingsTile.switchTile(
                          title: Text('POST',
                              style: TextStyle(fontFamily: fontFamily)),
                          description: Text('Use POST instead of GET for searching',
                              style: TextStyle(fontFamily: fontFamily)),
                          initialValue: usePost,
                          onToggle: (v) =>
                              setState(() => usePost = v ?? !usePost),
                        ),
                        SettingsTile.switchTile(
                          title: Text('Built-in player',
                              style: TextStyle(fontFamily: fontFamily)),
                          description: Text('Play videos with the built-in player',
                              style: TextStyle(fontFamily: fontFamily)),
                          initialValue: useNativePlayer,
                          onToggle: (v) => setState(
                              () => useNativePlayer = v ?? !useNativePlayer),
                        ),
                        SettingsTile.switchTile(
                          title: Text('Ad filtering',
                              style: TextStyle(fontFamily: fontFamily)),
                          description: Text('Enable HLS ad filtering',
                              style: TextStyle(fontFamily: fontFamily)),
                          initialValue: adBlocker,
                          onToggle: (v) =>
                              setState(() => adBlocker = v ?? !adBlocker),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: Text('Network settings',
                          style: TextStyle(fontFamily: fontFamily)),
                      tiles: [
                        CustomSettingsTile(
                          child: (info) => _buildTextFieldTile(
                            context,
                            info,
                            controller: userAgentController,
                            label: 'UserAgent',
                          ),
                        ),
                        CustomSettingsTile(
                          child: (info) => _buildTextFieldTile(
                            context,
                            info,
                            controller: refererController,
                            label: 'Referer',
                          ),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: Text('Anti-anti-crawler configuration',
                          style: TextStyle(fontFamily: fontFamily)),
                      tiles: [
                        SettingsTile.switchTile(
                          title: Text('Enable anti-anti-crawler',
                              style: TextStyle(fontFamily: fontFamily)),
                          description: Text('Show a captcha verification button instead of retry when search fails',
                              style: TextStyle(fontFamily: fontFamily)),
                          initialValue: antiCrawlerEnabled,
                          onToggle: (v) => setState(() =>
                              antiCrawlerEnabled = v ?? !antiCrawlerEnabled),
                        ),
                        if (antiCrawlerEnabled) ...[
                          SettingsTile.navigation(
                            onPressed: (_) {
                              if (captchaTypeMenuController.isOpen) {
                                captchaTypeMenuController.close();
                              } else {
                                captchaTypeMenuController.open();
                              }
                            },
                            title: Text('Verification type',
                                style: TextStyle(fontFamily: fontFamily)),
                            description: Text(
                              switch (captchaType) {
                                CaptchaType.imageCaptcha =>
                                  'Image captcha (shows a captcha image for manual input)',
                                CaptchaType.autoClickButton =>
                                  'Auto-click verification button (clicks automatically when the button is detected)',
                                CaptchaType.customJavaScript =>
                                  'Custom JS verification (runs the rule script after the page loads)',
                                _ => 'Unknown verification type',
                              },
                              style: TextStyle(fontFamily: fontFamily),
                            ),
                            value: MenuAnchor(
                              consumeOutsideTap: true,
                              controller: captchaTypeMenuController,
                              builder: (_, __, ___) => Text(
                                _captchaTypeMap[captchaType] ?? 'Unknown',
                                style: TextStyle(fontFamily: fontFamily),
                              ),
                              menuChildren: [
                                for (final entry in _captchaTypeMap.entries)
                                  MenuItemButton(
                                    requestFocusOnHover: false,
                                    onPressed: () =>
                                        setState(() => captchaType = entry.key),
                                    child: Container(
                                      height: 48,
                                      constraints:
                                          const BoxConstraints(minWidth: 160),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          entry.value,
                                          style: TextStyle(
                                            color: entry.key == captchaType
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : null,
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SettingsTile.navigation(
                            onPressed: (_) {
                              if (captchaDetectTypeMenuController.isOpen) {
                                captchaDetectTypeMenuController.close();
                              } else {
                                captchaDetectTypeMenuController.open();
                              }
                            },
                            title: Text('Verification page detection method',
                                style: TextStyle(fontFamily: fontFamily)),
                            description: Text('Prefer this marker to determine whether the search response is a verification page',
                                style: TextStyle(fontFamily: fontFamily)),
                            value: MenuAnchor(
                              consumeOutsideTap: true,
                              controller: captchaDetectTypeMenuController,
                              builder: (_, __, ___) => Text(
                                _captchaDetectTypeMap[captchaDetectType] ??
                                    'Unknown',
                                style: TextStyle(fontFamily: fontFamily),
                              ),
                              menuChildren: [
                                for (final entry
                                    in _captchaDetectTypeMap.entries)
                                  MenuItemButton(
                                    requestFocusOnHover: false,
                                    onPressed: () => setState(
                                        () => captchaDetectType = entry.key),
                                    child: Container(
                                      height: 48,
                                      constraints:
                                          const BoxConstraints(minWidth: 160),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          entry.value,
                                          style: TextStyle(
                                            color:
                                                entry.key == captchaDetectType
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : null,
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          CustomSettingsTile(
                            child: (info) => _buildTextFieldTile(
                              context,
                              info,
                              controller: captchaDetectValueController,
                              label: 'CaptchaDetectValue',
                              hint: captchaDetectType == CaptchaDetectType.text
                                  ? 'Authentication'
                                  : captchaDetectType == CaptchaDetectType.regex
                                      ? 'Authentication|smart_verify'
                                      : '//button[@id="verify"]',
                              helper: 'When left empty, fall back to the old image or button XPath detection',
                            ),
                          ),
                          if (captchaType == CaptchaType.imageCaptcha) ...[
                            CustomSettingsTile(
                              child: (info) => _buildTextFieldTile(
                                context,
                                info,
                                controller: captchaImageController,
                                label: 'CaptchaImage (XPath)',
                                hint: '//img[@class="captcha"]',
                                helper: 'XPath of the captcha image element',
                              ),
                            ),
                            CustomSettingsTile(
                              child: (info) => _buildTextFieldTile(
                                context,
                                info,
                                controller: captchaInputController,
                                label: 'CaptchaInput (XPath)',
                                hint: '//input[@name="captcha"]',
                                helper: 'XPath of the captcha input element',
                              ),
                            ),
                          ],
                          if (captchaType != CaptchaType.customJavaScript)
                            CustomSettingsTile(
                              child: (info) => _buildTextFieldTile(
                                context,
                                info,
                                controller: captchaButtonController,
                                label: captchaType == CaptchaType.imageCaptcha
                                    ? 'CaptchaButton (XPath)'
                                    : 'VerifyButton (XPath)',
                                hint: '//button[@type="submit"]',
                                helper: captchaType == CaptchaType.imageCaptcha
                                    ? 'XPath of the verification submit button element'
                                    : 'XPath of the verification button element, clicked automatically when detected',
                              ),
                            ),
                          if (captchaType == CaptchaType.customJavaScript)
                            CustomSettingsTile(
                              child: (info) => _buildTextFieldTile(
                                context,
                                info,
                                controller: captchaScriptController,
                                label: 'CaptchaScript (JavaScript)',
                                hint:
                                    'KazumiCaptcha.log("ready"); KazumiCaptcha.done();',
                                helper:
                                    'You can call KazumiCaptcha.log/clicked/done/fail',
                                maxLines: 8,
                              ),
                            ),
                        ],
                      ],
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
                  adBlocker: adBlocker,
                  userAgent: userAgentController.text,
                  baseUrl: baseURLController.text,
                  searchURL: searchURLController.text,
                  searchList: searchListController.text,
                  searchName: searchNameController.text,
                  searchResult: searchResultController.text,
                  chapterRoads: chapterRoadsController.text,
                  chapterResult: chapterResultController.text,
                  referer: refererController.text,
                  antiCrawlerConfig: AntiCrawlerConfig(
                    enabled: antiCrawlerEnabled,
                    captchaType: captchaType,
                    captchaImage: captchaImageController.text,
                    captchaInput: captchaInputController.text,
                    captchaButton: captchaButtonController.text,
                    captchaDetectType: captchaDetectType,
                    captchaDetectValue: captchaDetectValueController.text,
                    captchaScript: captchaScriptController.text,
                  ));
              Modular.to
                  .pushNamed('/settings/plugin/test', arguments: pluginText);
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
              plugin.adBlocker = adBlocker;
              plugin.referer = refererController.text;
              plugin.antiCrawlerConfig = AntiCrawlerConfig(
                enabled: antiCrawlerEnabled,
                captchaType: captchaType,
                captchaImage: captchaImageController.text,
                captchaInput: captchaInputController.text,
                captchaButton: captchaButtonController.text,
                captchaDetectType: captchaDetectType,
                captchaDetectValue: captchaDetectValueController.text,
                captchaScript: captchaScriptController.text,
              );
              pluginsController.updatePlugin(plugin);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldTile(
    BuildContext context,
    SettingsTileInfo info, {
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    int maxLines = 1,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(info.isTopTile ? 20 : 3),
            bottom: Radius.circular(info.isBottomTile ? 20 : 3),
          ),
          child: Material(
            color: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).colorScheme.surfaceContainerLowest
                : Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: controller,
                maxLines: maxLines,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  helperText: helper,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ),
        if (info.needDivider) const SizedBox(height: 2),
      ],
    );
  }
}
