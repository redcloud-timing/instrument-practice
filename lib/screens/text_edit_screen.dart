import 'dart:async';

import 'package:flutter/material.dart';

class TextEditScreen extends StatefulWidget {
  const TextEditScreen({
    super.key,
    required this.title,
    required this.initialText,
    required this.hintText,
    this.saveLabel = '保存',
    this.minLines = 10,
    this.maxLines,
    this.textInputAction = TextInputAction.newline,
    this.showSaveButton = true,
    this.onTextChanged,
    this.initialFontSize,
    this.onFontSizeChanged,
    this.linePrefix,
  });

  final String title;
  final String initialText;
  final String hintText;
  final String saveLabel;
  final int minLines;
  final int? maxLines;
  final TextInputAction textInputAction;
  final bool showSaveButton;
  final FutureOr<void> Function(String text)? onTextChanged;
  final double? initialFontSize;
  final FutureOr<void> Function(double fontSize)? onFontSizeChanged;
  final String? linePrefix;

  @override
  State<TextEditScreen> createState() => _TextEditScreenState();
}

class _TextEditScreenState extends State<TextEditScreen> {
  late final TextEditingController _textController;
  late double _fontSize;
  bool _formattingText = false;

  bool get _showFontSizeControls => widget.initialFontSize != null;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _fontSize = widget.initialFontSize ?? 16;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final text = _textController.text;

    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    Navigator.pop(context, text);
  }

  void _handleTextChanged(String text) {
    if (_formattingText) return;

    final nextText = _formatIndentedText(text);
    if (nextText != text) {
      final selection = _textController.selection;
      final cursorOffset = _formattedOffset(text, selection.extentOffset);
      _formattingText = true;
      _textController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(
          offset: cursorOffset.clamp(0, nextText.length),
        ),
        composing: TextRange.empty,
      );
      _formattingText = false;
    }

    final onTextChanged = widget.onTextChanged;
    if (onTextChanged == null) return;

    unawaited(Future.sync(() => onTextChanged(_textController.text)));
  }

  String _formatIndentedText(String text) {
    final prefix = widget.linePrefix;
    if (prefix == null) return text;

    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.isEmpty) return '';

    return normalized
        .split('\n')
        .map((line) {
          final content = line.replaceFirst(RegExp(r'^[ \t　]+'), '');
          if (content.isEmpty) return '';
          return '$prefix$content';
        })
        .join('\n');
  }

  int _formattedOffset(String text, int offset) {
    if (offset < 0) return _formatIndentedText(text).length;

    final safeOffset = offset.clamp(0, text.length);
    return _formatIndentedText(text.substring(0, safeOffset)).length;
  }

  void _changeFontSize(double delta) {
    final nextSize = (_fontSize + delta).clamp(14.0, 24.0).toDouble();
    if ((nextSize - _fontSize).abs() < 0.01) return;

    setState(() {
      _fontSize = nextSize;
    });

    final onFontSizeChanged = widget.onFontSizeChanged;
    if (onFontSizeChanged != null) {
      unawaited(Future.sync(() => onFontSizeChanged(nextSize)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_showFontSizeControls) ...[
            IconButton(
              tooltip: '缩小字体',
              onPressed: () => _changeFontSize(-1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Center(
              child: Text(
                _fontSize.round().toString(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            IconButton(
              tooltip: '放大字体',
              onPressed: () => _changeFontSize(1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
          if (widget.showSaveButton)
            TextButton(onPressed: _submit, child: Text(widget.saveLabel)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _textController,
            autofocus: true,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            keyboardType: widget.maxLines == 1
                ? TextInputType.text
                : TextInputType.multiline,
            textInputAction: widget.textInputAction,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: _fontSize, height: 1.55),
            onChanged: _handleTextChanged,
            onSubmitted: widget.textInputAction == TextInputAction.done
                ? (_) => _submit()
                : null,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: widget.hintText,
              alignLabelWithHint: true,
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.showSaveButton
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(widget.saveLabel),
                ),
              ),
            )
          : null,
    );
  }
}
