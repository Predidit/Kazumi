import 'package:flutter/material.dart';

import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/pages/about/about_widgets.dart';
import 'package:kazumi/request/config/api_endpoints.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.onCheckUpdate});

  final Future<bool> Function() onCheckUpdate;

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('关于'),
        body: AboutContent(
          children: [
            _ProjectHeader(onCheckUpdate: onCheckUpdate),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              final sections = [
                ContentSection.group(
                  title: '项目',
                  children: const [
                    AboutLinkTile(
                      icon: Icons.code_rounded,
                      title: '源代码',
                      url: ApiEndpoints.sourceUrl,
                    ),
                    AboutLinkTile(
                      icon: Icons.language_rounded,
                      title: '项目主页',
                      url: ApiEndpoints.projectUrl,
                    ),
                    AboutLinkTile(
                      icon: Icons.bug_report_rounded,
                      title: '问题反馈',
                      url: '${ApiEndpoints.sourceUrl}/issues',
                    ),
                    AboutLinkTile(
                      icon: Icons.forum_rounded,
                      title: 'Telegram',
                      url: ApiEndpoints.telegramGroup,
                    ),
                  ],
                ),
                ContentSection.group(
                  title: '开源',
                  children: [
                    const AboutLinkTile(
                      icon: Icons.handshake_outlined,
                      title: '贡献指南',
                      url:
                          '${ApiEndpoints.sourceUrl}/blob/main/static/doc/CONTRIBUTING.md',
                    ),
                    const AboutLinkTile.route(
                      icon: Icons.favorite_outline_rounded,
                      title: '致谢',
                      route: '/settings/about/credits',
                    ),
                    const AboutLinkTile(
                      icon: Icons.balance_rounded,
                      title: 'GPL-3.0 许可证',
                      url: '${ApiEndpoints.sourceUrl}/blob/main/LICENSE',
                    ),
                    const AboutLinkTile.route(
                      icon: Icons.description_outlined,
                      title: '第三方许可证',
                      route: '/settings/about/license',
                    ),
                  ],
                ),
              ];
              if (constraints.maxWidth >= 640 &&
                  MediaQuery.textScalerOf(context).scale(14) < 21) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: sections[0]),
                    const SizedBox(width: 16),
                    Expanded(child: sections[1]),
                  ],
                );
              }
              return Column(
                children: [
                  sections[0],
                  const SizedBox(height: 24),
                  sections[1]
                ],
              );
            }),
          ],
        ),
      );
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.onCheckUpdate});

  final Future<bool> Function() onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Kazumi',
              style: theme.textTheme.displayMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ApiEndpoints.version,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '基于自定义规则的开源番剧应用',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CheckUpdateButton(onCheckUpdate: onCheckUpdate),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => openAboutLink(
                  context,
                  '${ApiEndpoints.sourceUrl}/releases',
                ),
                child: const Text('更新日志'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
