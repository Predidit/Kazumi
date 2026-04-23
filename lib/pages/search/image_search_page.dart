import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class ImageSearchPage extends StatefulWidget {
  const ImageSearchPage({super.key});

  @override
  State<ImageSearchPage> createState() => _ImageSearchPageState();
}

class _ImageSearchPageState extends State<ImageSearchPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isUrlMode = false;
  String _previewUrl = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    _debounceTimer?.cancel();
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      setState(() => _previewUrl = '');
      return;
    }
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      setState(() => _previewUrl = text);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    super.dispose();
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
            constraints: BoxConstraints(
              maxWidth: LayoutBreakpoint.medium['width']!,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 上传区域
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isUrlMode
                      ? _buildUrlInput(colorScheme, textTheme)
                      : _buildUploadArea(colorScheme, textTheme),
                ),

                const SizedBox(height: 20),

                // 模式切换
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isUrlMode = !_isUrlMode;
                      });
                    },
                    icon: Icon(
                      _isUrlMode ? Icons.upload_file : Icons.link,
                      size: 18,
                    ),
                    label: Text(_isUrlMode ? '改为上传图片文件' : '改为输入图片 URL'),
                  ),
                ),

                const SizedBox(height: 32),

                // 搜索按钮
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.image_search_rounded),
                    label: const Text(
                      '开始搜索',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 提示说明
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
      onTap: () {},
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.4),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
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
        ),
      ),
    );
  }

  Widget _buildUrlInput(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '图片 URL',
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            hintText: '请输入图片链接，例如 https://xxxxxx/image.jpg',
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 13,
            ),
            prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _urlController.clear();
              },
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
        ),
        const SizedBox(height: 12),
        _buildUrlPreview(colorScheme, textTheme),
      ],
    );
  }

  Widget _buildUrlPreview(ColorScheme colorScheme, TextTheme textTheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: 130,
        maxHeight: _previewUrl.isNotEmpty ? 300 : 130,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
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
                if (loadingProgress == null) return child;
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
      Text('使用原始宽高比的截图可获得更准确的结果', style: baseStyle),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: colorScheme.onSurfaceVariant),
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
      ),
    );
  }
}
