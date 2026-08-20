import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/metronome_preset.dart';
import '../services/database_service.dart';
import '../services/metronome_sound_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_lifecycle_observer.dart';

/// 节拍控制器
///
/// 管理节拍的 BPM、节拍模式、预设和音效。
/// 通过 [DatabaseService] 持久化设置，通过 [MetronomeSoundService] 播放音效。
///
/// 主要功能：
/// - BPM 调节与 Tap Tempo
/// - 节拍模式（强/弱/次强/休止）与细分
/// - 预设管理（保存/加载/删除）
/// - 音效风格切换
/// - 闪光/震动反馈
/// - 后台自动暂停（通过 [attachLifecycleObserver]）
class MetronomeController extends ChangeNotifier {
  MetronomeController(this._databaseService, this._soundService);

  final DatabaseService _databaseService;
  final MetronomeSoundService _soundService;

  static const int minBpm = AppConstants.minBpm;
  static const int maxBpm = AppConstants.maxBpm;
  static const int minBeatsPerBar = AppConstants.minBeatsPerBar;
  static const int maxBeatsPerBar = AppConstants.maxBeatsPerBar;
  static const int maxSubdivisionDotsPerBeat =
      AppConstants.maxSubdivisionDotsPerBeat;
  static const customPresetName = AppConstants.customPresetName;

  bool isLoading = true;
  bool isRunning = false;

  int bpm = 80;
  int currentBeat = 0;
  int currentSubdivision = 0;
  int flashPulse = 0;

  String selectedPresetName = customPresetName;
  List<MetronomePreset> savedPresets = [];
  List<BeatType> beatPattern = [
    BeatType.accent,
    BeatType.normal,
    BeatType.normal,
    BeatType.normal,
  ];
  List<List<BeatType>> subdivisionPatterns = [[], [], [], []];
  MetronomeSoundStyle soundStyle = MetronomeSoundStyle.classic;

  bool flashEnabled = false;
  bool vibrationEnabled = false;

  bool showCometAnimation = false;

  Timer? _ticker;
  Timer? _saveDebounce;
  AppLifecycleObserver? _lifecycleObserver;
  bool _pausedByLifecycle = false;
  final List<DateTime> _tapTempoTimes = [];

  int get beatsPerBar => beatPattern.length;

  int subdivisionCountForBeat(int index) {
    if (index < 0 || index >= subdivisionPatterns.length) return 0;
    return subdivisionPatterns[index].length;
  }

  int totalTicksForBeat(int index) {
    return subdivisionCountForBeat(index) + 1;
  }

  Duration get _currentTickDelay {
    final beatIndex = currentBeat <= 0 ? 0 : currentBeat - 1;
    return Duration(
      milliseconds: (60000 / bpm / totalTicksForBeat(beatIndex)).round(),
    );
  }

  Duration get barDuration {
    var total = 0;
    for (var i = 0; i < beatsPerBar; i++) {
      total += totalTicksForBeat(i);
    }
    if (total == 0) return const Duration(seconds: 1);
    return Duration(milliseconds: (60000 * total / bpm).round());
  }

  void toggleCometAnimation() {
    showCometAnimation = !showCometAnimation;
    notifyListeners();
  }

  Future<void> init() async {
    final rawSettings = await _databaseService.getSetting(
      AppConstants.metronomeSettingsKey,
    );

    if (rawSettings != null) {
      try {
        final map = jsonDecode(rawSettings) as Map<String, dynamic>;
        _loadFromMap(map);
      } catch (e) {
        debugPrint('MetronomeController.init error: $e');
        selectedPresetName = customPresetName;
      }
    }

    isLoading = false;
    notifyListeners();
  }

  void setBpm(int value) {
    final cleanValue = value.clamp(minBpm, maxBpm).toInt();
    if (cleanValue == bpm) return;

    bpm = cleanValue;
    if (isRunning) {
      _scheduleNextTick();
    }
    _markChanged();
  }

  void changeBpm(int delta) {
    setBpm(bpm + delta);
  }

  void recordTapTempo() {
    final now = DateTime.now();

    _tapTempoTimes.removeWhere(
      (time) => now.difference(time) > const Duration(seconds: 3),
    );
    _tapTempoTimes.add(now);

    if (_tapTempoTimes.length < 2) return;
    if (_tapTempoTimes.length > 5) {
      _tapTempoTimes.removeAt(0);
    }

    final intervals = <int>[];
    for (var i = 1; i < _tapTempoTimes.length; i++) {
      intervals.add(
        _tapTempoTimes[i].difference(_tapTempoTimes[i - 1]).inMilliseconds,
      );
    }

    final averageMs =
        intervals.reduce((value, element) => value + element) /
        intervals.length;
    if (averageMs <= 0) return;

    setBpm((60000 / averageMs).round());
  }

  void applyPreset(MetronomePreset preset) {
    _applyPreset(preset, shouldSave: true);
  }

  Future<void> saveCurrentPreset(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return;

    final preset = MetronomePreset(
      name: name,
      bpm: bpm,
      beats: List<BeatType>.of(beatPattern),
      subdivisionBeats: _copySubdivisionPatterns(subdivisionPatterns),
    );

    savedPresets = [
      for (final item in savedPresets)
        if (item.name != name) item,
      preset,
    ];
    selectedPresetName = name;

    notifyListeners();
    await _saveSettings();
  }

  Future<void> deletePreset(String name) async {
    savedPresets = [
      for (final item in savedPresets)
        if (item.name != name) item,
    ];

    if (selectedPresetName == name) {
      selectedPresetName = customPresetName;
    }

    notifyListeners();
    await _saveSettings();
  }

  void setBeatCount(int value) {
    final cleanValue = value.clamp(minBeatsPerBar, maxBeatsPerBar).toInt();
    if (cleanValue == beatsPerBar) return;

    if (cleanValue > beatsPerBar) {
      beatPattern = [
        ...beatPattern,
        for (var i = beatsPerBar; i < cleanValue; i++) BeatType.normal,
      ];
      subdivisionPatterns = [
        ...subdivisionPatterns,
        for (var i = subdivisionPatterns.length; i < cleanValue; i++)
          <BeatType>[],
      ];
    } else {
      beatPattern = beatPattern.take(cleanValue).toList();
      subdivisionPatterns = subdivisionPatterns.take(cleanValue).toList();
    }

    _ensureValidPattern();
    currentBeat = math.min(currentBeat, beatsPerBar);
    currentSubdivision = _clampCurrentSubdivision();
    selectedPresetName = customPresetName;
    _markChanged();
  }

  void cycleBeatAt(int index) {
    if (index < 0 || index >= beatPattern.length) return;

    beatPattern = [
      for (var i = 0; i < beatPattern.length; i++)
        if (i == index) beatPattern[i].next else beatPattern[i],
    ];

    _ensureValidPattern();
    selectedPresetName = customPresetName;
    _markChanged();
  }

  void addSubdivisionDotAt(int beatIndex) {
    if (beatIndex < 0 || beatIndex >= subdivisionPatterns.length) return;

    final currentDots = subdivisionPatterns[beatIndex];
    if (currentDots.length >= maxSubdivisionDotsPerBeat) return;

    subdivisionPatterns = [
      for (var i = 0; i < subdivisionPatterns.length; i++)
        if (i == beatIndex)
          [...subdivisionPatterns[i], BeatType.normal]
        else
          List<BeatType>.of(subdivisionPatterns[i]),
    ];

    if (isRunning && currentBeat == beatIndex + 1) {
      _scheduleNextTick();
    }
    selectedPresetName = customPresetName;
    _markChanged();
  }

  void removeSubdivisionDotAt(int beatIndex) {
    if (beatIndex < 0 || beatIndex >= subdivisionPatterns.length) return;

    final currentDots = subdivisionPatterns[beatIndex];
    if (currentDots.isEmpty) return;

    subdivisionPatterns = [
      for (var i = 0; i < subdivisionPatterns.length; i++)
        if (i == beatIndex)
          subdivisionPatterns[i].take(currentDots.length - 1).toList()
        else
          List<BeatType>.of(subdivisionPatterns[i]),
    ];

    currentSubdivision = _clampCurrentSubdivision();
    if (isRunning && currentBeat == beatIndex + 1) {
      _scheduleNextTick();
    }
    selectedPresetName = customPresetName;
    _markChanged();
  }

  void cycleSubdivisionDotAt(int beatIndex, int dotIndex) {
    if (beatIndex < 0 || beatIndex >= subdivisionPatterns.length) return;
    if (dotIndex < 0 || dotIndex >= subdivisionPatterns[beatIndex].length) {
      return;
    }

    subdivisionPatterns = [
      for (var beat = 0; beat < subdivisionPatterns.length; beat++)
        if (beat == beatIndex)
          [
            for (var dot = 0; dot < subdivisionPatterns[beat].length; dot++)
              if (dot == dotIndex)
                subdivisionPatterns[beat][dot].next
              else
                subdivisionPatterns[beat][dot],
          ]
        else
          List<BeatType>.of(subdivisionPatterns[beat]),
    ];

    selectedPresetName = customPresetName;
    _markChanged();
  }

  void setSoundStyle(MetronomeSoundStyle value) {
    if (value == soundStyle) return;

    soundStyle = value;
    _markChanged();
  }

  void setFlashEnabled(bool value) {
    if (value == flashEnabled) return;

    flashEnabled = value;
    _markChanged();
  }

  void setVibrationEnabled(bool value) {
    if (value == vibrationEnabled) return;

    vibrationEnabled = value;
    _markChanged();
  }

  void toggle() {
    if (isRunning) {
      stop();
      return;
    }

    start();
  }

  void start() {
    if (isRunning) return;

    isRunning = true;
    currentBeat = 0;
    currentSubdivision = 0;

    _playTick();
  }

  void stop() {
    if (!isRunning) return;

    isRunning = false;
    currentBeat = 0;
    currentSubdivision = 0;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void _applyPreset(MetronomePreset preset, {required bool shouldSave}) {
    bpm = preset.bpm;
    beatPattern = List.of(preset.beats);
    subdivisionPatterns = _copySubdivisionPatterns(preset.subdivisionBeats);
    selectedPresetName = preset.name;
    currentBeat = math.min(currentBeat, beatsPerBar);
    currentSubdivision = _clampCurrentSubdivision();

    if (isRunning) {
      _scheduleNextTick();
    }

    if (shouldSave) {
      _markChanged();
    } else {
      notifyListeners();
    }
  }

  void _scheduleNextTick() {
    _ticker?.cancel();
    if (!isRunning) return;
    _ticker = Timer(_currentTickDelay, _playTick);
  }

  void _playTick() {
    if (!isRunning) return;

    if (currentBeat == 0) {
      currentBeat = 1;
      currentSubdivision = 0;
    } else if (currentSubdivision < subdivisionCountForBeat(currentBeat - 1)) {
      currentSubdivision++;
    } else {
      currentBeat = (currentBeat % beatsPerBar) + 1;
      currentSubdivision = 0;
    }

    final role = _currentSoundRole();
    if (role == MetronomeSoundRole.downbeat) {
      flashPulse++;
    }

    notifyListeners();

    unawaited(
      _soundService.playTick(
        role: role,
        soundStyle: soundStyle,
        vibrate: vibrationEnabled && role != MetronomeSoundRole.rest,
      ),
    );

    _scheduleNextTick();
  }

  MetronomeSoundRole _currentSoundRole() {
    if (currentBeat <= 0) return MetronomeSoundRole.rest;

    if (currentSubdivision == 0) {
      return _roleForBeatType(beatPattern[currentBeat - 1], mainBeat: true);
    }

    final dots = subdivisionPatterns[currentBeat - 1];
    final dotIndex = currentSubdivision - 1;
    if (dotIndex < 0 || dotIndex >= dots.length) {
      return MetronomeSoundRole.rest;
    }

    return _roleForBeatType(dots[dotIndex], mainBeat: false);
  }

  MetronomeSoundRole _roleForBeatType(BeatType type, {required bool mainBeat}) {
    switch (type) {
      case BeatType.accent:
        return MetronomeSoundRole.downbeat;
      case BeatType.subaccent:
        return MetronomeSoundRole.upbeat;
      case BeatType.normal:
        return MetronomeSoundRole.subdivision;
      case BeatType.rest:
        return MetronomeSoundRole.rest;
    }
  }

  void _loadFromMap(Map<String, dynamic> map) {
    bpm = (map['bpm'] as int? ?? bpm).clamp(minBpm, maxBpm).toInt();
    selectedPresetName =
        map['selectedPresetName'] as String? ?? selectedPresetName;
    final presetValues = map['savedPresets'];
    if (presetValues is List) {
      savedPresets = [
        for (final value in presetValues)
          if (value is Map)
            _cleanPreset(
              MetronomePreset.fromMap(Map<String, dynamic>.from(value)),
            ),
      ].where((preset) => preset.name.isNotEmpty).toList();
    }
    soundStyle = MetronomeSoundStyle.fromName(map['soundStyle'] as String?);
    flashEnabled = map['flashEnabled'] as bool? ?? flashEnabled;
    vibrationEnabled = map['vibrationEnabled'] as bool? ?? vibrationEnabled;

    final patternValues = map['beatPattern'];
    if (patternValues is List) {
      beatPattern = patternValues
          .map((value) => BeatType.fromValue(value is int ? value : 1))
          .take(maxBeatsPerBar)
          .toList();
    }

    final subdivisionPatternValues = map['subdivisionPatterns'];
    if (subdivisionPatternValues is List) {
      subdivisionPatterns = _parseSubdivisionPatterns(subdivisionPatternValues);
    }

    _ensureValidPattern();
    if (selectedPresetName != customPresetName &&
        !savedPresets.any((preset) => preset.name == selectedPresetName)) {
      selectedPresetName = customPresetName;
    }
  }

  static MetronomePreset _cleanPreset(MetronomePreset preset) {
    final beats = preset.beats.isEmpty
        ? const [BeatType.accent]
        : preset.beats.take(maxBeatsPerBar).toList();
    final dots = _copySubdivisionPatterns(preset.subdivisionBeats)
        .take(beats.length)
        .map((row) => row.take(maxSubdivisionDotsPerBeat).toList())
        .toList();

    return MetronomePreset(
      name: preset.name,
      bpm: preset.bpm.clamp(minBpm, maxBpm).toInt(),
      beats: beats,
      subdivisionBeats: [
        ...dots,
        for (var i = dots.length; i < beats.length; i++) <BeatType>[],
      ],
    );
  }

  static List<List<BeatType>> _parseSubdivisionPatterns(List<dynamic> values) {
    return values.take(maxBeatsPerBar).map((row) {
      if (row is! List) return <BeatType>[];
      return row
          .take(maxSubdivisionDotsPerBeat)
          .map((value) => BeatType.fromValue(value is int ? value : 1))
          .toList();
    }).toList();
  }

  void _ensureValidPattern() {
    if (beatPattern.isEmpty) {
      beatPattern = [BeatType.accent];
    }
    if (beatPattern.length > maxBeatsPerBar) {
      beatPattern = beatPattern.take(maxBeatsPerBar).toList();
    }
    if (subdivisionPatterns.length < beatPattern.length) {
      subdivisionPatterns = [
        ...subdivisionPatterns,
        for (var i = subdivisionPatterns.length; i < beatPattern.length; i++)
          <BeatType>[],
      ];
    }
    if (subdivisionPatterns.length > beatPattern.length) {
      subdivisionPatterns = subdivisionPatterns
          .take(beatPattern.length)
          .toList();
    }
    subdivisionPatterns = [
      for (final dots in subdivisionPatterns)
        dots.take(maxSubdivisionDotsPerBeat).toList(),
    ];
    if (!beatPattern.contains(BeatType.accent)) {
      beatPattern[0] = BeatType.accent;
    }
  }

  int _clampCurrentSubdivision() {
    if (currentBeat <= 0) return 0;
    return math.min(
      currentSubdivision,
      subdivisionCountForBeat(currentBeat - 1),
    );
  }

  void _markChanged() {
    _scheduleSaveSettings();
    notifyListeners();
  }

  void _scheduleSaveSettings() {
    if (isLoading) return;

    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_saveSettings());
    });
  }

  Future<void> _saveSettings() async {
    final map = {
      'bpm': bpm,
      'selectedPresetName': selectedPresetName,
      'savedPresets': savedPresets.map((preset) => preset.toMap()).toList(),
      'beatPattern': beatPattern.map((beat) => beat.value).toList(),
      'subdivisionPatterns': [
        for (final dots in subdivisionPatterns)
          dots.map((beat) => beat.value).toList(),
      ],
      'soundStyle': soundStyle.name,
      'flashEnabled': flashEnabled,
      'vibrationEnabled': vibrationEnabled,
    };

    await _databaseService.setSetting(
      AppConstants.metronomeSettingsKey,
      jsonEncode(map),
    );
  }

  static List<List<BeatType>> _copySubdivisionPatterns(
    List<List<BeatType>> source,
  ) {
    return [for (final row in source) List<BeatType>.of(row)];
  }

  /// 注册 App 生命周期监听，后台时自动暂停节拍
  void attachLifecycleObserver() {
    _lifecycleObserver?.dispose();
    _lifecycleObserver = AppLifecycleObserver(
      onPaused: () {
        if (isRunning) {
          _pausedByLifecycle = true;
          stop();
        }
      },
      onResumed: () {
        if (_pausedByLifecycle) {
          _pausedByLifecycle = false;
          start();
        }
      },
    );
    _lifecycleObserver!.attach();
  }

  @override
  void dispose() {
    _lifecycleObserver?.dispose();
    _ticker?.cancel();
    _saveDebounce?.cancel();
    super.dispose();
  }
}
