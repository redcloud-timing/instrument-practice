import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/practice_controller.dart';

class DayDetailScreen extends StatefulWidget {
  const DayDetailScreen({super.key, required this.date});

  final DateTime date;

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  final _minutesController = TextEditingController();
  final _noteController = TextEditingController();

  late final PracticeController _practiceController;
  Timer? _autoSaveTimer;
  bool _loaded = false;
  bool _hydrating = false;
  bool _formattingNote = false;
  bool _saving = false;
  bool _saveAgain = false;
  int? _lastSavedDurationSeconds;
  String? _lastSavedNote;
  String _lastEditingNote = '';

  static const _autoSaveDelay = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _minutesController.addListener(_scheduleAutoSave);
    _noteController.addListener(_handleNoteChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_loaded) return;

    _practiceController = context.read<PracticeController>();
    final log = _practiceController.logForDate(widget.date);
    final minutes = ((log?.durationSeconds ?? 0) / 60).round();

    _hydrating = true;
    _minutesController.text = minutes.toString();
    _noteController.text = _editingNoteText(log?.note ?? '');
    _noteController.selection = TextSelection.collapsed(
      offset: _noteController.text.length,
    );
    _lastEditingNote = _noteController.text;
    _lastSavedDurationSeconds = minutes * 60;
    _lastSavedNote = log?.note ?? '';
    _hydrating = false;
    _loaded = true;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    if (_loaded && !_hydrating) {
      unawaited(_saveNow());
    }
    _minutesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _scheduleAutoSave() {
    if (!_loaded || _hydrating) return;

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, () {
      unawaited(_saveNow());
    });
  }

  void _handleNoteChanged() {
    if (_hydrating || _formattingNote) return;

    final insertedLineIndent = _insertNoteIndentAfterNewLine();
    if (!insertedLineIndent) {
      _formatNoteText();
    }
    _lastEditingNote = _noteController.text;
    _scheduleAutoSave();
  }

  bool _insertNoteIndentAfterNewLine() {
    final text = _noteController.text;
    final cursorOffset = _noteController.selection.extentOffset;
    if (!_isSingleNoteNewLineInsertion(text, cursorOffset)) return false;

    const indent = PracticeController.practiceNoteFirstLineIndent;
    final nextText = text.replaceRange(cursorOffset, cursorOffset, indent);

    _formattingNote = true;
    _noteController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursorOffset + indent.length),
      composing: TextRange.empty,
    );
    _formattingNote = false;
    return true;
  }

  bool _isSingleNoteNewLineInsertion(String text, int cursorOffset) {
    if (cursorOffset <= 0 || cursorOffset > text.length) return false;
    if (text.codeUnitAt(cursorOffset - 1) != 10) return false;
    if (text.length != _lastEditingNote.length + 1) return false;

    return _newLineCount(text) == _newLineCount(_lastEditingNote) + 1;
  }

  int _newLineCount(String text) {
    return '\n'.allMatches(text).length;
  }

  void _formatNoteText() {
    final text = _noteController.text;
    final nextText = PracticeController.formatIndentedLinesForEditing(
      text,
      PracticeController.practiceNoteFirstLineIndent,
    );
    if (nextText == text) return;

    final cursorOffset = _formattedNoteOffset(
      text,
      _noteController.selection.extentOffset,
    );
    _formattingNote = true;
    _noteController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: cursorOffset.clamp(0, nextText.length),
      ),
      composing: TextRange.empty,
    );
    _formattingNote = false;
  }

  int _formattedNoteOffset(String text, int offset) {
    if (offset < 0) {
      return PracticeController.formatIndentedLinesForEditing(
        text,
        PracticeController.practiceNoteFirstLineIndent,
      ).length;
    }

    final safeOffset = offset.clamp(0, text.length);
    return PracticeController.formatIndentedLinesForEditing(
      text.substring(0, safeOffset),
      PracticeController.practiceNoteFirstLineIndent,
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

        final durationSeconds = _durationSecondsForSave();
        if (durationSeconds == null) return;

        final note = PracticeController.normalizePracticeNote(
          _noteController.text,
        );
        if (_lastSavedDurationSeconds == durationSeconds &&
            _lastSavedNote == note) {
          continue;
        }

        await _practiceController.saveLogForDate(
          date: widget.date,
          durationSeconds: durationSeconds,
          note: note,
        );

        _lastSavedDurationSeconds = durationSeconds;
        _lastSavedNote = note;
      } while (_saveAgain);
    } finally {
      _saving = false;
    }
  }

  int? _durationSecondsForSave() {
    final text = _minutesController.text.trim();
    if (text.isEmpty) return _lastSavedDurationSeconds ?? 0;

    final minutes = int.tryParse(text);
    if (minutes == null || minutes < 0) return null;
    return minutes * 60;
  }

  String _editingNoteText(String note) {
    final normalized = PracticeController.normalizePracticeNote(note);
    if (normalized.isEmpty) {
      return PracticeController.practiceNoteFirstLineIndent;
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PracticeController>();
    final fontSize = controller.practiceNoteFontSize;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('练习记录'),
        actions: [
          IconButton(
            tooltip: '缩小字体',
            onPressed: fontSize > PracticeController.practiceNoteMinFontSize
                ? () => context
                      .read<PracticeController>()
                      .changePracticeNoteFontSize(-1)
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
            onPressed: fontSize < PracticeController.practiceNoteMaxFontSize
                ? () => context
                      .read<PracticeController>()
                      .changePracticeNoteFontSize(1)
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
              child: _RecordHeader(
                date: widget.date,
                minutesController: _minutesController,
              ),
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
                    const _NotebookTitle(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: TextField(
                        controller: _noteController,
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
                          hintText: '例如：长音气息更稳了，但高音区还需要慢练。',
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

class _RecordHeader extends StatelessWidget {
  const _RecordHeader({required this.date, required this.minutesController});

  final DateTime date;
  final TextEditingController minutesController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${date.month}月${date.day}日',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${date.year}年 · ${_weekday(date.weekday)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _DurationEditor(controller: minutesController),
          ],
        ),
      ),
    );
  }

  String _weekday(int weekday) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[weekday - 1];
  }
}

class _NotebookTitle extends StatelessWidget {
  const _NotebookTitle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.edit_note_rounded, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '今日笔记',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DurationEditor extends StatelessWidget {
  const _DurationEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
        child: SizedBox(
          width: 86,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.end,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              isDense: true,
              suffixText: ' 分钟',
              suffixStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
