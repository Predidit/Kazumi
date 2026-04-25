import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/request/damaku.dart';

class PlayerDanmakuSearchPanel extends StatefulWidget {
  const PlayerDanmakuSearchPanel({
    super.key,
    required this.playerController,
    required this.initialKeyword,
    this.onClosePanel,
  });

  final PlayerController playerController;
  final String initialKeyword;
  final VoidCallback? onClosePanel;

  @override
  State<PlayerDanmakuSearchPanel> createState() =>
      _PlayerDanmakuSearchPanelState();
}

class _PlayerDanmakuSearchPanelState extends State<PlayerDanmakuSearchPanel> {
  late final TextEditingController _searchController;
  bool _searchingAnime = false;
  int? _loadingAnimeId;
  int? _expandedAnimeId;
  List<DanmakuAnime> _animes = <DanmakuAnime>[];
  final Map<int, List<DanmakuEpisode>> _episodeCache =
      <int, List<DanmakuEpisode>>{};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialKeyword);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAnime() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      KazumiDialog.showToast(message: '请输入番剧名');
      return;
    }

    setState(() {
      _searchingAnime = true;
      _expandedAnimeId = null;
      _loadingAnimeId = null;
      _episodeCache.clear();
    });

    try {
      final DanmakuSearchResponse response =
          await DanmakuRequest.getDanmakuSearchResponse(keyword);
      if (!mounted) return;
      setState(() {
        _animes = response.animes;
      });
      if (_animes.isEmpty) {
        KazumiDialog.showToast(message: '未找到匹配结果');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '弹幕检索错误: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _searchingAnime = false;
        });
      }
    }
  }

  Future<void> _ensureEpisodesLoaded(DanmakuAnime anime) async {
    if (_episodeCache.containsKey(anime.animeId)) {
      return;
    }

    setState(() {
      _loadingAnimeId = anime.animeId;
    });

    try {
      final DanmakuEpisodeResponse response =
          await DanmakuRequest.getDanDanEpisodesByDanDanBangumiID(
              anime.animeId);
      if (!mounted) return;
      setState(() {
        _episodeCache[anime.animeId] = response.episodes;
      });
      if ((_episodeCache[anime.animeId] ?? <DanmakuEpisode>[]).isEmpty) {
        KazumiDialog.showToast(message: '未找到匹配结果');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '弹幕检索错误: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          if (_loadingAnimeId == anime.animeId) {
            _loadingAnimeId = null;
          }
        });
      }
    }
  }

  Future<void> _toggleAnimeExpanded(DanmakuAnime anime) async {
    if (_expandedAnimeId == anime.animeId) {
      setState(() {
        _expandedAnimeId = null;
      });
      return;
    }

    setState(() {
      _expandedAnimeId = anime.animeId;
    });
    await _ensureEpisodesLoaded(anime);
  }

  Future<void> _switchEpisode(DanmakuEpisode episode) async {
    try {
      await widget.playerController.getDanDanmakuByEpisodeID(episode.episodeId);
      KazumiDialog.showToast(message: '弹幕切换成功');
      widget.onClosePanel?.call();
    } catch (_) {
      KazumiDialog.showToast(message: '弹幕切换失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '弹幕检索',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: '番剧名',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                prefixIcon:
                    Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurface),
                suffixIcon: IconButton(
                  onPressed: _searchingAnime ? null : _searchAnime,
                  icon: Icon(Icons.send_rounded, color: Theme.of(context).colorScheme.onSurface),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _searchAnime(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildAnimeList(Theme.of(context).colorScheme.onSurface, Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeList(Color? primaryTextColor, Color? secondaryTextColor) {
    if (_searchingAnime) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_animes.isEmpty) {
      return Center(
        child: Text(
          '输入番剧名开始检索',
          style: TextStyle(color: secondaryTextColor),
        ),
      );
    }

    return ListView(
      children: [
        for (final anime in _animes) ...[
          ListTile(
            title: Text(
              anime.animeTitle,
              style: TextStyle(color: primaryTextColor),
            ),
            subtitle: Text(
              anime.typeDescription,
              style: TextStyle(color: secondaryTextColor),
            ),
            trailing: Icon(
              _expandedAnimeId == anime.animeId
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: secondaryTextColor,
            ),
            onTap: () => _toggleAnimeExpanded(anime),
          ),
          if (_expandedAnimeId == anime.animeId)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4, bottom: 8),
              child: _buildEpisodeSection(
                animeId: anime.animeId,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
              ),
            ),
          Divider(
            height: 1,
            color: secondaryTextColor?.withValues(alpha: 0.2),
          ),
        ],
      ],
    );
  }

  Widget _buildEpisodeSection({
    required int animeId,
    required Color? primaryTextColor,
    required Color? secondaryTextColor,
  }) {
    if (_loadingAnimeId == animeId) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final List<DanmakuEpisode> episodes =
        _episodeCache[animeId] ?? <DanmakuEpisode>[];
    if (episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '未找到分集',
          style: TextStyle(color: secondaryTextColor),
        ),
      );
    }

    return Column(
      children: [
        for (final episode in episodes)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 8, right: 4),
            dense: true,
            title: Text(
              episode.episodeTitle,
              style: TextStyle(color: primaryTextColor),
            ),
            trailing: Icon(Icons.play_arrow_rounded, color: secondaryTextColor),
            onTap: () => _switchEpisode(episode),
          ),
      ],
    );
  }
}
