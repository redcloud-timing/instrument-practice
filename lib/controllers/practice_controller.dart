import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/library_item.dart';
import '../models/practice_log.dart';
import '../services/database_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_date_utils.dart';

/// 练习记录管理控制器
///
/// 管理练习计时器、每日日志、花朵成长状态和每日阅读。
/// 通过 [DatabaseService] 持久化数据。
///
/// 主要功能：
/// - 练习计时器启停与自动保存
/// - 每日练习日志查询与编辑
/// - 花朵成长状态机（浇水/听音乐触发成长）
/// - 每日阅读内容管理
class PracticeController extends ChangeNotifier {
  PracticeController(this._databaseService);

  final DatabaseService _databaseService;

  static const dailyReadMinFontSize = AppConstants.minFontSize;
  static const dailyReadMaxFontSize = AppConstants.maxFontSize;
  static const dailyReadDefaultFontSize = AppConstants.defaultFontSize;
  static const dailyReadFirstLineIndent = AppConstants.firstLineIndent;
  static const practiceNoteMinFontSize = AppConstants.minFontSize;
  static const practiceNoteMaxFontSize = AppConstants.maxFontSize;
  static const practiceNoteDefaultFontSize = AppConstants.defaultFontSize;
  static const practiceNoteFirstLineIndent = AppConstants.firstLineIndent;

  bool isLoading = true;

  String dailyRead = '';
  double dailyReadFontSize = dailyReadDefaultFontSize;
  double practiceNoteFontSize = practiceNoteDefaultFontSize;
  LibraryItem? homePracticeImage;
  List<PracticeLog> logs = [];

  Future<void>? _dailyReadPersisting;
  String? _pendingDailyReadToSave;

  DateTime? activeTimerStart;
  int elapsedSeconds = 0;

  Timer? _ticker;

  bool get isTimerRunning => activeTimerStart != null;

  Map<String, PracticeLog> get logsByDate {
    return {for (final log in logs) log.practiceDate: log};
  }

  int get streakDays {
    var streak = 0;
    var current = AppDateUtils.dateKey(DateTime.now());
    final byDate = logsByDate;
    while (byDate.containsKey(current)) {
      streak++;
      final date = DateTime.parse(current);
      current = AppDateUtils.dateKey(date.subtract(const Duration(days: 1)));
    }
    return streak;
  }

  List<int> get pastDaysFlowers {
    final byDate = logsByDate;
    final result = <int>[];
    for (var i = 0; i < 5; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = AppDateUtils.dateKey(date);
      final log = byDate[key];
      if (log == null) {
        result.add(-1);
      } else {
        final mins = log.durationSeconds ~/ 60;
        if (mins >= 120) {
          result.add(4);
        } else if (mins >= 90) {
          result.add(3);
        } else if (mins >= 60) {
          result.add(2);
        } else if (mins >= 30) {
          result.add(1);
        } else {
          result.add(0);
        }
      }
    }
    return result;
  }

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    dailyRead = _normalizeDailyRead(
      await _databaseService.getSetting(AppConstants.dailyReadKey) ??
          '练习前先放松肩颈，确认气息稳定。慢练优先，音色优先，速度最后再加。',
    );

    dailyReadFontSize = _readDailyReadFontSize(
      await _databaseService.getSetting(AppConstants.dailyReadFontSizeKey),
    );
    practiceNoteFontSize = _readPracticeNoteFontSize(
      await _databaseService.getSetting(AppConstants.practiceNoteFontSizeKey),
    );

    final timerIso = await _databaseService.getSetting(
      AppConstants.timerStartKey,
    );
    final parsedTimerStart = timerIso == null
        ? null
        : DateTime.tryParse(timerIso);

    if (parsedTimerStart != null) {
      activeTimerStart = parsedTimerStart;
      _startTicker();
    } else if (timerIso != null) {
      await _databaseService.deleteSetting(AppConstants.timerStartKey);
    }

    await _loadHomePracticeImage();

    logs = await _databaseService.getAllLogs();
    isLoading = false;
    notifyListeners();
  }

  PracticeLog? logForDate(DateTime date) {
    return logsByDate[AppDateUtils.dateKey(date)];
  }

  Future<void> reloadLogs() async {
    logs = await _databaseService.getAllLogs();
    notifyListeners();
  }

  Future<void> saveDailyRead(String text) {
    final nextText = _normalizeDailyRead(text);
    if (dailyRead != nextText) {
      dailyRead = nextText;
      notifyListeners();
    }

    _pendingDailyReadToSave = nextText;
    _dailyReadPersisting ??= _flushDailyRead();
    return _dailyReadPersisting!;
  }

  Future<void> _flushDailyRead() async {
    while (_pendingDailyReadToSave != null) {
      final text = _pendingDailyReadToSave!;
      _pendingDailyReadToSave = null;
      await _databaseService.setSetting(AppConstants.dailyReadKey, text);
    }

    _dailyReadPersisting = null;
  }

  Future<void> changeDailyReadFontSize(double delta) {
    return setDailyReadFontSize(dailyReadFontSize + delta);
  }

  Future<void> setDailyReadFontSize(double fontSize) async {
    final nextSize = _clampDailyReadFontSize(fontSize);
    if ((dailyReadFontSize - nextSize).abs() < 0.01) return;

    dailyReadFontSize = nextSize;
    notifyListeners();

    await _databaseService.setSetting(
      AppConstants.dailyReadFontSizeKey,
      nextSize.toStringAsFixed(0),
    );
  }

  Future<void> changePracticeNoteFontSize(double delta) {
    return setPracticeNoteFontSize(practiceNoteFontSize + delta);
  }

  Future<void> setPracticeNoteFontSize(double fontSize) async {
    final nextSize = _clampPracticeNoteFontSize(fontSize);
    if ((practiceNoteFontSize - nextSize).abs() < 0.01) return;

    practiceNoteFontSize = nextSize;
    notifyListeners();

    await _databaseService.setSetting(
      AppConstants.practiceNoteFontSizeKey,
      nextSize.toStringAsFixed(0),
    );
  }

  Future<void> saveHomePracticeImage(LibraryItem item) async {
    if (!item.isImage) return;
    homePracticeImage = item;
    await _databaseService.setSetting(
      AppConstants.homePracticeImageKey,
      jsonEncode(item.toMap()),
    );
    notifyListeners();
  }

  Future<void> clearHomePracticeImage() async {
    homePracticeImage = null;
    await _databaseService.deleteSetting(AppConstants.homePracticeImageKey);
    notifyListeners();
  }

  Future<void> saveLogForDate({
    required DateTime date,
    required int durationSeconds,
    required String note,
  }) async {
    final cleanSeconds = durationSeconds < 0 ? 0 : durationSeconds;

    await _databaseService.upsertLog(
      practiceDate: AppDateUtils.dateKey(date),
      durationSeconds: cleanSeconds,
      note: normalizePracticeNote(note),
    );

    await reloadLogs();
  }

  Future<void> _loadHomePracticeImage() async {
    final json = await _databaseService.getSetting(
      AppConstants.homePracticeImageKey,
    );
    if (json == null || json.isEmpty) return;

    try {
      final map = jsonDecode(json);
      if (map is Map) {
        final item = LibraryItem.fromMap(Map<String, dynamic>.from(map));
        if (item.isImage && item.uri.isNotEmpty) {
          homePracticeImage = item;
        }
      }
    } catch (_) {}
  }

  Future<void> startTimer() async {
    if (activeTimerStart != null) return;

    activeTimerStart = DateTime.now();
    elapsedSeconds = 0;

    await _databaseService.setSetting(
      AppConstants.timerStartKey,
      activeTimerStart!.toIso8601String(),
    );

    _startTicker();
    notifyListeners();
  }

  Future<int> stopTimerAndSave() async {
    final start = activeTimerStart;
    if (start == null) return 0;

    final seconds = DateTime.now().difference(start).inSeconds;
    final savedSeconds = seconds < 1 ? 1 : seconds;
    final practiceDate = AppDateUtils.dateKey(start);

    activeTimerStart = null;
    elapsedSeconds = 0;
    _ticker?.cancel();

    await _databaseService.deleteSetting(AppConstants.timerStartKey);
    await _databaseService.addDurationToDate(
      practiceDate: practiceDate,
      addedSeconds: savedSeconds,
    );

    logs = await _databaseService.getAllLogs();
    notifyListeners();

    return savedSeconds;
  }

  void _startTicker() {
    _ticker?.cancel();
    _updateElapsed();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateElapsed();
      notifyListeners();
    });
  }

  void _updateElapsed() {
    final start = activeTimerStart;
    if (start == null) {
      elapsedSeconds = 0;
      return;
    }

    final seconds = DateTime.now().difference(start).inSeconds;
    elapsedSeconds = seconds < 0 ? 0 : seconds;
  }

  static String _normalizeDailyRead(String text) {
    return normalizeIndentedLines(text, dailyReadFirstLineIndent);
  }

  static double _readDailyReadFontSize(String? value) {
    return _clampDailyReadFontSize(double.tryParse(value ?? ''));
  }

  static double _clampDailyReadFontSize(double? value) {
    return (value ?? dailyReadDefaultFontSize)
        .clamp(dailyReadMinFontSize, dailyReadMaxFontSize)
        .toDouble();
  }

  static String normalizePracticeNote(String text) {
    return normalizeIndentedLines(text, practiceNoteFirstLineIndent);
  }

  static String normalizeIndentedLines(String text, String indent) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    return formatIndentedLinesForEditing(trimmed, indent);
  }

  static String formatIndentedLinesForEditing(String text, String indent) {
    final normalizedNewLines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    if (normalizedNewLines.isEmpty) return '';

    return normalizedNewLines
        .split('\n')
        .map((line) {
          final content = line
              .replaceFirst(RegExp(r'^[ \t　]+'), '')
              .trimRight();
          if (content.isEmpty) return '';
          return '$indent$content';
        })
        .join('\n');
  }

  static double _readPracticeNoteFontSize(String? value) {
    return _clampPracticeNoteFontSize(double.tryParse(value ?? ''));
  }

  static double _clampPracticeNoteFontSize(double? value) {
    return (value ?? practiceNoteDefaultFontSize)
        .clamp(practiceNoteMinFontSize, practiceNoteMaxFontSize)
        .toDouble();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
