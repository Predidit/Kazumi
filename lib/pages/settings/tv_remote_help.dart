import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/bean/widget/tv_focusable_surface.dart';

class TvRemoteHelp extends StatelessWidget {
  const TvRemoteHelp({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(children: [
            for (final group in _tvRemoteGroups)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TvFocusableSurface(
                  onPressed: () {},
                  child: ContentSection.group(
                    title: group.title,
                    children: [
                      for (final item in group.items)
                        ListTile(
                          leading: Icon(item.icon),
                          title: Text(item.title),
                          subtitle: Text(item.description),
                        ),
                    ],
                  ),
                ),
              ),
          ]),
        ),
      );
}

class _TvRemoteMapping {
  const _TvRemoteMapping(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

class _TvRemoteGroup {
  const _TvRemoteGroup(this.title, this.icon, this.items);

  final String title;
  final IconData icon;
  final List<_TvRemoteMapping> items;
}

const List<_TvRemoteGroup> _tvRemoteGroups = [
  _TvRemoteGroup(
    '首页与导航',
    Icons.home_rounded,
    [
      _TvRemoteMapping(
        Icons.pin_rounded,
        '数字键 0–9',
        '按首页编号定位番剧；停顿 1.8 秒后进入，确认键可立即进入',
      ),
      _TvRemoteMapping(
        Icons.manage_search_rounded,
        '找不到编号',
        '最多额外加载 5 页或等待 10 秒；返回键和切换页面均可中断',
      ),
      _TvRemoteMapping(
        Icons.swap_horiz_rounded,
        '顶部分类',
        '左右键切换分类，焦点停留后刷新下方番剧',
      ),
      _TvRemoteMapping(
        Icons.gamepad_rounded,
        '方向键 / OK / 返回',
        '按钮行和分类首尾循环；节目首列左键返回侧栏，侧栏左键跳到右侧；返回关闭当前层',
      ),
      _TvRemoteMapping(
        Icons.home_outlined,
        '长按返回约 1 秒后松开',
        '直接返回本应用的 LCN 主页；短按保持逐层返回，主页短按两次退出。系统 Home 仍回电视桌面',
      ),
      _TvRemoteMapping(
        Icons.play_arrow_rounded,
        '详情页：播放 / 播放暂停键',
        '优先续播上次的源和进度；无可用历史时打开选源，不自动猜测搜索结果',
      ),
    ],
  ),
  _TvRemoteGroup(
    '播放器固定映射',
    Icons.play_circle_rounded,
    [
      _TvRemoteMapping(
        Icons.radio_button_checked,
        'OK / 上 / 下（控制栏隐藏时）',
        'OK 或下键唤醒并聚焦播放/暂停；上键聚焦选集。唤醒不暂停，再按 OK 才执行当前按钮',
      ),
      _TvRemoteMapping(
        Icons.play_circle_outline_rounded,
        '播放与定位',
        '播放/暂停键；左右键或媒体键快退、快进；频道键切换上下集',
      ),
      _TvRemoteMapping(
        Icons.view_list_rounded,
        '选集',
        'EPG/Guide、Top Menu 或黄色功能键',
      ),
      _TvRemoteMapping(
        Icons.subtitles_rounded,
        '弹幕',
        '字幕/CC、音轨或红色功能键统一映射为弹幕开关',
      ),
      _TvRemoteMapping(
        Icons.favorite_outline_rounded,
        '收藏',
        '收藏键或绿色功能键',
      ),
      _TvRemoteMapping(
        Icons.info_outline_rounded,
        '播放信息',
        'INFO 或蓝色功能键，查看硬解、帧率、缓存和丢帧',
      ),
      _TvRemoteMapping(
        Icons.stop_circle_outlined,
        '停止 / 退出',
        'Stop 或 Exit 退出播放器',
      ),
    ],
  ),
  _TvRemoteGroup(
    '系统按键与自定义边界',
    Icons.settings_remote_rounded,
    [
      _TvRemoteMapping(
        Icons.volume_up_rounded,
        '音量 / 静音',
        '交给 Android TV 处理，以兼容电视、CEC、ARC/eARC 和功放',
      ),
      _TvRemoteMapping(
        Icons.security_rounded,
        '系统保留键',
        '部分电视会先拦截 EPG、音量等按键，应用只能处理系统实际传入的键值',
      ),
      _TvRemoteMapping(
        Icons.keyboard_rounded,
        '自定义按键',
        '右侧页签可修改播放器通用快捷键；上述 TV 兼容映射保持固定，避免设备差异导致失效',
      ),
    ],
  ),
];
