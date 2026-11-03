import 'package:flutter/material.dart';

import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/pages/about/about_widgets.dart';
import 'package:kazumi/request/config/api_endpoints.dart';

class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('致谢'),
        body: AboutContent(
          children: [
            ContentSection.group(
              title: '贡献',
              children: const [
                AboutLinkTile(
                  icon: Icons.people_outline_rounded,
                  title: '贡献者',
                  url: '${ApiEndpoints.sourceUrl}/graphs/contributors',
                ),
                AboutLinkTile(
                  icon: Icons.brush_rounded,
                  title: '图标作者',
                  subtitle: 'Pixiv',
                  url: ApiEndpoints.iconUrl,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ContentSection.group(
              title: '服务',
              children: const [
                AboutLinkTile(
                  icon: Icons.menu_book_rounded,
                  title: 'Bangumi',
                  subtitle: '番剧信息',
                  url: ApiEndpoints.bangumiIndex,
                ),
                AboutLinkTile(
                  icon: Icons.subtitles_rounded,
                  title: '弹弹play',
                  subtitle: '弹幕',
                  url: ApiEndpoints.dandanIndex,
                ),
                AboutLinkTile(
                  icon: Icons.image_search_rounded,
                  title: 'trace.moe',
                  subtitle: '以图搜番',
                  url: 'https://trace.moe',
                ),
              ],
            ),
            const SizedBox(height: 24),
            ContentSection.group(
              title: '开源项目',
              children: const [
                AboutLinkTile(
                  icon: Icons.flutter_dash_rounded,
                  title: 'Flutter',
                  subtitle: '应用框架',
                  url: 'https://flutter.dev',
                ),
                AboutLinkTile(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'media-kit',
                  subtitle: '视频播放',
                  url: 'https://github.com/media-kit/media-kit',
                ),
                AboutLinkTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Anime4K',
                  subtitle: '实时超分辨率',
                  url: 'https://github.com/bloc97/Anime4K',
                ),
                AboutLinkTile(
                  icon: Icons.sync_rounded,
                  title: 'Syncplay',
                  subtitle: '播放同步',
                  url: 'https://github.com/Syncplay/syncplay',
                ),
                AboutLinkTile(
                  icon: Icons.account_tree_rounded,
                  title: 'XpathSelector',
                  subtitle: 'XPath 解析',
                  url: 'https://github.com/simonkimi/xpath_selector',
                ),
                AboutLinkTile(
                  icon: Icons.video_settings_rounded,
                  title: 'avbuild',
                  subtitle: '非标准视频流支持',
                  url: 'https://github.com/wang-bin/avbuild',
                ),
                AboutLinkTile(
                  icon: Icons.storage_rounded,
                  title: 'Hive CE',
                  subtitle: '本地存储',
                  url: 'https://github.com/IO-Design-Team/hive_ce',
                ),
              ],
            ),
          ],
        ),
      );
}
