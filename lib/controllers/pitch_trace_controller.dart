import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/musical_scale.dart';
import '../models/pitch_reading.dart';
import '../models/pitch_trace_recording.dart';
import '../services/database_service.dart';
import '../services/pitch_trace_service.dart';

class PitchTraceController extends ChangeNotifier {
  PitchTraceController(this._databaseService, this._pitchTraceService);

  static const _settingsKey = 'pitch_trace_settings_v1';
  static const _recordingMetadataKey = 'pitch_trace_recording_metadata_v1';
  static const defaultMinFrequency = 80.0;
  static const defaultMaxFrequency = 2200.0;
  static const minAllowedFrequency = 80.0;
  static const maxAllowedFrequency = 2600.0;
  static const defaultVisibleDurationMs = 8000.0;
  static const defaultMidiSpan = 24.0;
  static const visibleDurationStepsMs = [
    3000.0,
    4000.0,
    5000.0,
    6000.0,
    8000.0,
    10000.0,
    12000.0,
    16000.0,
    20000.0,
    24000.0,
    30000.0,
  ];
  static const midiSpanSteps = [12.0, 16.0, 20.0, 24.0, 30.0, 36.0, 48.0];

  final DatabaseService _databaseService;
  final PitchTraceService _pitchTraceService;

  bool isRunning = false;
  bool isBusy = false;
  String? errorMessage;
  PitchReading? reading;

  final List<PitchReading> _history = [];
  List<PitchReading> get history => List.unmodifiable(_history);

  String? latestRecordingPath;
  bool isPlaying = false;
  bool isPaused = false;
  String? playingPath;
  String? playingName;

  bool isRecordingPaused = false;
  int _pauseStartMs = 0;
  int _totalPauseOffsetMs = 0;

  int _playbackPositionMs = 0;
  int get playbackPositionMs => _playbackPositionMs;

  final List<PitchTraceRecording> _recordings = [];
  List<PitchTraceRecording> get recordings => List.unmodifiable(_recordings);

  StreamSubscription<PitchReading>? _readingSubscription;
  Timer? _playbackTimer;
  Timer? _settingsSaveDebounce;
  int _playbackStartRealMs = 0;
  int _playbackPausedOffset = 0;

  double _referenceA4Hz = defaultReferenceA4Hz;
  double get referenceA4Hz => _referenceA4Hz;

  double _minFrequency = defaultMinFrequency;
  double get minFrequency => _minFrequency;

  double _maxFrequency = defaultMaxFrequency;
  double get maxFrequency => _maxFrequency;

  double _visibleDurationMs = defaultVisibleDurationMs;
  double get visibleDurationMs => _visibleDurationMs;

  double _midiSpan = defaultMidiSpan;
  double get midiSpan => _midiSpan;

  MusicalScale _scale = const MusicalScale(root: 'C', type: ScaleType.major);
  MusicalScale get scale => _scale;

  int _centerMidi = 72;
  int get centerMidi => _centerMidi;

  final List<PitchReading> _loadedRecordingHistory = [];
  List<PitchReading> get loadedRecordingHistory =>
      List.unmodifiable(_loadedRecordingHistory);
  String? _loadedRecordingPath;

  final Map<String, _RecordingMetadata> _recordingMetadata = {};

  Future<void> init() async {
    await Future.wait([_loadSettings(), _loadRecordingMetadata()]);
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final rawSettings = await _databaseService.getSetting(_settingsKey);
    if (rawSettings == null) return;

    try {
      final map = jsonDecode(rawSettings) as Map<String, dynamic>;
      _referenceA4Hz = _readDouble(
        map['referenceA4Hz'],
        defaultReferenceA4Hz,
      ).clamp(438.0, 442.0).toDouble();
      var minFrequency = _readDouble(map['minFrequency'], defaultMinFrequency);
      final maxFrequency = _readDouble(
        map['maxFrequency'],
        defaultMaxFrequency,
      );
      if (map['pitchDetectorVersion'] != 2 && minFrequency == 240.0) {
        minFrequency = defaultMinFrequency;
      }
      _applyFrequencyRange(minFrequency, maxFrequency);
      _visibleDurationMs = _nearestStep(
        _readDouble(map['visibleDurationMs'], defaultVisibleDurationMs),
        visibleDurationStepsMs,
      );
      _midiSpan = _nearestStep(
        _readDouble(map['midiSpan'], defaultMidiSpan),
        midiSpanSteps,
      );
    } catch (e) {
      debugPrint('PitchTraceController._loadSettings error: $e');
    }
  }

  Future<void> _saveSettings() async {
    final map = {
      'referenceA4Hz': _referenceA4Hz,
      'minFrequency': _minFrequency,
      'maxFrequency': _maxFrequency,
      'pitchDetectorVersion': 2,
      'visibleDurationMs': _visibleDurationMs,
      'midiSpan': _midiSpan,
    };
    await _databaseService.setSetting(_settingsKey, jsonEncode(map));
  }

  void _scheduleSettingsSave() {
    _settingsSaveDebounce?.cancel();
    _settingsSaveDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_saveSettings());
    });
  }

  void setReferenceA4Hz(double value) {
    final cleanValue = value.clamp(438.0, 442.0).roundToDouble();
    if (cleanValue == _referenceA4Hz) return;
    _referenceA4Hz = cleanValue;
    _scheduleSettingsSave();
    notifyListeners();
  }

  void setFrequencyRange(double minFrequency, double maxFrequency) {
    final previousMin = _minFrequency;
    final previousMax = _maxFrequency;
    _applyFrequencyRange(minFrequency, maxFrequency);
    if (previousMin == _minFrequency && previousMax == _maxFrequency) return;
    _scheduleSettingsSave();
    notifyListeners();
  }

  void resetFrequencyRange() {
    setFrequencyRange(defaultMinFrequency, defaultMaxFrequency);
  }

  void setVisibleDurationMs(double value) {
    final cleanValue = _nearestStep(value, visibleDurationStepsMs);
    if (cleanValue == _visibleDurationMs) return;
    _visibleDurationMs = cleanValue;
    _scheduleSettingsSave();
    notifyListeners();
  }

  void setMidiSpan(double value) {
    final cleanValue = _nearestStep(value, midiSpanSteps);
    if (cleanValue == _midiSpan) return;
    _midiSpan = cleanValue;
    _scheduleSettingsSave();
    notifyListeners();
  }

  void _applyFrequencyRange(double minFrequency, double maxFrequency) {
    final low = minFrequency.clamp(minAllowedFrequency, maxAllowedFrequency);
    final high = maxFrequency.clamp(minAllowedFrequency, maxAllowedFrequency);
    final cleanLow = low < high ? low : high;
    final cleanHigh = high > low ? high : low;
    _minFrequency = cleanLow.roundToDouble();
    _maxFrequency = cleanHigh.roundToDouble();
    if (_maxFrequency - _minFrequency < 50) {
      _maxFrequency = (_minFrequency + 50)
          .clamp(minAllowedFrequency, maxAllowedFrequency)
          .toDouble();
      if (_maxFrequency - _minFrequency < 50) {
        _minFrequency = (_maxFrequency - 50)
            .clamp(minAllowedFrequency, maxAllowedFrequency)
            .toDouble();
      }
    }
  }

  Future<void> toggle() async {
    if (isRunning) {
      await stop();
      return;
    }
    await start();
  }

  Future<void> start() async {
    if (isBusy || isRunning) return;

    isBusy = true;
    errorMessage = null;
    _history.clear();
    _loadedRecordingHistory.clear();
    _loadedRecordingPath = null;
    latestRecordingPath = null;
    isRecordingPaused = false;
    _pauseStartMs = 0;
    _totalPauseOffsetMs = 0;
    _stopPlaybackTimer();
    notifyListeners();

    try {
      _listenToReadings();
      await _pitchTraceService.start(
        minFrequency: _minFrequency,
        maxFrequency: _maxFrequency,
      );
      isRunning = true;
    } on PitchTraceException catch (error) {
      errorMessage = error.message;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void _listenToReadings() {
    _readingSubscription?.cancel();
    _readingSubscription = _pitchTraceService.readings.listen((value) {
      reading = value;
      if (isRecordingPaused) {
        notifyListeners();
        return;
      }
      if (value.hasPitch) {
        final adjusted = _totalPauseOffsetMs > 0
            ? PitchReading(
                frequency: value.frequency,
                amplitude: value.amplitude,
                clarity: value.clarity,
                timestampMillis: value.timestampMillis - _totalPauseOffsetMs,
              )
            : value;
        _history.add(adjusted);
        final cutoff = adjusted.timestampMillis - 300000;
        _history.removeWhere((r) => r.timestampMillis < cutoff);
      }
      notifyListeners();
    });
  }

  Future<void> pauseRecording() async {
    if (!isRunning || isRecordingPaused) return;
    try {
      await _pitchTraceService.pauseRecording();
      isRecordingPaused = true;
      _pauseStartMs = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();
    } on PitchTraceException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> resumeRecording() async {
    if (!isRunning || !isRecordingPaused) return;
    try {
      await _pitchTraceService.resumeRecording();
      isRecordingPaused = false;
      _totalPauseOffsetMs +=
          DateTime.now().millisecondsSinceEpoch - _pauseStartMs;
      notifyListeners();
    } on PitchTraceException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (isBusy || !isRunning) return;

    isRecordingPaused = false;
    isBusy = true;
    notifyListeners();

    try {
      final historyToSave = List<PitchReading>.from(_history);
      latestRecordingPath = await _pitchTraceService.stop();
      isRunning = false;
      if (latestRecordingPath != null) {
        if (historyToSave.isNotEmpty) {
          _savePitchHistory(latestRecordingPath!, historyToSave);
        }
        await loadRecordings();
      }
    } on PitchTraceException catch (error) {
      errorMessage = error.message;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void _savePitchHistory(String wavPath, List<PitchReading> history) {
    try {
      final jsonPath = wavPath.replaceAll('.wav', '.json');
      final file = File(jsonPath);
      final list = history
          .where((r) => r.hasPitch)
          .map(
            (r) => {
              'frequency': r.frequency,
              'amplitude': r.amplitude,
              'clarity': r.clarity,
              'timestampMillis': r.timestampMillis,
            },
          )
          .toList();
      file.writeAsStringSync(jsonEncode(list));
    } catch (e) {
      debugPrint('PitchTraceController._savePitchHistory error: $e');
    }
  }

  List<PitchReading> _loadPitchHistory(String wavPath) {
    try {
      final jsonPath = wavPath.replaceAll('.wav', '.json');
      final file = File(jsonPath);
      if (!file.existsSync()) return [];
      final list = jsonDecode(file.readAsStringSync()) as List;
      return list.map((item) {
        final m = Map<String, Object?>.from(item as Map);
        return PitchReading.fromMap(m);
      }).toList();
    } catch (e) {
      debugPrint('PitchTraceController._loadPitchHistory error: $e');
      return [];
    }
  }

  Future<void> loadRecordingForDisplay(String path) async {
    _loadedRecordingHistory.clear();
    _loadedRecordingPath = path;
    final history = _loadPitchHistory(path);
    _loadedRecordingHistory.addAll(history);
    notifyListeners();
  }

  void clearLoadedRecording() {
    _loadedRecordingHistory.clear();
    _loadedRecordingPath = null;
    notifyListeners();
  }

  Future<void> loadRecordings() async {
    try {
      await _loadRecordingMetadata();
      final recordings = await _pitchTraceService.listRecordings();
      final activePaths = recordings.map((r) => r.path).toSet();
      _recordingMetadata.removeWhere((path, _) => !activePaths.contains(path));
      _recordings.clear();
      _recordings.addAll(recordings.map(_applyRecordingMetadata));
      await _saveRecordingMetadata();
      notifyListeners();
    } on PitchTraceException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> renameRecording(String path, String title) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return;
    final existing = _recordingMetadata[path] ?? const _RecordingMetadata();
    _recordingMetadata[path] = existing.copyWith(title: cleanTitle);
    _refreshRecordingMetadata(path);
    if (playingPath == path) playingName = cleanTitle;
    await _saveRecordingMetadata();
    notifyListeners();
  }

  Future<void> saveRecordingNote(String path, String note) async {
    final existing = _recordingMetadata[path] ?? const _RecordingMetadata();
    _recordingMetadata[path] = existing.copyWith(note: note.trim());
    _refreshRecordingMetadata(path);
    await _saveRecordingMetadata();
    notifyListeners();
  }

  String recordingDisplayName(String path, {String? fallback}) {
    final title = _recordingMetadata[path]?.title.trim();
    if (title != null && title.isNotEmpty) return title;
    for (final recording in _recordings) {
      if (recording.path == path) {
        return fallback ?? recording.name;
      }
    }
    return fallback ?? path.split('/').last;
  }

  String recordingNote(String path) {
    return _recordingMetadata[path]?.note ?? '';
  }

  PitchTraceRecording _applyRecordingMetadata(PitchTraceRecording recording) {
    final metadata = _recordingMetadata[recording.path];
    if (metadata == null) return recording;
    return recording.copyWith(title: metadata.title, note: metadata.note);
  }

  void _refreshRecordingMetadata(String path) {
    final index = _recordings.indexWhere((r) => r.path == path);
    if (index < 0) return;
    _recordings[index] = _applyRecordingMetadata(_recordings[index]);
  }

  Future<void> _loadRecordingMetadata() async {
    final rawMetadata = await _databaseService.getSetting(
      _recordingMetadataKey,
    );
    if (rawMetadata == null) return;

    try {
      final decoded = jsonDecode(rawMetadata) as Map<String, dynamic>;
      _recordingMetadata
        ..clear()
        ..addAll(
          decoded.map((path, value) {
            final map = Map<String, dynamic>.from(value as Map);
            return MapEntry(path, _RecordingMetadata.fromJson(map));
          }),
        );
    } catch (e) {
      debugPrint('PitchTraceController._loadRecordingMetadata error: $e');
    }
  }

  Future<void> _saveRecordingMetadata() async {
    final metadata = Map<String, dynamic>.fromEntries(
      _recordingMetadata.entries
          .where(
            (entry) =>
                entry.value.title.trim().isNotEmpty ||
                entry.value.note.trim().isNotEmpty,
          )
          .map((entry) => MapEntry(entry.key, entry.value.toJson())),
    );
    await _databaseService.setSetting(
      _recordingMetadataKey,
      jsonEncode(metadata),
    );
  }

  Future<void> deleteRecording(String path) async {
    try {
      await _pitchTraceService.deleteRecording(path);
      try {
        final jsonPath = path.replaceAll('.wav', '.json');
        final file = File(jsonPath);
        if (file.existsSync()) file.deleteSync();
      } catch (e) {
        debugPrint(
          'PitchTraceController.deleteRecording json cleanup error: $e',
        );
      }
      _recordings.removeWhere((r) => r.path == path);
      if (_recordingMetadata.remove(path) != null) {
        await _saveRecordingMetadata();
      }
      if (_loadedRecordingPath == path) {
        _loadedRecordingHistory.clear();
        _loadedRecordingPath = null;
      }
      if (latestRecordingPath == path) latestRecordingPath = null;
      if (playingPath == path) {
        _stopPlaybackTimer();
        playingPath = null;
        playingName = null;
        isPlaying = false;
        isPaused = false;
        _playbackPositionMs = 0;
      }
      notifyListeners();
    } on PitchTraceException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> playRecording(String path) async {
    try {
      await _pitchTraceService.stopPlayback();
      _stopPlaybackTimer();

      _loadedRecordingHistory.clear();
      _loadedRecordingPath = path;
      final history = _loadPitchHistory(path);
      _loadedRecordingHistory.addAll(history);

      final name = await _pitchTraceService.playRecording(path);
      playingPath = path;
      playingName = recordingDisplayName(path, fallback: name ?? '录音');
      isPlaying = true;
      isPaused = false;
      _playbackPositionMs = 0;
      _playbackPausedOffset = 0;
      _startPlaybackTimer();
      notifyListeners();
    } on PitchTraceException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> pausePlayingRecording() async {
    if (!isPlaying || isPaused) return;
    try {
      await _pitchTraceService.pausePlayback();
      _playbackPausedOffset = _playbackPositionMs;
      _stopPlaybackTimer();
      isPaused = true;
      notifyListeners();
    } on PitchTraceException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> resumePlayingRecording() async {
    if (!isPlaying || !isPaused) return;
    try {
      await _pitchTraceService.resumePlayback();
      _playbackStartRealMs =
          DateTime.now().millisecondsSinceEpoch - _playbackPausedOffset;
      _resumeTimerOnly();
      isPaused = false;
      notifyListeners();
    } on PitchTraceException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> seekPlayback(int positionMs) async {
    if (!isPlaying) return;
    try {
      await _pitchTraceService.seekPlayback(positionMs);
      _playbackStartRealMs = DateTime.now().millisecondsSinceEpoch - positionMs;
      _playbackPositionMs = positionMs;
      if (isPaused) {
        _playbackPausedOffset = positionMs;
      }
      notifyListeners();
    } on PitchTraceException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _pitchTraceService.stopPlayback();
      _stopPlaybackTimer();
      playingPath = null;
      playingName = null;
      isPlaying = false;
      isPaused = false;
      _playbackPositionMs = 0;
      _loadedRecordingHistory.clear();
      _loadedRecordingPath = null;
      notifyListeners();
    } on PitchTraceException catch (error) {
      errorMessage = error.message;
    }
  }

  void _startPlaybackTimer() {
    _stopPlaybackTimer();
    _playbackStartRealMs = DateTime.now().millisecondsSinceEpoch;
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!isPlaying || isPaused) return;
      _playbackPositionMs =
          DateTime.now().millisecondsSinceEpoch - _playbackStartRealMs;
      notifyListeners();
    });
  }

  void _resumeTimerOnly() {
    _stopPlaybackTimer();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!isPlaying || isPaused) return;
      _playbackPositionMs =
          DateTime.now().millisecondsSinceEpoch - _playbackStartRealMs;
      notifyListeners();
    });
  }

  void _stopPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  void setScale(MusicalScale scale) {
    _scale = scale;
    notifyListeners();
  }

  void setCenterMidi(int midi) {
    _centerMidi = midi.clamp(48, 84);
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPlaybackTimer();
    final hasPendingSettingsSave = _settingsSaveDebounce?.isActive ?? false;
    _settingsSaveDebounce?.cancel();
    if (hasPendingSettingsSave) {
      unawaited(_saveSettings());
    }
    unawaited(_pitchTraceService.stop());
    unawaited(_pitchTraceService.stopPlayback());
    _readingSubscription?.cancel();
    super.dispose();
  }
}

double _readDouble(Object? value, double fallback) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return fallback;
}

double _nearestStep(double value, List<double> steps) {
  var best = steps.first;
  var bestDistance = (value - best).abs();
  for (final step in steps.skip(1)) {
    final distance = (value - step).abs();
    if (distance < bestDistance) {
      best = step;
      bestDistance = distance;
    }
  }
  return best;
}

class _RecordingMetadata {
  const _RecordingMetadata({this.title = '', this.note = ''});

  final String title;
  final String note;

  _RecordingMetadata copyWith({String? title, String? note}) {
    return _RecordingMetadata(
      title: title ?? this.title,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'note': note};
  }

  factory _RecordingMetadata.fromJson(Map<String, dynamic> json) {
    return _RecordingMetadata(
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}
