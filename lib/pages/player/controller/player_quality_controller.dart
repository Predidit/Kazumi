// ignore_for_file: library_private_types_in_public_api

import 'package:http/http.dart' as http;
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/m3u8_parser.dart';
import 'package:mobx/mobx.dart';

part 'player_quality_controller.g.dart';

/// 「自动」清晰度的固定 id（由播放器/站点选择，默认最高码率）。
const String autoQualityId = 'auto';

class PlayerQualityController = _PlayerQualityController
    with _$PlayerQualityController;

/// 一个可选择的清晰度。
class QualityOption {
  const QualityOption({
    required this.id,
    required this.label,
    required this.uri,
    required this.isAuto,
    this.height,
    this.bandwidth = 0,
  });

  /// 'auto' 或 'v' 加序号（v0 为最高清晰度）。
  final String id;

  /// 展示文案，如「自动」「1080P」「2.1 Mbps」。
  final String label;

  /// 选择后应当打开的 URL（auto 时为 master URL）。
  final String uri;

  final bool isAuto;
  final int? height;
  final int bandwidth;
}

abstract class _PlayerQualityController with Store {
  @observable
  ObservableList<QualityOption> qualities = ObservableList<QualityOption>();

  @observable
  String currentQualityId = autoQualityId;

  @observable
  bool loading = false;

  /// 内存中的清晰度偏好（按高度）。null 表示自动（默认最高）。
  /// 切集时会按此偏好自动选择，退出播放页后重置。
  int? preferredHeight;

  bool get isAvailable => qualities.any((q) => !q.isAuto);

  QualityOption? get currentOption {
    for (final q in qualities) {
      if (q.id == currentQualityId) {
        return q;
      }
    }
    return qualities.isNotEmpty ? qualities.first : null;
  }

  /// 当前展示给用户的清晰度标签（用于按钮）。
  String get currentLabel => currentOption?.label ?? '自动';

  /// 在播放器 open 之前调用。
  ///
  /// 若 [url] 是含多清晰度的 HLS master，则解析并返回按偏好选定的起始 URL，
  /// 同时填充 [qualities]；否则原样返回 [url]，且不提供清晰度选择。
  Future<String> prepare(String url, Map<String, String> headers) async {
    reset();

    if (!_looksLikeHls(url)) {
      return url;
    }

    loading = true;
    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 8));
      final body = response.body;
      if (M3u8Parser.detectType(body) != M3u8Type.master) {
        return url;
      }

      final variants = M3u8Parser.parseMasterPlaylist(body, url).variants;
      if (variants.isEmpty) {
        return url;
      }

      // 先按高度/码率从高到低排序，再分配稳定 id（v0 为最高）。
      final sorted = variants.map((v) {
        return QualityOption(
          id: '',
          label: _labelFor(
            height: _heightOf(v.resolution),
            bandwidth: v.bandwidth,
          ),
          uri: v.uri,
          isAuto: false,
          height: _heightOf(v.resolution),
          bandwidth: v.bandwidth,
        );
      }).toList()
        ..sort((a, b) {
          final ah = a.height;
          final bh = b.height;
          if (ah != null && bh != null && ah != bh) {
            return bh.compareTo(ah);
          }
          return b.bandwidth.compareTo(a.bandwidth);
        });

      final options = <QualityOption>[
        QualityOption(
            id: autoQualityId, label: '自动', uri: url, isAuto: true),
        for (var i = 0; i < sorted.length; i++)
          QualityOption(
            id: 'v$i',
            label: sorted[i].label,
            uri: sorted[i].uri,
            isAuto: false,
            height: sorted[i].height,
            bandwidth: sorted[i].bandwidth,
          ),
      ];

      qualities = ObservableList<QualityOption>.of(options);

      final preferred = _matchPreferred(options);
      currentQualityId = preferred.id;
      return preferred.uri;
    } catch (e) {
      // 拿不到 master（网络/代理/鉴权等）不影响正常播放，只是没有清晰度列表。
      KazumiLogger()
          .w('PlayerQualityController: failed to parse HLS master', error: e);
      return url;
    } finally {
      loading = false;
    }
  }

  /// 用户在面板中选择清晰度后，返回需要打开的目标 URL；不匹配时返回 null。
  String? targetUrlFor(String id) {
    for (final q in qualities) {
      if (q.id == id) {
        return q.uri;
      }
    }
    return null;
  }

  /// 用户主动选择后更新当前项与内存偏好。
  @action
  void applyUserSelection(String id) {
    final option = qualities.firstWhere(
      (q) => q.id == id,
      orElse: () => qualities.first,
    );
    currentQualityId = option.id;
    preferredHeight = option.isAuto ? null : option.height;
  }

  @action
  void reset() {
    qualities = ObservableList<QualityOption>();
    currentQualityId = autoQualityId;
    loading = false;
  }

  /// 根据 [preferredHeight] 在选项中挑出最合适的一项；无偏好时为自动。
  QualityOption _matchPreferred(List<QualityOption> options) {
    final auto = options.first;
    final height = preferredHeight;
    if (height == null) {
      return auto;
    }
    final variants = options.where((q) => !q.isAuto).toList();
    if (variants.isEmpty) {
      return auto;
    }
    // 精确匹配优先；否则取不超过偏好的最高清晰度；都偏大则取最低。
    QualityOption? exact;
    QualityOption? below;
    for (final q in variants) {
      final h = q.height;
      if (h == height) {
        exact = q;
        break;
      }
      if (h != null && h <= height) {
        if (below == null || (h > (below.height ?? -1))) {
          below = q;
        }
      }
    }
    if (exact != null) {
      return exact;
    }
    if (below != null) {
      return below;
    }
    return variants.reduce((a, b) => (a.height ?? 1 << 30) < (b.height ?? 1 << 30)
        ? a
        : b);
  }

  bool _looksLikeHls(String url) {
    var path = url;
    final q = path.indexOf('?');
    if (q >= 0) {
      path = path.substring(0, q);
    }
    return path.toLowerCase().contains('.m3u8');
  }

  int? _heightOf(String? resolution) {
    if (resolution == null) {
      return null;
    }
    final parts = resolution.toLowerCase().split('x');
    if (parts.length != 2) {
      return null;
    }
    return int.tryParse(parts[1].trim());
  }

  String _labelFor({int? height, int bandwidth = 0}) {
    if (height != null && height > 0) {
      return '${height}P';
    }
    final kbps = bandwidth / 1000;
    if (kbps >= 1000) {
      return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
    }
    if (bandwidth > 0) {
      return '${kbps.round()} kbps';
    }
    return '未知';
  }
}
