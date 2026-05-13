import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/practice_controller.dart';

class DailyReadEditScreen extends StatefulWidget {
  const DailyReadEditScreen({super.key});

  @override
  State<DailyReadEditScreen> createState() => _DailyReadEditScreenState();
}

class _DailyReadEditScreenState extends State<DailyReadEditScreen> {
  final _textController = TextEditingController();

  late final PracticeController _practiceController;
  Timer? _autoSaveTimer;
  bool _loaded = false;
  bool _hydrating = false;
  bool _formattingText = false;
  bool _saving = false;
  bool _saveAgain = false;
  String? _lastSavedText;

  static const _autoSaveDelay = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;

    _practiceController = context.read<PracticeController>();
    final text = _editingText(_practiceController.dailyRead);

    _hydrating = true;
    _textController.text = text;
    _textController.selection = TextSelection.collapsed(offset: text.length);
    _lastSavedText = PracticeController.normalizeIndentedLines(
      text,
      PracticeController.dailyReadFirstLineIndent,
    );
    _hydrating = false;
    _loaded = true;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    if (_loaded && !_hydrating) {
      unawaited(_saveNow());
    }
    _textController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (_hydrating || _formattingText) return;

    _formatText();
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, () {
      unawaited(_saveNow());
    });
  }

  void _formatText() {
    final text = _textController.text;
    final nextText = PracticeController.formatIndentedLinesForEditing(
      text,
      PracticeController.dailyReadFirstLineIndent,
    );
    if (nextText == text) return;

    final cursorOffset = _formattedOffset(
      text,
      _textController.selection.extentOffset,
    );
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

  int _formattedOffset(String text, int offset) {
    if (offset < 0) {
      return PracticeController.formatIndentedLinesForEditing(
        text,
        PracticeController.dailyReadFirstLineIndent,
      ).length;
    }

    final safeOffset = offset.clamp(0, text.length);
    return PracticeController.formatIndentedLinesForEditing(
      text.substring(0, safeOffset),
      PracticeController.dailyReadFirstLineIndent,
    ).length;
  }

  Future<void> _saveNow() async {
    if (_saving) {
      _saveAgain = true;
      return;
    }

    _saving = true;

    try {
      do {
        _saveAgain = false;
        final text = PracticeController.normalizeIndentedLines(
          _textController.text,
          PracticeController.dailyReadFirstLineIndent,
        );
        if (_lastSavedText == text) continue;

        await _practiceController.saveDailyRead(text);
        _lastSavedText = text;
      } while (_saveAgain);
    } finally {
      _saving = false;
    }
  }

  String _editingText(String text) {
    final normalized = PracticeController.normalizeIndentedLines(
      text,
      PracticeController.dailyReadFirstLineIndent,
    );
    if (normalized.isEmpty) {
      return PracticeController.dailyReadFirstLineIndent;
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PracticeController>();
    final fontSize = controller.dailyReadFontSize;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('每日必读'),
        actions: [
          IconButton(
            tooltip: '缩小字体',
            onPressed: fontSize > PracticeController.dailyReadMinFontSize
                ? () => context
                      .read<PracticeController>()
                      .changeDailyReadFontSize(-1)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Center(
            child: Text(
              fontSize.round().toString(),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          IconButton(
            tooltip: '放大字体',
            onPressed: fontSize < PracticeController.dailyReadMaxFontSize
                ? () => context
                      .read<PracticeController>()
                      .changeDailyReadFontSize(1)
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: const _DailyReadHeader(),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    colorScheme.primary.withValues(alpha: 0.025),
                    colorScheme.surface,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PaperTitle(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        autofocus: true,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        textAlignVertical: TextAlignVertical.top,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: fontSize,
                          height: 1.68,
                        ),
                        cursorColor: colorScheme.primary,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          hintText: '写下练习前提醒、长期注意事项或练习原则。',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.72,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyReadHeader extends StatelessWidget {
  const _DailyReadHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(
              Icons.menu_book_outlined,
              color: colorScheme.primary,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '每日必读',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '练习前提醒 · 长期原则',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperTitle extends StatelessWidget {
  const _PaperTitle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.edit_note_rounded, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '提醒内容',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
