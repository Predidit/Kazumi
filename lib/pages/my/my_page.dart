import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SysAppBar(title: Text('我的'), needTopOffset: false),
      body: SingleChildScrollView(
        child: KazumiPageBody(
          maxWidth: 960,
          child: Column(
            children: [
              KazumiSettingsSection(
                title: '播放历史与视频源',
                children: [
                  _tile(
                    context,
                    icon: Icons.history_rounded,
                    title: '历史记录',
                    subtitle: '查看和继续最近的播放记录',
                    route: '/settings/history/',
                  ),
                  _tile(
                    context,
                    icon: Icons.download_rounded,
                    title: '下载管理',
                    subtitle: '查看、暂停或继续离线下载',
                    route: '/settings/download/',
                  ),
                  _tile(
                    context,
                    icon: Icons.tune_rounded,
                    title: '下载设置',
                    subtitle: '配置下载目录、并发数与相关选项',
                    route: '/settings/download-settings',
                  ),
                  _tile(
                    context,
                    icon: Icons.extension_rounded,
                    title: '规则管理',
                    subtitle: '管理、测试和更新番剧资源规则',
                    route: '/settings/plugin/',
                  ),
                ],
              ),
              KazumiSettingsSection(
                title: '播放器',
                children: [
                  _tile(
                    context,
                    icon: Icons.display_settings_rounded,
                    title: '播放设置',
                    subtitle: '控制播放行为、解码和画面选项',
                    route: '/settings/player',
                  ),
                  _tile(
                    context,
                    icon: Icons.subtitles_rounded,
                    title: '弹幕设置',
                    subtitle: '调整显示、过滤、偏移与交互参数',
                    route: '/settings/danmaku/',
                  ),
                  _tile(
                    context,
                    icon: Icons.keyboard_rounded,
                    title: '快捷键',
                    subtitle: '查看和自定义桌面播放快捷键',
                    route: '/settings/keyboard',
                  ),
                  _tile(
                    context,
                    icon: Icons.vpn_key_rounded,
                    title: '代理设置',
                    subtitle: '配置并测试 HTTP 代理',
                    route: '/settings/proxy',
                  ),
                ],
              ),
              KazumiSettingsSection(
                title: '应用与外观',
                children: [
                  _tile(
                    context,
                    icon: Icons.palette_rounded,
                    title: '外观设置',
                    subtitle: '主题、动态配色、字体与显示模式',
                    route: '/settings/theme',
                  ),
                  _tile(
                    context,
                    icon: Icons.dashboard_customize_rounded,
                    title: '界面设置',
                    subtitle: '调整启动页、窗口与界面行为',
                    route: '/settings/interface',
                  ),
                  _tile(
                    context,
                    icon: Icons.cloud_sync_rounded,
                    title: '同步设置',
                    subtitle: '配置 WebDAV 与 Bangumi 同步',
                    route: '/settings/webdav/',
                  ),
                ],
              ),
              KazumiSettingsSection(
                title: '支持',
                children: [
                  _tile(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: '关于 Kazumi',
                    subtitle: '版本、缓存、日志与开源许可',
                    route: '/settings/about/',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    final colors = Theme.of(context).colorScheme;
    return KazumiSettingsTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 21, color: colors.onPrimaryContainer),
      ),
      title: title,
      subtitle: subtitle,
      onTap: () => context.pushNamed(route),
    );
  }
}
