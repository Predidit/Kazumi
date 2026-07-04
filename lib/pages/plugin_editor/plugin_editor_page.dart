import 'dart:convert';

import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:card_settings_ui/tile/settings_tile_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/api_rule_config.dart';
import 'package:kazumi/plugins/anti_crawler_config.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/services/plugin/api_rule_engine.dart';

abstract final class _RuleEditorText {
  static const ruleName = '规则名称';
  static const ruleVersion = '规则版本';
  static const baseUrl = '基础地址（URL）';
  static const searchRuleType = '搜索规则类型';
  static const chapterRuleType = '选集规则类型';

  static const searchUrl = '搜索地址（URL）';
  static const searchListXPath = '搜索结果列表（XPath）';
  static const itemNameXPath = '条目名称（XPath）';
  static const itemLinkXPath = '条目链接（XPath）';
  static const roadListXPath = '播放线路列表（XPath）';
  static const episodeListXPath = '剧集列表（XPath）';

  static const searchMethod = '搜索请求方法';
  static const searchRequestUrl = '搜索请求地址（URL）';
  static const searchHeaders = '搜索请求头（JSON）';
  static const searchQuery = '搜索查询参数（JSON）';
  static const searchBodyType = '搜索请求体类型';
  static const searchBody = '搜索请求体（JSON）';
  static const searchListPath = '搜索结果列表路径（JSONPath）';
  static const itemNamePath = '条目名称路径（JSONPath，相对条目）';
  static const itemSourcePath = '条目来源路径（JSONPath，相对条目）';

  static const chapterMethod = '选集请求方法';
  static const chapterRequestUrl = '选集请求地址（URL）';
  static const chapterHeaders = '选集请求头（JSON）';
  static const chapterQuery = '选集查询参数（JSON）';
  static const chapterBodyType = '选集请求体类型';
  static const chapterBody = '选集请求体（JSON）';
  static const chapterResponseFormat = '选集响应格式';
  static const roadListPath = '播放线路列表路径（JSONPath，留空表示单线路）';
  static const roadNamePath = '线路名称路径（JSONPath，相对线路）';
  static const episodeListPath = '剧集列表路径（JSONPath，相对线路）';
  static const episodeNamePath = '剧集名称路径（JSONPath，相对剧集）';
  static const playbackEntryPath = '播放入口地址路径（JSONPath，使用播放页地址模板时可留空）';
  static const playbackEntryPathHelper = '从剧集对象读取交给 WebView 的地址，可以是播放页面或媒体直链。';
  static const roadNamesPath = '线路名称串路径（JSONPath）';
  static const roadEpisodesPath = '线路剧集串路径（JSONPath）';
  static const roadSeparator = '线路分隔符';
  static const episodeSeparator = '剧集分隔符';
  static const fieldSeparator = '名称与地址分隔符';
  static const responseVariables = '响应变量（JSON：变量名 → JSONPath）';
  static const playPageUrl = '播放页地址模板（URL，可选）';
  static const playPageQuery = '播放页查询参数（JSON）';

  static const userAgent = '用户代理（User-Agent）';
  static const userAgentHelper = '仅用于播放器和下载器。';
  static const referer = '播放请求来源（Referer）';
  static const refererHelper = '仅用于播放器和下载器。';

  static const captchaDetectValue = '验证页检测值';
  static const captchaDetectValueHelper = '留空时使用验证码图片或验证按钮的 XPath 进行检测。';
  static const captchaImage = '验证码图片（XPath）';
  static const captchaImageHelper = '填写验证码图片元素的 XPath。';
  static const captchaInput = '验证码输入框（XPath）';
  static const captchaInputHelper = '填写验证码输入框元素的 XPath。';
  static const captchaSubmitButton = '验证提交按钮（XPath）';
  static const captchaSubmitButtonHelper = '填写提交验证码按钮元素的 XPath。';
  static const verifyButton = '验证按钮（XPath）';
  static const verifyButtonHelper = '填写验证按钮元素的 XPath，检测到后将自动点击。';
  static const captchaScript = '验证脚本（JavaScript）';
  static const captchaScriptHelper =
      '可调用 KazumiCaptcha.log、clicked、done 和 fail。';
}

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
  final TextEditingController searchApiURLController = TextEditingController();
  final TextEditingController searchApiHeadersController =
      TextEditingController();
  final TextEditingController searchApiQueryController =
      TextEditingController();
  final TextEditingController searchApiBodyController = TextEditingController();
  final TextEditingController searchApiListPathController =
      TextEditingController();
  final TextEditingController searchApiNamePathController =
      TextEditingController();
  final TextEditingController searchApiSourcePathController =
      TextEditingController();
  final TextEditingController chapterApiURLController = TextEditingController();
  final TextEditingController chapterApiHeadersController =
      TextEditingController();
  final TextEditingController chapterApiQueryController =
      TextEditingController();
  final TextEditingController chapterApiBodyController =
      TextEditingController();
  final TextEditingController chapterApiRoadsPathController =
      TextEditingController();
  final TextEditingController chapterApiRoadNamePathController =
      TextEditingController();
  final TextEditingController chapterApiEpisodesPathController =
      TextEditingController();
  final TextEditingController chapterApiEpisodeNamePathController =
      TextEditingController();
  final TextEditingController chapterApiEpisodeURLPathController =
      TextEditingController();
  final TextEditingController chapterApiRoadNamesPathController =
      TextEditingController();
  final TextEditingController chapterApiRoadEpisodesPathController =
      TextEditingController();
  final TextEditingController chapterApiRoadSeparatorController =
      TextEditingController();
  final TextEditingController chapterApiEpisodeSeparatorController =
      TextEditingController();
  final TextEditingController chapterApiFieldSeparatorController =
      TextEditingController();
  final TextEditingController chapterApiVariablesController =
      TextEditingController();
  final TextEditingController chapterApiPageURLController =
      TextEditingController();
  final TextEditingController chapterApiPageQueryController =
      TextEditingController();
  String searchMode = RuleMode.xpath;
  String chapterMode = RuleMode.xpath;
  String searchApiMethod = 'GET';
  String searchApiBodyType = ApiBodyType.none;
  String chapterApiMethod = 'GET';
  String chapterApiBodyType = ApiBodyType.none;
  String chapterApiFormat = ApiChapterFormat.nested;
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
    CaptchaType.imageCaptcha: '图片验证码',
    CaptchaType.autoClickButton: '自动点击按钮',
    CaptchaType.customJavaScript: '自定义 JavaScript 验证',
  };

  static const Map<int, String> _captchaDetectTypeMap = {
    CaptchaDetectType.xpath: 'XPath',
    CaptchaDetectType.text: '文本',
    CaptchaDetectType.regex: '正则',
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
    searchMode = plugin.searchMode;
    chapterMode = plugin.chapterMode;
    searchApiMethod = plugin.searchApiConfig.request.method;
    searchApiBodyType = plugin.searchApiConfig.request.bodyType;
    searchApiURLController.text = plugin.searchApiConfig.request.url;
    searchApiHeadersController.text =
        _prettyJson(plugin.searchApiConfig.request.headers);
    searchApiQueryController.text =
        _prettyJson(plugin.searchApiConfig.request.query);
    searchApiBodyController.text =
        _prettyJson(plugin.searchApiConfig.request.body);
    searchApiListPathController.text = plugin.searchApiConfig.listPath;
    searchApiNamePathController.text = plugin.searchApiConfig.namePath;
    searchApiSourcePathController.text = plugin.searchApiConfig.sourcePath;
    chapterApiMethod = plugin.chapterApiConfig.request.method;
    chapterApiBodyType = plugin.chapterApiConfig.request.bodyType;
    chapterApiFormat = plugin.chapterApiConfig.format;
    chapterApiURLController.text = plugin.chapterApiConfig.request.url;
    chapterApiHeadersController.text =
        _prettyJson(plugin.chapterApiConfig.request.headers);
    chapterApiQueryController.text =
        _prettyJson(plugin.chapterApiConfig.request.query);
    chapterApiBodyController.text =
        _prettyJson(plugin.chapterApiConfig.request.body);
    chapterApiRoadsPathController.text = plugin.chapterApiConfig.roadsPath;
    chapterApiRoadNamePathController.text =
        plugin.chapterApiConfig.roadNamePath;
    chapterApiEpisodesPathController.text =
        plugin.chapterApiConfig.episodesPath;
    chapterApiEpisodeNamePathController.text =
        plugin.chapterApiConfig.episodeNamePath;
    chapterApiEpisodeURLPathController.text =
        plugin.chapterApiConfig.episodeUrlPath;
    chapterApiRoadNamesPathController.text =
        plugin.chapterApiConfig.roadNamesPath;
    chapterApiRoadEpisodesPathController.text =
        plugin.chapterApiConfig.roadEpisodesPath;
    chapterApiRoadSeparatorController.text =
        plugin.chapterApiConfig.roadSeparator;
    chapterApiEpisodeSeparatorController.text =
        plugin.chapterApiConfig.episodeSeparator;
    chapterApiFieldSeparatorController.text =
        plugin.chapterApiConfig.fieldSeparator;
    chapterApiVariablesController.text =
        _prettyJson(plugin.chapterApiConfig.variables);
    chapterApiPageURLController.text =
        plugin.chapterApiConfig.episodePage?.url ?? '';
    chapterApiPageQueryController.text =
        _prettyJson(plugin.chapterApiConfig.episodePage?.query);
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
    searchApiURLController.dispose();
    searchApiHeadersController.dispose();
    searchApiQueryController.dispose();
    searchApiBodyController.dispose();
    searchApiListPathController.dispose();
    searchApiNamePathController.dispose();
    searchApiSourcePathController.dispose();
    chapterApiURLController.dispose();
    chapterApiHeadersController.dispose();
    chapterApiQueryController.dispose();
    chapterApiBodyController.dispose();
    chapterApiRoadsPathController.dispose();
    chapterApiRoadNamePathController.dispose();
    chapterApiEpisodesPathController.dispose();
    chapterApiEpisodeNamePathController.dispose();
    chapterApiEpisodeURLPathController.dispose();
    chapterApiRoadNamesPathController.dispose();
    chapterApiRoadEpisodesPathController.dispose();
    chapterApiRoadSeparatorController.dispose();
    chapterApiEpisodeSeparatorController.dispose();
    chapterApiFieldSeparatorController.dispose();
    chapterApiVariablesController.dispose();
    chapterApiPageURLController.dispose();
    chapterApiPageQueryController.dispose();
    captchaImageController.dispose();
    captchaInputController.dispose();
    captchaButtonController.dispose();
    captchaDetectValueController.dispose();
    captchaScriptController.dispose();
    super.dispose();
  }

  static String _prettyJson(Object? value) {
    if (value == null) return '';
    if (value is Map && value.isEmpty) return '{}';
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

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
                      labelText: _RuleEditorText.ruleName,
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: versionController,
                  decoration: const InputDecoration(
                      labelText: _RuleEditorText.ruleVersion,
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: baseURLController,
                  decoration: const InputDecoration(
                      labelText: _RuleEditorText.baseUrl,
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: searchMode,
                  decoration: const InputDecoration(
                    labelText: _RuleEditorText.searchRuleType,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: RuleMode.xpath, child: Text('XPath')),
                    DropdownMenuItem(value: RuleMode.api, child: Text('API')),
                  ],
                  onChanged: (value) =>
                      setState(() => searchMode = value ?? RuleMode.xpath),
                ),
                const SizedBox(height: 20),
                if (searchMode == RuleMode.xpath)
                  ..._buildXPathSearchFields()
                else
                  ..._buildApiSearchFields(),
                DropdownButtonFormField<String>(
                  initialValue: chapterMode,
                  decoration: const InputDecoration(
                    labelText: _RuleEditorText.chapterRuleType,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: RuleMode.xpath, child: Text('XPath')),
                    DropdownMenuItem(value: RuleMode.api, child: Text('API')),
                  ],
                  onChanged: (value) =>
                      setState(() => chapterMode = value ?? RuleMode.xpath),
                ),
                const SizedBox(height: 20),
                if (chapterMode == RuleMode.xpath)
                  ..._buildXPathChapterFields()
                else
                  ..._buildApiChapterFields(),
                ExpansionTile(
                  title: const Text('高级选项'),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                  children: [
                    SettingsSection(
                      title: Text('行为设置',
                          style: TextStyle(fontFamily: fontFamily)),
                      tiles: [
                        SettingsTile.switchTile(
                          title: Text('简易解析',
                              style: TextStyle(fontFamily: fontFamily)),
                          description: Text('使用简易解析器而不是现代解析器',
                              style: TextStyle(fontFamily: fontFamily)),
                          initialValue: useLegacyParser,
                          onToggle: (v) => setState(
                              () => useLegacyParser = v ?? !useLegacyParser),
                        ),
                        SettingsTile.switchTile(
                          title: Text('内置播放器',
                              style: TextStyle(fontFamily: fontFamily)),
                          description: Text('使用内置播放器播放视频',
                              style: TextStyle(fontFamily: fontFamily)),
                          initialValue: useNativePlayer,
                          onToggle: (v) => setState(
                              () => useNativePlayer = v ?? !useNativePlayer),
                        ),
                        SettingsTile.switchTile(
                          title: Text('广告过滤',
                              style: TextStyle(fontFamily: fontFamily)),
                          description: Text('启用 HLS 广告过滤',
                              style: TextStyle(fontFamily: fontFamily)),
                          initialValue: adBlocker,
                          onToggle: (v) =>
                              setState(() => adBlocker = v ?? !adBlocker),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: Text('网络设置',
                          style: TextStyle(fontFamily: fontFamily)),
                      tiles: [
                        CustomSettingsTile(
                          child: (info) => _buildTextFieldTile(
                            context,
                            info,
                            controller: userAgentController,
                            label: _RuleEditorText.userAgent,
                            helper: _RuleEditorText.userAgentHelper,
                          ),
                        ),
                        CustomSettingsTile(
                          child: (info) => _buildTextFieldTile(
                            context,
                            info,
                            controller: refererController,
                            label: _RuleEditorText.referer,
                            helper: _RuleEditorText.refererHelper,
                          ),
                        ),
                      ],
                    ),
                    if (searchMode == RuleMode.xpath)
                      SettingsSection(
                        title: Text('反反爬虫配置',
                            style: TextStyle(fontFamily: fontFamily)),
                        tiles: [
                          SettingsTile.switchTile(
                            title: Text('启用反反爬虫',
                                style: TextStyle(fontFamily: fontFamily)),
                            description: Text('检索失败时显示验证码验证按钮而非重试',
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
                              title: Text('验证类型',
                                  style: TextStyle(fontFamily: fontFamily)),
                              description: Text(
                                switch (captchaType) {
                                  CaptchaType.imageCaptcha =>
                                    '图片验证码（展示验证码图片，用户手动输入）',
                                  CaptchaType.autoClickButton =>
                                    '自动点击验证按钮（检测到按钮后自动模拟点击）',
                                  CaptchaType.customJavaScript =>
                                    '自定义 JavaScript 验证（加载页面后执行规则脚本）',
                                  _ => '未知验证类型',
                                },
                                style: TextStyle(fontFamily: fontFamily),
                              ),
                              value: MenuAnchor(
                                consumeOutsideTap: true,
                                controller: captchaTypeMenuController,
                                builder: (_, __, ___) => Text(
                                  _captchaTypeMap[captchaType] ?? '未知',
                                  style: TextStyle(fontFamily: fontFamily),
                                ),
                                menuChildren: [
                                  for (final entry in _captchaTypeMap.entries)
                                    MenuItemButton(
                                      requestFocusOnHover: false,
                                      onPressed: () => setState(
                                          () => captchaType = entry.key),
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
                              title: Text('验证页检测方式',
                                  style: TextStyle(fontFamily: fontFamily)),
                              description: Text('优先使用该标记判断搜索响应是否为验证页',
                                  style: TextStyle(fontFamily: fontFamily)),
                              value: MenuAnchor(
                                consumeOutsideTap: true,
                                controller: captchaDetectTypeMenuController,
                                builder: (_, __, ___) => Text(
                                  _captchaDetectTypeMap[captchaDetectType] ??
                                      '未知',
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
                                label: _RuleEditorText.captchaDetectValue,
                                hint:
                                    captchaDetectType == CaptchaDetectType.text
                                        ? '身份验证'
                                        : captchaDetectType ==
                                                CaptchaDetectType.regex
                                            ? '身份验证|smart_verify'
                                            : '//button[@id="verify"]',
                                helper:
                                    _RuleEditorText.captchaDetectValueHelper,
                              ),
                            ),
                            if (captchaType == CaptchaType.imageCaptcha) ...[
                              CustomSettingsTile(
                                child: (info) => _buildTextFieldTile(
                                  context,
                                  info,
                                  controller: captchaImageController,
                                  label: _RuleEditorText.captchaImage,
                                  hint: '//img[@class="captcha"]',
                                  helper: _RuleEditorText.captchaImageHelper,
                                ),
                              ),
                              CustomSettingsTile(
                                child: (info) => _buildTextFieldTile(
                                  context,
                                  info,
                                  controller: captchaInputController,
                                  label: _RuleEditorText.captchaInput,
                                  hint: '//input[@name="captcha"]',
                                  helper: _RuleEditorText.captchaInputHelper,
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
                                      ? _RuleEditorText.captchaSubmitButton
                                      : _RuleEditorText.verifyButton,
                                  hint: '//button[@type="submit"]',
                                  helper:
                                      captchaType == CaptchaType.imageCaptcha
                                          ? _RuleEditorText
                                              .captchaSubmitButtonHelper
                                          : _RuleEditorText.verifyButtonHelper,
                                ),
                              ),
                            if (captchaType == CaptchaType.customJavaScript)
                              CustomSettingsTile(
                                child: (info) => _buildTextFieldTile(
                                  context,
                                  info,
                                  controller: captchaScriptController,
                                  label: _RuleEditorText.captchaScript,
                                  hint:
                                      'KazumiCaptcha.log("ready"); KazumiCaptcha.done();',
                                  helper: _RuleEditorText.captchaScriptHelper,
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
              try {
                final pluginText = _buildEditedPlugin();
                Modular.to
                    .pushNamed('/settings/plugin/test', arguments: pluginText);
              } catch (error) {
                _showEditorError(error);
              }
            },
          ),
          SizedBox(width: 15),
          FloatingActionButton(
            heroTag: null,
            child: const Icon(Icons.save),
            onPressed: () async {
              try {
                final editedPlugin = _buildEditedPlugin();
                pluginsController.updatePlugin(editedPlugin);
                Navigator.of(context).pop();
              } catch (error) {
                _showEditorError(error);
              }
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildXPathSearchFields() => [
        DropdownButtonFormField<String>(
          initialValue: usePost ? 'POST' : 'GET',
          decoration: const InputDecoration(
            labelText: _RuleEditorText.searchMethod,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'GET', child: Text('GET')),
            DropdownMenuItem(value: 'POST', child: Text('POST')),
          ],
          onChanged: (value) => setState(() => usePost = value == 'POST'),
        ),
        const SizedBox(height: 20),
        _editorField(searchURLController, _RuleEditorText.searchUrl),
        _editorField(searchListController, _RuleEditorText.searchListXPath),
        _editorField(searchNameController, _RuleEditorText.itemNameXPath),
        _editorField(searchResultController, _RuleEditorText.itemLinkXPath),
      ];

  List<Widget> _buildXPathChapterFields() => [
        _editorField(chapterRoadsController, _RuleEditorText.roadListXPath),
        _editorField(chapterResultController, _RuleEditorText.episodeListXPath),
      ];

  List<Widget> _buildApiSearchFields() => [
        DropdownButtonFormField<String>(
          initialValue: searchApiMethod,
          decoration: const InputDecoration(
            labelText: _RuleEditorText.searchMethod,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'GET', child: Text('GET')),
            DropdownMenuItem(value: 'POST', child: Text('POST')),
          ],
          onChanged: (value) =>
              setState(() => searchApiMethod = value ?? 'GET'),
        ),
        const SizedBox(height: 20),
        _editorField(
          searchApiURLController,
          _RuleEditorText.searchRequestUrl,
        ),
        _editorField(
          searchApiHeadersController,
          _RuleEditorText.searchHeaders,
          maxLines: 4,
        ),
        _editorField(
          searchApiQueryController,
          _RuleEditorText.searchQuery,
          maxLines: 4,
        ),
        DropdownButtonFormField<String>(
          initialValue: searchApiBodyType,
          decoration: const InputDecoration(
            labelText: _RuleEditorText.searchBodyType,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: ApiBodyType.none, child: Text('无')),
            DropdownMenuItem(value: ApiBodyType.json, child: Text('JSON')),
            DropdownMenuItem(value: ApiBodyType.form, child: Text('表单')),
          ],
          onChanged: (value) => setState(
            () => searchApiBodyType = value ?? ApiBodyType.none,
          ),
        ),
        const SizedBox(height: 20),
        if (searchApiBodyType != ApiBodyType.none)
          _editorField(
            searchApiBodyController,
            _RuleEditorText.searchBody,
            maxLines: 5,
          ),
        _editorField(
          searchApiListPathController,
          _RuleEditorText.searchListPath,
        ),
        _editorField(
          searchApiNamePathController,
          _RuleEditorText.itemNamePath,
        ),
        _editorField(
          searchApiSourcePathController,
          _RuleEditorText.itemSourcePath,
        ),
      ];

  List<Widget> _buildApiChapterFields() => [
        DropdownButtonFormField<String>(
          initialValue: chapterApiMethod,
          decoration: const InputDecoration(
            labelText: _RuleEditorText.chapterMethod,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'GET', child: Text('GET')),
            DropdownMenuItem(value: 'POST', child: Text('POST')),
          ],
          onChanged: (value) =>
              setState(() => chapterApiMethod = value ?? 'GET'),
        ),
        const SizedBox(height: 20),
        _editorField(
          chapterApiURLController,
          _RuleEditorText.chapterRequestUrl,
        ),
        _editorField(
          chapterApiHeadersController,
          _RuleEditorText.chapterHeaders,
          maxLines: 4,
        ),
        _editorField(
          chapterApiQueryController,
          _RuleEditorText.chapterQuery,
          maxLines: 4,
        ),
        DropdownButtonFormField<String>(
          initialValue: chapterApiBodyType,
          decoration: const InputDecoration(
            labelText: _RuleEditorText.chapterBodyType,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: ApiBodyType.none, child: Text('无')),
            DropdownMenuItem(value: ApiBodyType.json, child: Text('JSON')),
            DropdownMenuItem(value: ApiBodyType.form, child: Text('表单')),
          ],
          onChanged: (value) => setState(
            () => chapterApiBodyType = value ?? ApiBodyType.none,
          ),
        ),
        const SizedBox(height: 20),
        if (chapterApiBodyType != ApiBodyType.none)
          _editorField(
            chapterApiBodyController,
            _RuleEditorText.chapterBody,
            maxLines: 5,
          ),
        DropdownButtonFormField<String>(
          initialValue: chapterApiFormat,
          decoration: const InputDecoration(
            labelText: _RuleEditorText.chapterResponseFormat,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: ApiChapterFormat.nested,
              child: Text('嵌套 JSON'),
            ),
            DropdownMenuItem(
              value: ApiChapterFormat.delimited,
              child: Text('分隔字符串'),
            ),
          ],
          onChanged: (value) => setState(
            () => chapterApiFormat = value ?? ApiChapterFormat.nested,
          ),
        ),
        const SizedBox(height: 20),
        if (chapterApiFormat == ApiChapterFormat.nested) ...[
          _editorField(
            chapterApiRoadsPathController,
            _RuleEditorText.roadListPath,
          ),
          _editorField(
            chapterApiRoadNamePathController,
            _RuleEditorText.roadNamePath,
          ),
          _editorField(
            chapterApiEpisodesPathController,
            _RuleEditorText.episodeListPath,
          ),
          _editorField(
            chapterApiEpisodeNamePathController,
            _RuleEditorText.episodeNamePath,
          ),
          _editorField(
            chapterApiEpisodeURLPathController,
            _RuleEditorText.playbackEntryPath,
            helper: _RuleEditorText.playbackEntryPathHelper,
          ),
        ] else ...[
          _editorField(
            chapterApiRoadNamesPathController,
            _RuleEditorText.roadNamesPath,
          ),
          _editorField(
            chapterApiRoadEpisodesPathController,
            _RuleEditorText.roadEpisodesPath,
          ),
          _editorField(
            chapterApiRoadSeparatorController,
            _RuleEditorText.roadSeparator,
          ),
          _editorField(
            chapterApiEpisodeSeparatorController,
            _RuleEditorText.episodeSeparator,
          ),
          _editorField(
            chapterApiFieldSeparatorController,
            _RuleEditorText.fieldSeparator,
          ),
        ],
        _editorField(
          chapterApiVariablesController,
          _RuleEditorText.responseVariables,
          maxLines: 5,
        ),
        _editorField(
          chapterApiPageURLController,
          _RuleEditorText.playPageUrl,
        ),
        _editorField(
          chapterApiPageQueryController,
          _RuleEditorText.playPageQuery,
          maxLines: 5,
        ),
      ];

  Widget _editorField(
    TextEditingController controller,
    String label, {
    String? helper,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Plugin _buildEditedPlugin() {
    final searchConfig = _buildSearchApiConfig();
    final chapterConfig = _buildChapterApiConfig();
    return Plugin(
      api: searchMode == RuleMode.api || chapterMode == RuleMode.api
          ? ApiEndpoints.apiLevel.toString()
          : apiController.text,
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
      searchMode: searchMode,
      chapterMode: chapterMode,
      searchApiConfig: searchConfig,
      chapterApiConfig: chapterConfig,
      antiCrawlerConfig: AntiCrawlerConfig(
        enabled: antiCrawlerEnabled,
        captchaType: captchaType,
        captchaImage: captchaImageController.text,
        captchaInput: captchaInputController.text,
        captchaButton: captchaButtonController.text,
        captchaDetectType: captchaDetectType,
        captchaDetectValue: captchaDetectValueController.text,
        captchaScript: captchaScriptController.text,
      ),
    );
  }

  ApiSearchConfig _buildSearchApiConfig() {
    if (searchMode != RuleMode.api) {
      return ApiSearchConfig(
        request: ApiRequestConfig(
          method: searchApiMethod,
          url: searchApiURLController.text,
          headers: _parseJsonMap(searchApiHeadersController, '搜索请求头'),
          query: _parseJsonMap(searchApiQueryController, '搜索查询参数'),
          bodyType: searchApiBodyType,
          body: _parseBody(
            searchApiBodyController,
            searchApiBodyType,
            '搜索请求体',
          ),
        ),
        listPath: searchApiListPathController.text,
        namePath: searchApiNamePathController.text,
        sourcePath: searchApiSourcePathController.text,
      );
    }
    final config = ApiSearchConfig(
      request: ApiRequestConfig(
        method: searchApiMethod,
        url: searchApiURLController.text.trim(),
        headers: _parseJsonMap(searchApiHeadersController, '搜索请求头'),
        query: _parseJsonMap(searchApiQueryController, '搜索查询参数'),
        bodyType: searchApiBodyType,
        body: _parseBody(
          searchApiBodyController,
          searchApiBodyType,
          '搜索请求体',
        ),
      ),
      listPath: searchApiListPathController.text.trim(),
      namePath: searchApiNamePathController.text.trim(),
      sourcePath: searchApiSourcePathController.text.trim(),
    );
    if (config.request.url.isEmpty) {
      throw const FormatException('搜索请求地址不能为空');
    }
    const ApiRuleStrategy().prepareRequest(
      config.request,
      const {'keyword': 'test'},
    );
    RestrictedJsonPath.validate(config.listPath);
    RestrictedJsonPath.validate(config.namePath);
    RestrictedJsonPath.validate(config.sourcePath);
    return config;
  }

  ApiChapterConfig _buildChapterApiConfig() {
    final pageUrl = chapterApiPageURLController.text.trim();
    final variablesRaw = _parseJsonMap(
      chapterApiVariablesController,
      '选集响应变量',
    );
    final config = ApiChapterConfig(
      request: ApiRequestConfig(
        method: chapterApiMethod,
        url: chapterApiURLController.text.trim(),
        headers: _parseJsonMap(chapterApiHeadersController, '选集请求头'),
        query: _parseJsonMap(chapterApiQueryController, '选集查询参数'),
        bodyType: chapterApiBodyType,
        body: _parseBody(
          chapterApiBodyController,
          chapterApiBodyType,
          '选集请求体',
        ),
      ),
      format: chapterApiFormat,
      roadsPath: chapterApiRoadsPathController.text.trim(),
      roadNamePath: chapterApiRoadNamePathController.text.trim(),
      episodesPath: chapterApiEpisodesPathController.text.trim(),
      episodeNamePath: chapterApiEpisodeNamePathController.text.trim(),
      episodeUrlPath: chapterApiEpisodeURLPathController.text.trim(),
      roadNamesPath: chapterApiRoadNamesPathController.text.trim(),
      roadEpisodesPath: chapterApiRoadEpisodesPathController.text.trim(),
      roadSeparator: chapterApiRoadSeparatorController.text,
      episodeSeparator: chapterApiEpisodeSeparatorController.text,
      fieldSeparator: chapterApiFieldSeparatorController.text,
      variables: variablesRaw.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      episodePage: pageUrl.isEmpty
          ? null
          : ApiEpisodePageConfig(
              url: pageUrl,
              query: _parseJsonMap(
                chapterApiPageQueryController,
                '播放页查询参数',
              ),
            ),
    );
    if (chapterMode != RuleMode.api) return config;
    if (config.request.url.isEmpty) {
      throw const FormatException('选集请求地址不能为空');
    }
    const ApiRuleStrategy().prepareRequest(
      config.request,
      const {'source': 'test'},
    );
    for (final path in config.variables.values) {
      RestrictedJsonPath.validate(path);
    }
    if (config.format == ApiChapterFormat.nested) {
      if (config.roadsPath.isNotEmpty) {
        RestrictedJsonPath.validate(config.roadsPath);
      }
      if (config.roadNamePath.isNotEmpty) {
        RestrictedJsonPath.validate(config.roadNamePath);
      }
      RestrictedJsonPath.validate(config.episodesPath);
      RestrictedJsonPath.validate(config.episodeNamePath);
      if (config.episodeUrlPath.isNotEmpty) {
        RestrictedJsonPath.validate(config.episodeUrlPath);
      } else if (config.episodePage == null) {
        throw const FormatException('必须配置播放入口地址路径或播放页地址模板');
      }
    } else {
      RestrictedJsonPath.validate(config.roadNamesPath);
      RestrictedJsonPath.validate(config.roadEpisodesPath);
      if (config.roadSeparator.isEmpty ||
          config.episodeSeparator.isEmpty ||
          config.fieldSeparator.isEmpty) {
        throw const FormatException('章节分隔符不能为空');
      }
    }
    return config;
  }

  Map<String, dynamic> _parseJsonMap(
    TextEditingController controller,
    String label,
  ) {
    final text = controller.text.trim();
    if (text.isEmpty) return <String, dynamic>{};
    final value = jsonDecode(text);
    if (value is! Map) throw FormatException('$label 必须是 JSON 对象');
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  dynamic _parseBody(
    TextEditingController controller,
    String bodyType,
    String label,
  ) {
    if (bodyType == ApiBodyType.none) return null;
    final text = controller.text.trim();
    if (text.isEmpty) return <String, dynamic>{};
    final dynamic value;
    try {
      value = jsonDecode(text);
    } on FormatException catch (error) {
      throw FormatException('$label 不是有效 JSON：${error.message}');
    }
    if (bodyType == ApiBodyType.form && value is! Map) {
      throw FormatException('$label 在表单模式下必须是 JSON 对象');
    }
    return value;
  }

  void _showEditorError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
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
