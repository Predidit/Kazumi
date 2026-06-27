/// 订阅规则在抓取阶段直接产出的“单集身份”。
///
/// 设计目标：不再让播放器从 URL 反推 episode 身份，而是由规则一次性产出权威身份，
/// 下游（历史、弹幕、选集、下载）直接消费。身份被显式拆成两个面：
/// - [stableId]：定位 / 持久 key，用于历史进度匹配，与域名/协议/列表顺序无关；
/// - [ordinal]：集序数，用于弹幕集号与排序，需对齐外部编号（Bangumi 1..N）。
///
/// 详见 `docs/episode-identity-design.md`。
class EpisodeIdentity {
  /// 定位 / 持久 key：在 `(规则, 番剧, road 作用域)` 内唯一且顺序无关。
  /// 优先级：源站显式 id/slug > 归一化相对 path（`stableEpisodeIdFromUrl`）。
  /// URL 噪声 / 域名 / 协议不参与，作为历史进度匹配主键。
  final String stableId;

  /// 可访问的请求 URL（已归一化）。仅用于发起请求，不再用于身份匹配。
  final String pageUrl;

  /// 展示标题（原样保留 “OVA”/“特别篇” 等非数字标题）。
  final String title;

  /// 集序数：对齐 Bangumi 官方 1..N 的弹幕 / 排序号；
  /// 源站无法判定时为 null（下游可显式降级为列表位次，但不写回 [stableId]）。
  final int? ordinal;

  /// 该集所属的“原始线路”下标（规则抓取时的 road 次序，顺序无关）。
  final int roadIndex;

  const EpisodeIdentity({
    required this.stableId,
    required this.pageUrl,
    required this.title,
    required this.roadIndex,
    this.ordinal,
  });

  @override
  String toString() =>
      'EpisodeIdentity(stableId: $stableId, ordinal: $ordinal, title: $title)';
}

class Road {
  String name;

  /// 由 `List<String>` 升级为 `List<EpisodeIdentity>`：规则直接产出每集身份。
  /// 原 `identifier`（标题数组）已并入 [EpisodeIdentity.title]。
  List<EpisodeIdentity> data;

  Road({
    required this.name,
    required this.data,
  });

  /// 按 [EpisodeIdentity.stableId] 定位某集在本线路中的位置（0-based），未命中返回 -1。
  int indexOfStableId(String stableId) {
    final id = stableId.trim();
    if (id.isEmpty) return -1;
    return data.indexWhere((e) => e.stableId == id);
  }

  /// 按 [EpisodeIdentity.ordinal] 定位某集（离线列表按下载集号查找），未命中返回 -1。
  int indexOfOrdinal(int ordinal) {
    return data.indexWhere((e) => e.ordinal == ordinal);
  }
}
