import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/search/image_search_module.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';

class ImageSearchPage extends StatefulWidget {
  const ImageSearchPage({super.key});

  @override
  State<ImageSearchPage> createState() => _ImageSearchPageState();
}

class _ImageSearchPageState extends State<ImageSearchPage> {
  final TextEditingController _urlController = TextEditingController();
  final SearchPageController _searchPageController = SearchPageController();
  final ImagePicker _picker = ImagePicker();
  bool _isUrlMode = false;
  String _previewUrl = '';
  Timer? _debounceTimer;
  File? _selectedImageFile;
  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }


  @override
  void dispose() {
    _debounceTimer?.cancel();
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    _debounceTimer?.cancel();
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      setState(() => _previewUrl = '');
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchPageController.clearImageSearchState();
        _previewUrl = text;
      } );
    });
  }

  Future<void> _pickImageFile() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    const int maxImageBytes = 25 * 1024 * 1024;
    final imageFile = File(image.path);
    final imageBytes = await imageFile.length();
    if (imageBytes > maxImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片大小不能超过 25MB')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _searchPageController.clearImageSearchState();
      _selectedImageFile = imageFile;
      _selectedImageName = image.name;
    });
  }

  Future<void> _startSearch() async {
    if (_isUrlMode) {
      final imageUrl = _urlController.text.trim();
      final uri = Uri.tryParse(imageUrl);
      if (imageUrl.isEmpty || uri == null || !uri.hasScheme) {
        KazumiDialog.showToast(message: '请输入有效的图片链接');
        return;
      }
      await _searchPageController.searchImageByUrl(imageUrl);
    } else {
      final imageFile = _selectedImageFile;
      if (imageFile == null) {
        KazumiDialog.showToast(message: '请先选择图片文件');
        return;
      }
      await _searchPageController.searchImageByFile(imageFile);
    }

    if (!mounted) {
      return;
    }

    if (_searchPageController.imageSearchError.isNotEmpty &&
        _searchPageController.imageSearchResults.isEmpty) {
      KazumiDialog.showToast(message: _searchPageController.imageSearchError);
    }
  }

  void _switchMode() {
    setState(() {
      _isUrlMode = !_isUrlMode;
    });
  }

  static String _formatTraceResultTitle(ResultItem result) {
    final title = result.anilist?.title;
    return title?.chinese ??
        title?.native ??
        title?.romaji ??
        title?.english ??
        result.filename ??
        '未知番剧';
  }


  static String _formatTraceEpisode(dynamic episode) {
    String formatEpisodeValue(num value) {
      return value % 1 == 0 ? value.toInt().toString() : value.toString();
    }

    if (episode is num) {
      return '第 ${formatEpisodeValue(episode)} 集';
    }
    if (episode is List && episode.isNotEmpty) {
      final episodes = episode.whereType<num>().map(formatEpisodeValue);
      if (episodes.isNotEmpty) {
        return '剧集: ${episodes.join(' / ')}';
      }
    }
    return '剧集未知';
  }

  int _resolveCrossAxisCount(double width) {
    if (width < LayoutBreakpoint.compact['width']!) {
      return 1;
    }
    if (width < LayoutBreakpoint.medium['width']!) {
      return 2;
    }
    if (width < 1180) {
      return 3;
    }
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: SysAppBar(
        backgroundColor: Colors.transparent,
        title: const Text('图片搜索'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 25,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isUrlMode
                      ? _buildUrlInput(colorScheme, textTheme)
                      : _buildUploadArea(colorScheme, textTheme),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: _switchMode,
                    icon: Icon(
                      _isUrlMode ? Icons.upload_file : Icons.link,
                      size: 18,
                    ),
                    label: Text(_isUrlMode ? '改为上传图片文件' : '改为输入图片 URL'),
                  ),
                ),
                Observer(
                  builder: (context) => SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _searchPageController.isImageSearching
                          ? null
                          : _startSearch,
                      icon: _searchPageController.isImageSearching
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.image_search_rounded),
                      label: Text(
                        _searchPageController.isImageSearching
                            ? '搜索中...'
                            : '开始搜索',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                _buildResultSection(colorScheme, textTheme),
                _buildTips(colorScheme, textTheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea(ColorScheme colorScheme, TextTheme textTheme) {
    return GestureDetector(
      onTap: _pickImageFile,
      child: Container(
        width: double.infinity,
        height: 240,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.4),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _selectedImageFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 32,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '点击选择图片',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '支持 JPG、PNG、WEBP 格式',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    _selectedImageFile!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        '图片预览失败',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedImageName ?? '已选择图片',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '点击可重新选择图片',
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _pickImageFile,
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: '重新选择',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildUrlInput(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      key: const ValueKey('url-input'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            hintText: '请输入图片链接',
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 13,
            ),
            prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _urlController.clear,
              tooltip: '清除',
            ),
            filled: true,
            fillColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _startSearch(),
        ),
        _buildUrlPreview(colorScheme, textTheme),
      ],
    );
  }

  Widget _buildUrlPreview(ColorScheme colorScheme, TextTheme textTheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: 170,
        maxHeight: _previewUrl.isNotEmpty ? 300 : 170,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.4),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _previewUrl.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 36,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '输入图片链接后预览',
                    style: textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            )
          : Image.network(
              _previewUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                final total = loadingProgress.expectedTotalBytes;
                final loaded = loadingProgress.cumulativeBytesLoaded;
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: total != null ? loaded / total : null,
                        strokeWidth: 2.5,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '加载中...',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 36,
                      color: colorScheme.error.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '图片加载失败',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '请检查链接是否有效',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildResultSection(ColorScheme colorScheme, TextTheme textTheme) {
    return Observer(
      builder: (context) {
        final results = _searchPageController.imageSearchResults;
        final errorMessage = _searchPageController.imageSearchError;

        if (_searchPageController.isImageSearching) {
          return _buildStateCard(
            colorScheme: colorScheme,
            textTheme: textTheme,
            icon: const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            title: '正在识别图片',
            description: '请稍候，正在从截图中匹配番剧信息',
          );
        }

        if (results.isEmpty) {
          return _buildStateCard(
            colorScheme: colorScheme,
            textTheme: textTheme,
            icon: Icon(
              errorMessage.isEmpty
                  ? Icons.grid_view_rounded
                  : Icons.error_outline,
              size: 30,
              color: errorMessage.isEmpty
                  ? colorScheme.primary
                  : colorScheme.error,
            ),
            title: errorMessage.isEmpty ? '搜索结果将在这里展示' : '未获取到搜索结果',
            description:
                errorMessage.isEmpty ? '选择图片文件或输入图片链接后开始搜索' : errorMessage,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '识别结果',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = _resolveCrossAxisCount(
                  constraints.maxWidth,
                );
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: results.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 152,
                  ),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return InkWell(
                      onTap: () {
                        final title = _formatTraceResultTitle(result);
                        Navigator.of(context).pop(title);
                      },
                      child: _buildResultCard(
                        context,
                        colorScheme,
                        textTheme,
                        result,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStateCard({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required Widget icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 14),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    ResultItem result,
  ) {
    final coverUrl = result.image ??
        result.anilist?.coverImage?.large ??
        result.anilist?.coverImage?.medium;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatTraceResultTitle(result),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 5,
              children: [
                SizedBox(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: NetworkImgLayer(
                      src: coverUrl,
                      width: 132,
                      height: 74.25,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoLine(
                        textTheme,
                        colorScheme,
                       _formatTraceEpisode(result.episode),
                      ),
                      _buildInfoLine(
                        textTheme,
                        colorScheme,
                        '相似度: ${Utils.formatTraceSimilarity(result.similarity)}',
                      ),
                      _buildInfoLine(
                        textTheme,
                        colorScheme,
                        '时间: ${Utils.durationToString(Duration(seconds: (result.from ?? 0).floor()))} - ${Utils.durationToString(Duration(seconds: (result.to ?? 0).floor()))}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(
    TextTheme textTheme,
    ColorScheme colorScheme,
    String value,
  ) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }


  Widget _buildTips(ColorScheme colorScheme, TextTheme textTheme) {
    final baseStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.5,
    );
    final linkStyle = baseStyle?.copyWith(
      color: colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: colorScheme.primary,
    );
    final dotColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    final tips = <Widget>[
      Text('仅支持使用原始比例番剧截图搜索结果', style: baseStyle),
      Text('截图应清晰，避免过度压缩或添加水印', style: baseStyle),
      RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: '搜索引擎由 '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('https://trace.moe'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text('trace.moe', style: linkStyle),
              ),
            ),
            const TextSpan(text: ' 提供支持'),
          ],
        ),
      ),
    ];

    return  Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '以图搜番',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.map(
            (tipWidget) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: tipWidget),
                ],
              ),
            ),
          ),
        ],
    );
  }
}
