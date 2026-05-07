import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/library_item.dart';
import '../models/practice_log.dart';
import '../services/database_service.dart';
import '../utils/app_date_utils.dart';

class PracticeController extends ChangeNotifier {
  PracticeController(this._databaseService);

  final DatabaseService _databaseService;

  static const _dailyReadKey = 'daily_read';
  static const _timerStartKey = 'active_timer_start_iso';
  static const _flowerStateKey = 'flower_state_v1';
  static const _flowerDateKey = 'flower_state_date';
  static const _homePracticeImageKey = 'home_practice_image_v1';
  static const _maxFlowerGrowthStage = 5;
  static const _maxInteractionClicks = 3;

  bool isLoading = true;

  int _flowerGrowthStage = 0;
  int _musicClicks = 0;
  int _waterClicks = 0;
  int _sunClicks = 0;

  int get flowerGrowthStage => _flowerGrowthStage;
  int get musicClicks => _musicClicks;
  int get waterClicks => _waterClicks;
  int get sunClicks => _sunClicks;
  String dailyRead = '';
  LibraryItem? homePracticeImage;
  List<PracticeLog> logs = [];

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

    await _loadFlowerState();
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

  Future<void> saveDailyRead(String text) async {
    dailyRead = text.trim();
    await _databaseService.setSetting(_dailyReadKey, dailyRead);
    notifyListeners();
  }

  Future<void> saveHomePracticeImage(LibraryItem item) async {
    if (!item.isImage) return;
    homePracticeImage = item;
    await _databaseService.setSetting(
      _homePracticeImageKey,
      jsonEncode(item.toMap()),
    );
    notifyListeners();
  }

  Future<void> clearHomePracticeImage() async {
    homePracticeImage = null;
    await _databaseService.deleteSetting(_homePracticeImageKey);
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

  void clickMusic() {
    if (_musicClicks >= _maxInteractionClicks) return;
    _musicClicks++;
    _checkFlowerGrowth();
    _saveFlowerState();
    notifyListeners();
  }

  void clickWater() {
    if (_waterClicks >= _maxInteractionClicks) return;
    _waterClicks++;
    _checkFlowerGrowth();
    _saveFlowerState();
    notifyListeners();
  }

  void clickSun() {
    if (_sunClicks >= _maxInteractionClicks) return;
    _sunClicks++;
    _checkFlowerGrowth();
    _saveFlowerState();
    notifyListeners();
  }

  void _checkFlowerGrowth() {
    if (_musicClicks >= _maxInteractionClicks &&
        _waterClicks >= _maxInteractionClicks &&
        _sunClicks >= _maxInteractionClicks &&
        _flowerGrowthStage < _maxFlowerGrowthStage) {
      _flowerGrowthStage++;
      _musicClicks = 0;
      _waterClicks = 0;
      _sunClicks = 0;
    }
  }

  Future<void> _loadFlowerState() async {
    final today = AppDateUtils.dateKey(DateTime.now());
    final savedDate = await _databaseService.getSetting(_flowerDateKey);

    if (savedDate != today) {
      _flowerGrowthStage = 0;
      _musicClicks = 0;
      _waterClicks = 0;
      _sunClicks = 0;
      await _saveFlowerState();
      return;
    }

    final json = await _databaseService.getSetting(_flowerStateKey);
    if (json != null && json.isNotEmpty) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _flowerGrowthStage = ((map['stage'] as int?) ?? 0)
            .clamp(0, _maxFlowerGrowthStage)
            .toInt();
        _musicClicks = ((map['music'] as int?) ?? 0)
            .clamp(0, _maxInteractionClicks)
            .toInt();
        _waterClicks = ((map['water'] as int?) ?? 0)
            .clamp(0, _maxInteractionClicks)
            .toInt();
        _sunClicks = ((map['sun'] as int?) ?? 0)
            .clamp(0, _maxInteractionClicks)
            .toInt();
      } catch (_) {}
    }
  }

  Future<void> _loadHomePracticeImage() async {
    final json = await _databaseService.getSetting(_homePracticeImageKey);
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

  Future<void> _saveFlowerState() async {
    final data = jsonEncode({
      'stage': _flowerGrowthStage,
      'music': _musicClicks,
      'water': _waterClicks,
      'sun': _sunClicks,
    });
    await _databaseService.setSetting(_flowerStateKey, data);
    await _databaseService.setSetting(
      _flowerDateKey,
      AppDateUtils.dateKey(DateTime.now()),
    );
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
