import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bili_bangumi/info.dart';
import 'package:kazumi/modules/bili_search/result.dart';
import 'package:kazumi/request/damaku.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

class BiliSearchDialog extends StatefulWidget {
  const BiliSearchDialog({
    super.key,
    required this.keyword,
    required this.onChangeDm,
  });

  final String keyword;
  final ValueChanged<int> onChangeDm;

  @override
  State<BiliSearchDialog> createState() => _BiliSearchDialogState();
}

class _BiliSearchDialogState extends State<BiliSearchDialog> {
  String? _cookie;
  late final SearchMBangumiModel _data = SearchMBangumiModel()
    ..list = List<SearchMBangumiItemModel>.empty(growable: true);
  int _bangumiPage = 1;
  int _ftPage = 1;
  bool _isEndBangumi = false;
  bool _isEndft = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    try {
      // get cookie
      Request().get('https://www.bilibili.com/').then((res) {
        _cookie = (res.headers['set-cookie'] as List?)?.join('');
        _searchByType();
      });
    } catch (e) {
      KazumiDialog.dismiss();
      KazumiDialog.showToast(message: '弹幕检索错误: $e');
      KazumiLogger().log(Level.error, '$e');
    }
  }

  // get bangumi
  void _searchByType() async {
    try {
      if (_isLoading || (_isEndBangumi && _isEndft)) return;
      _isLoading = true;
      List<SearchMBangumiModel?> res = await Future.wait([
        if (!_isEndBangumi)
          DanmakuRequest.biliSearchByType(
            isBangumi: true,
            keyword: widget.keyword,
            page: _bangumiPage,
            cookie: _cookie,
          ),
        if (!_isEndft)
          DanmakuRequest.biliSearchByType(
            isBangumi: false,
            keyword: widget.keyword,
            page: _ftPage,
            cookie: _cookie,
          ),
      ]);

      SearchMBangumiModel? bangumiData = _isEndBangumi ? null : res[0];
      SearchMBangumiModel? ftData = _isEndBangumi
          ? _isEndft
              ? null
              : res[0]
          : _isEndft
              ? null
              : res[1];

      if (bangumiData?.list.isNotEmpty == true) {
        _bangumiPage++;
        _data.list.addAll(bangumiData!.list);
      } else {
        _isEndBangumi = true;
      }

      if (ftData?.list.isNotEmpty == true) {
        _ftPage++;
        _data.list.addAll(ftData!.list);
      } else {
        _isEndft = true;
      }

      setState(() {});

      _isLoading = false;

      // empty
      if (_bangumiPage == 1 && _ftPage == 1 && _data.list.isEmpty) {
        KazumiDialog.dismiss();
        KazumiDialog.showToast(message: '未找到匹配结果');
      }
    } catch (e) {
      if (_data.list.isEmpty) {
        KazumiDialog.dismiss();
      }
      KazumiDialog.showToast(message: '弹幕检索: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _data.list.isEmpty == true
        ? Center(
            child: Card(
              elevation: 8.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      '弹幕检索中',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          )
        : Dialog(
            clipBehavior: Clip.hardEdge,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _data.list.length,
              itemBuilder: (context, index) {
                if (index == _data.list.length - 1) {
                  // loadmore
                  if (!_isEndBangumi || !_isEndft) {
                    _searchByType();
                  }
                }
                final item = _data.list[index];
                return ListTile(
                  title: Text('${item.title}'),
                  onTap: () {
                    KazumiDialog.dismiss();
                    KazumiDialog.showLoading(msg: '弹幕检索中');
                    _getPgcEpisodes(item.seasonId);
                  },
                );
              },
            ),
          );
  }

  // get episodes
  void _getPgcEpisodes(seasonId) async {
    try {
      final res = await DanmakuRequest.getBiliBangumiInfo(
        seasonId: seasonId,
        cookie: _cookie,
      );
      if (res?.episodes?.isNotEmpty == true) {
        KazumiDialog.dismiss();
        KazumiDialog.show(
          builder: (context) => Dialog(
            clipBehavior: Clip.hardEdge,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: res!.episodes!.length,
              itemBuilder: (context, index) {
                EpisodeItem item = res.episodes![index];
                return ListTile(
                  title: Text(item.showTitle ?? ''),
                  onTap: () {
                    KazumiDialog.dismiss();
                    if (item.cid != null) {
                      KazumiDialog.showToast(message: '弹幕切换中');
                      widget.onChangeDm(item.cid!);
                    }
                  },
                );
              },
            ),
          ),
        );
      } else {
        KazumiDialog.dismiss();
        KazumiDialog.showToast(message: '未找到匹配结果');
      }
    } catch (e) {
      KazumiDialog.dismiss();
      KazumiDialog.showToast(message: '弹幕检索错误: $e');
      KazumiLogger().log(Level.error, '$e');
    }
  }
}
