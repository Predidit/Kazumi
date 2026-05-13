import 'package:flutter/material.dart';

/// Bundle 当前桌面端实际生效的 light + dark ColorScheme。
///
/// `dynamic_color` 的输出在桌面端运行时才确定（macOS 强调色、Windows 系统色），
/// LanServer 没有 BuildContext 拿不到 `Theme.of(context).colorScheme`。
/// 通过把 `app_widget.dart` 内 DynamicColorBuilder 已经选定的 `ColorScheme`
/// 回写到下面的 ValueNotifier，LanServer / `/api/theme` / SSE 推送就能
/// 用同样的 token 出现在 web 端。
class EffectiveColorScheme {
  const EffectiveColorScheme({required this.light, required this.dark});

  final ColorScheme light;
  final ColorScheme dark;
}

/// 全局 ValueNotifier，跨层共享当前生效 ColorScheme。
///
/// 初始 value 为 `null` —— 表示 DynamicColorBuilder 还没首次 build，
/// 此时 LanServer 应回退到 `ColorScheme.fromSeed(seed)` 自行生成。
final ValueNotifier<EffectiveColorScheme?> effectiveColorSchemeNotifier =
    ValueNotifier<EffectiveColorScheme?>(null);
