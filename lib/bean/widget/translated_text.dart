import 'package:flutter/material.dart';
import 'package:kazumi/services/translation/translation_service.dart';

/// A drop-in replacement for [Text] that force-translates dynamic content
/// (e.g. anime titles, summaries from the Bangumi API) to English at display
/// time when the "force English" feature is enabled.
///
/// The original text is shown immediately; once the (cached) translation is
/// available the widget rebuilds with the English text. The underlying data is
/// never mutated.
class TranslatedText extends StatefulWidget {
  const TranslatedText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.textScaler,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final TextScaler? textScaler;

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  late String _display;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _resolve();
    }
  }

  void _resolve() {
    final service = TranslationService.instance;
    if (!service.enabled || !service.needsTranslation(widget.data)) {
      _display = widget.data;
      return;
    }

    final cached = service.cached(widget.data);
    if (cached != null) {
      _display = cached;
      return;
    }

    // Show the original first, then translate asynchronously.
    _display = widget.data;
    final source = widget.data;
    service.translateToEnglish(source).then((translated) {
      if (!mounted || translated == null) return;
      if (widget.data != source) return; // widget recycled to a new value
      if (translated == _display) return;
      setState(() => _display = translated);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _display,
      style: widget.style,
      textAlign: widget.textAlign,
      overflow: widget.overflow,
      maxLines: widget.maxLines,
      softWrap: widget.softWrap,
      textScaler: widget.textScaler,
    );
  }
}
