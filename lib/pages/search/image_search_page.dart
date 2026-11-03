import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/modules/search/image_search_module.dart';
import 'package:kazumi/pages/search/search_controller.dart';

part 'image_search_widgets.dart';

class ImageSearchPage extends StatefulWidget {
  const ImageSearchPage({super.key, required this.controller});

  final SearchPageController controller;

  @override
  State<ImageSearchPage> createState() => _ImageSearchPageState();
}

class _ImageSearchPageState extends State<ImageSearchPage> {
  final _urlController = TextEditingController();
  final _urlFocus = FocusNode();
  final _pageScroll = ScrollController();
  final _sourceScroll = ScrollController();
  final _resultScroll = ScrollController();
  final _resultsKey = GlobalKey();
  final _picker = ImagePicker();
  Timer? _previewDebounce;
  File? _imageFile;
  String _previewUrl = '';
  String _lastUrlText = '';
  String? _inputError;
  bool _useUrl = false;
  bool _isPicking = false;
  bool _userScrolledDuringSearch = false;

  SearchPageController get _controller => widget.controller;
  bool get _busy => _controller.isImageSearching || _isPicking;
  bool get _hasImage =>
      _useUrl ? _parseHttpUrl(_urlController.text) != null : _imageFile != null;

  Duration get _transition => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _urlController.dispose();
    _urlFocus.dispose();
    _pageScroll.dispose();
    _sourceScroll.dispose();
    _resultScroll.dispose();
    super.dispose();
  }

  void _resetResults() {
    _controller.clearImageSearchState();
    _inputError = null;
  }

  void _onUrlChanged() {
    final value = _urlController.text.trim();
    // Ignore cursor moves so they do not clear active results.
    if (value == _lastUrlText) return;
    _lastUrlText = value;
    _previewDebounce?.cancel();
    setState(() {
      _resetResults();
      _previewUrl = '';
    });
    if (_parseHttpUrl(value) == null) return;
    _previewDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _previewUrl = value);
    });
  }

  void _changeSource(bool useUrl) {
    if (_busy || _useUrl == useUrl) return;
    _previewDebounce?.cancel();
    _urlFocus.unfocus();
    setState(() {
      _useUrl = useUrl;
      _resetResults();
      _previewUrl = _parseHttpUrl(_urlController.text) != null
          ? _urlController.text.trim()
          : '';
    });
  }

  Future<void> _pasteUrl() async {
    if (_busy) return;
    try {
      final text =
          (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
      if (!mounted || _busy || !_useUrl) return;
      if (text == null || text.isEmpty) {
        setState(() => _inputError = '剪贴板里还没有图片链接');
        return;
      }
      _urlController.text = text;
      if (!_hasImage) {
        setState(() => _inputError = '请输入以 https:// 或 http:// 开头的图片链接');
      }
    } catch (_) {
      if (mounted) setState(() => _inputError = '无法读取剪贴板，请手动粘贴链接');
    }
  }

  Future<void> _pickImage() async {
    if (_busy) return;
    setState(() {
      _isPicking = true;
      _inputError = null;
    });
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final file = File(image.path);
      if (await file.length() > 25 * 1024 * 1024) {
        if (mounted) setState(() => _inputError = '图片超过 25 MB，请换一张较小的截图');
        return;
      }
      if (!mounted) return;
      setState(() {
        _resetResults();
        _imageFile = file;
      });
    } catch (_) {
      if (mounted) setState(() => _inputError = '无法读取图片，请重新选择并检查相册权限');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _search() async {
    if (_busy) return;
    if (!_hasImage) {
      setState(() => _inputError = '请输入有效的 HTTP 或 HTTPS 图片链接');
      _urlFocus.requestFocus();
      return;
    }
    _previewDebounce?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _inputError = null;
      _userScrolledDuringSearch = false;
      if (_useUrl) _previewUrl = _urlController.text.trim();
    });
    final search = _useUrl
        ? _controller.searchImageByUrl(_urlController.text.trim())
        : _controller.searchImageByFile(_imageFile!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealResults());
    await search;
    if (mounted && !_userScrolledDuringSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealResults());
    }
  }

  void _revealResults() {
    if (!mounted) return;
    if (_resultScroll.hasClients) {
      if (_transition == Duration.zero) {
        _resultScroll.jumpTo(0);
      } else {
        _resultScroll.animateTo(0,
            duration: _transition, curve: Curves.easeOutCubic);
      }
    } else {
      final resultsContext = _resultsKey.currentContext;
      if (resultsContext != null) {
        Scrollable.ensureVisible(resultsContext,
            duration: _transition, curve: Curves.easeOutCubic);
      }
    }
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Fall through to the shared error message.
    }
    if (!mounted) return;
    KazumiDialog.showToast(context: context, message: '暂时无法打开链接，请稍后再试');
  }

  void _showHelp() {
    KazumiDialog.show<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.image_search_rounded),
        title: const Text('让截图更容易被找到'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Text('使用动画正片截图，保留原始比例。尽量避开黑边、字幕遮挡、水印与拼接画面。'),
              Text('插画、漫画和经过大幅裁剪的图片通常无法匹配。相似度仅供参考，建议对照画面或预览片段确认。'),
              Text('识别由 trace.moe 提供。开始识别后，所选图片或图片链接会发送至该服务。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _openExternal(Uri.parse('https://trace.moe')),
            child: const Text('访问 trace.moe'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: SysAppBar(
        backgroundColor: colors.surface,
        actions: [
          IconButton(
              onPressed: _showHelp,
              tooltip: '搜图小贴士',
              icon: const Icon(Icons.help_outline_rounded)),
        ],
      ),
      body: SafeArea(
        top: false,
        child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (_controller.isImageSearching &&
                  notification.direction != ScrollDirection.idle) {
                _userScrolledDuringSearch = true;
              }
              return false;
            },
            child: LayoutBuilder(
              builder: (context, constraints) => Observer(
                builder: (context) => ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: _buildContent(context, constraints),
                ),
              ),
            )),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BoxConstraints constraints) {
    final window = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final splitLayout = constraints.maxWidth >= 840 ||
        (constraints.maxWidth >= 600 &&
            window.width > window.height &&
            textScale < 1.5);
    final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;
    final searching = _controller.isImageSearching;
    final error = _controller.imageSearchError;
    final results = _controller.imageSearchResults.toList()
      ..sort((a, b) => (b.similarity ?? 0).compareTo(a.similarity ?? 0));
    final showResults = searching || results.isNotEmpty || error.isNotEmpty;
    final short = constraints.maxHeight < 440;
    // Keep the form scrollable when the keyboard consumes most of the height.
    final pinAction =
        splitLayout && (showResults || short) && constraints.maxHeight >= 240;
    final source = _buildSource(context, searching, showResults,
        short: short, inlineAction: !pinAction);
    final resultContent = showResults
        ? _ImageSearchResults(
            results: results,
            searching: searching,
            error: error,
            onRetry: _hasImage ? _search : null,
            onSelect: (title) => context.pop(title),
            onPreview: _openExternal,
          )
        : null;
    if (splitLayout) {
      final contentWidth = constraints.maxWidth.clamp(0.0, 1440.0);
      final inset = (constraints.maxWidth - contentWidth) / 2 + padding;
      // Keep the right gutter inside the viewport for edge scrolling.
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, showResults ? 0 : inset, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 24,
            children: [
              SizedBox(
                width: showResults
                    ? ((constraints.maxWidth - padding * 2 - 24) * .36)
                        .clamp(264.0, 400.0)
                    : (constraints.maxWidth - padding * 2).clamp(0.0, 520.0),
                child: _buildSourcePane(source,
                    action: pinAction ? _buildPrimaryAction(searching) : null),
              ),
              if (resultContent != null)
                Expanded(
                  child: Scrollbar(
                    controller: _resultScroll,
                    child: SingleChildScrollView(
                      key: const PageStorageKey('image-search-results'),
                      controller: _resultScroll,
                      padding: EdgeInsets.only(right: inset, bottom: 8),
                      child: resultContent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Scrollbar(
      controller: _pageScroll,
      child: SingleChildScrollView(
        key: const PageStorageKey('image-search-page'),
        controller: _pageScroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: showResults ? 640 : 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 24,
              children: [
                source,
                if (resultContent != null)
                  SizedBox(key: _resultsKey, child: resultContent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourcePane(Widget source, {Widget? action}) {
    final scrollable = Scrollbar(
      controller: _sourceScroll,
      child: SingleChildScrollView(
        key: const PageStorageKey('image-search-source'),
        controller: _sourceScroll,
        padding: EdgeInsets.only(bottom: action == null ? 0 : 16),
        child: source,
      ),
    );
    // Preserve input focus when the keyboard changes button placement.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
            fit: action == null ? FlexFit.loose : FlexFit.tight,
            child: scrollable),
        if (action != null) action,
      ],
    );
  }

  Widget _buildSource(BuildContext context, bool searching, bool showResults,
      {required bool short, required bool inlineAction}) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final busy = searching || _isPicking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            showResults
                ? '搜索图片'
                : short
                    ? '用截图找到番名'
                    : '这一幕，\n出自哪部番？',
            style:
                (showResults || short ? type.headlineSmall : type.displaySmall)
                    ?.copyWith(
                        fontWeight: FontWeight.w700, color: colors.onSurface),
          ),
        ),
        if (!showResults && !short) ...[
          const SizedBox(height: 8),
          Text('用一张截图，找到番名与出现的集数。',
              style: type.bodyLarge?.copyWith(color: colors.onSurfaceVariant)),
        ],
        SizedBox(height: short ? 12 : 24),
        _ImageSourceSelector(
            useUrl: _useUrl, enabled: !busy, onChanged: _changeSource),
        const SizedBox(height: 16),
        if (_useUrl) ...[
          TextField(
            controller: _urlController,
            focusNode: _urlFocus,
            readOnly: busy,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _search(),
            onTapOutside: (_) => _urlFocus.unfocus(),
            decoration: InputDecoration(
              labelText: '图片链接',
              hintText: 'https://…',
              filled: true,
              fillColor: colors.surfaceContainerLow,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              suffixIcon: IconButton(
                onPressed: busy ? null : _pasteUrl,
                tooltip: '粘贴图片链接',
                icon: const Icon(Icons.content_paste_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('使用可直接访问的 HTTP 或 HTTPS 图片地址',
              style: type.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          if (_previewUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPreview(short: short),
          ],
        ] else ...[
          if (_imageFile != null)
            _buildPreview(short: short)
          else
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: short ? 12 : 24),
              child: short
                  ? Row(children: [
                      const _ImageSearchEmblem(size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text('截图预览',
                              style: type.titleMedium
                                  ?.copyWith(color: colors.onSurfaceVariant))),
                    ])
                  : Column(
                      children: [
                        const _ImageSearchEmblem(size: 72),
                        const SizedBox(height: 12),
                        Text('截图预览',
                            textAlign: TextAlign.center,
                            style: type.titleMedium
                                ?.copyWith(color: colors.onSurfaceVariant)),
                      ],
                    ),
            ),
          const SizedBox(height: 8),
          if (_imageFile != null)
            Row(
              children: [
                Expanded(
                    child: Text(path.basename(_imageFile!.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant))),
                TextButton.icon(
                    onPressed: busy ? null : _pickImage,
                    label: const Text('更换截图'),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 20)),
              ],
            )
          else
            Text('JPG、PNG、WebP · 最大 25 MB',
                textAlign: TextAlign.center,
                style:
                    type.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ],
        if (_inputError != null) ...[
          const SizedBox(height: 12),
          Semantics(
              liveRegion: true,
              child: Text(_inputError!,
                  style: type.bodyMedium?.copyWith(color: colors.error))),
        ],
        const SizedBox(height: 16),
        if (inlineAction) _buildPrimaryAction(searching),
        const SizedBox(height: 12),
        Text('由 trace.moe 识别动画截图',
            textAlign: TextAlign.center,
            style: type.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        if (!showResults && !short) ...[
          const SizedBox(height: 24),
          const _ScreenshotTip(),
        ],
      ],
    );
  }

  Widget _buildPrimaryAction(bool searching) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final busy = searching || _isPicking;
    final selecting = !_useUrl && _imageFile == null;
    return FilledButton.icon(
      key: const ValueKey('image-search-primary'),
      onPressed: busy
          ? null
          : selecting
              ? _pickImage
              : _hasImage
                  ? _search
                  : null,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
        textStyle: WidgetStatePropertyAll(
            type.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        shape: WidgetStateProperty.resolveWith((states) =>
            RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    states.contains(WidgetState.pressed) ? 16 : 28))),
        animationDuration: _transition,
      ),
      icon: searching || _isPicking
          ? LoadingIndicator(size: 24, color: colors.onSurfaceVariant)
          : Icon(_hasImage
              ? Icons.image_search_rounded
              : Icons.add_photo_alternate_outlined),
      label: Text(searching
          ? '正在识别'
          : _isPicking
              ? '正在读取图片'
              : selecting
                  ? '选择截图'
                  : _useUrl
                      ? '开始识别'
                      : '识别这张截图'),
    );
  }

  Widget _buildPreview({required bool short}) {
    final colors = Theme.of(context).colorScheme;
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        const Center(
            child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂时无法预览\n仍可尝试识别，或更换图片', textAlign: TextAlign.center),
        ));
    return Semantics(
      label: '待识别的完整截图',
      image: true,
      child: Container(
        height: short ? 136 : 208,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24)),
        child: _useUrl
            ? Image.network(_previewUrl,
                fit: BoxFit.contain,
                errorBuilder: fallback,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: LoadingIndicator(semanticsLabel: '正在加载截图')))
            : Image.file(_imageFile!,
                fit: BoxFit.contain, errorBuilder: fallback),
      ),
    );
  }
}
