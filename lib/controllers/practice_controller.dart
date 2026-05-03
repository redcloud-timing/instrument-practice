import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/practice_log.dart';
import '../services/database_service.dart';
import '../utils/app_date_utils.dart';

class PracticeController extends ChangeNotifier {
  PracticeController(this._databaseService);

  final DatabaseService _databaseService;

  static const _dailyReadKey = 'daily_read';
  static const _timerStartKey = 'active_timer_start_iso';

  bool isLoading = true;
  String dailyRead = '';
  List<PracticeLog> logs = [];

  DateTime? activeTimerStart;
  int elapsedSeconds = 0;

  Timer? _ticker;

  bool get isTimerRunning => activeTimerStart != null;

  Map<String, PracticeLog> get logsByDate {
    return {for (final log in logs) log.practiceDate: log};
  }

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    dailyRead =
        await _databaseService.getSetting(_dailyReadKey) ??
        '练习前先放松肩颈，确认气息稳定。慢练优先，音色优先，速度最后再加。';

    final timerIso = await _databaseService.getSetting(_timerStartKey);
    final parsedTimerStart = timerIso == null
        ? null
        : DateTime.tryParse(timerIso);

    if (parsedTimerStart != null) {
      activeTimerStart = parsedTimerStart;
      _startTicker();
    } else if (timerIso != null) {
      await _databaseService.deleteSetting(_timerStartKey);
    }

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

  Future<void> saveDailyRead(String text) async {
    dailyRead = text.trim();
    await _databaseService.setSetting(_dailyReadKey, dailyRead);
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
      note: note.trim(),
    );

    await reloadLogs();
  }

  Future<void> startTimer() async {
    if (activeTimerStart != null) return;

    activeTimerStart = DateTime.now();
    elapsedSeconds = 0;

    await _databaseService.setSetting(
      _timerStartKey,
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

    await _databaseService.deleteSetting(_timerStartKey);
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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
