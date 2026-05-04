import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/musical_scale.dart';
import '../models/tuner_reading.dart';
import '../models/tuner_recording.dart';
import '../services/tuner_service.dart';

class TunerController extends ChangeNotifier {
  TunerController(this._tunerService);

  final TunerService _tunerService;

  bool isRunning = false;
  bool isBusy = false;
  String? errorMessage;
  TunerReading? reading;

  final List<TunerReading> _history = [];
  List<TunerReading> get history => List.unmodifiable(_history);

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

  final List<TunerRecording> _recordings = [];
  List<TunerRecording> get recordings => List.unmodifiable(_recordings);

  StreamSubscription<TunerReading>? _readingSubscription;
  Timer? _playbackTimer;
  int _playbackStartRealMs = 0;
  int _playbackPausedOffset = 0;

  MusicalScale _scale = const MusicalScale(root: 'C', type: ScaleType.major);
  MusicalScale get scale => _scale;

  int _centerMidi = 72;
  int get centerMidi => _centerMidi;

  final List<TunerReading> _loadedRecordingHistory = [];
  List<TunerReading> get loadedRecordingHistory =>
      List.unmodifiable(_loadedRecordingHistory);
  String? _loadedRecordingPath;

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
      await _tunerService.start();
      isRunning = true;
    } on TunerException catch (error) {
      errorMessage = error.message;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void _listenToReadings() {
    _readingSubscription?.cancel();
    _readingSubscription = _tunerService.readings.listen((value) {
      reading = value;
      if (isRecordingPaused) {
        notifyListeners();
        return;
      }
      if (value.hasPitch) {
        final adjusted = _totalPauseOffsetMs > 0
            ? TunerReading(
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
      await _tunerService.pauseRecording();
      isRecordingPaused = true;
      _pauseStartMs = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();
    } on TunerException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> resumeRecording() async {
    if (!isRunning || !isRecordingPaused) return;
    try {
      await _tunerService.resumeRecording();
      isRecordingPaused = false;
      _totalPauseOffsetMs +=
          DateTime.now().millisecondsSinceEpoch - _pauseStartMs;
      notifyListeners();
    } on TunerException catch (error) {
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
      final historyToSave = List<TunerReading>.from(_history);
      latestRecordingPath = await _tunerService.stop();
      isRunning = false;
      if (latestRecordingPath != null && historyToSave.isNotEmpty) {
        _savePitchHistory(latestRecordingPath!, historyToSave);
        await loadRecordings();
      }
    } on TunerException catch (error) {
      errorMessage = error.message;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void _savePitchHistory(String wavPath, List<TunerReading> history) {
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
      debugPrint('TunerController._savePitchHistory error: $e');
    }
  }

  List<TunerReading> _loadPitchHistory(String wavPath) {
    try {
      final jsonPath = wavPath.replaceAll('.wav', '.json');
      final file = File(jsonPath);
      if (!file.existsSync()) return [];
      final list = jsonDecode(file.readAsStringSync()) as List;
      return list.map((item) {
        final m = Map<String, Object?>.from(item as Map);
        return TunerReading.fromMap(m);
      }).toList();
    } catch (e) {
      debugPrint('TunerController._loadPitchHistory error: $e');
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
      _recordings.clear();
      _recordings.addAll(await _tunerService.listRecordings());
      notifyListeners();
    } on TunerException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> deleteRecording(String path) async {
    try {
      await _tunerService.deleteRecording(path);
      try {
        final jsonPath = path.replaceAll('.wav', '.json');
        final file = File(jsonPath);
        if (file.existsSync()) file.deleteSync();
      } catch (e) {
        debugPrint('TunerController.deleteRecording json cleanup error: $e');
      }
      _recordings.removeWhere((r) => r.path == path);
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
    } on TunerException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> playRecording(String path) async {
    try {
      await _tunerService.stopPlayback();
      _stopPlaybackTimer();

      _loadedRecordingHistory.clear();
      _loadedRecordingPath = path;
      final history = _loadPitchHistory(path);
      _loadedRecordingHistory.addAll(history);

      final name = await _tunerService.playRecording(path);
      playingPath = path;
      playingName = name;
      isPlaying = true;
      isPaused = false;
      _playbackPositionMs = 0;
      _playbackPausedOffset = 0;
      _startPlaybackTimer();
      notifyListeners();
    } on TunerException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> pausePlayingRecording() async {
    if (!isPlaying || isPaused) return;
    try {
      await _tunerService.pausePlayback();
      _playbackPausedOffset = _playbackPositionMs;
      _stopPlaybackTimer();
      isPaused = true;
      notifyListeners();
    } on TunerException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> resumePlayingRecording() async {
    if (!isPlaying || !isPaused) return;
    try {
      await _tunerService.resumePlayback();
      _playbackStartRealMs =
          DateTime.now().millisecondsSinceEpoch - _playbackPausedOffset;
      _resumeTimerOnly();
      isPaused = false;
      notifyListeners();
    } on TunerException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> seekPlayback(int positionMs) async {
    if (!isPlaying) return;
    try {
      await _tunerService.seekPlayback(positionMs);
      _playbackStartRealMs = DateTime.now().millisecondsSinceEpoch - positionMs;
      _playbackPositionMs = positionMs;
      if (isPaused) {
        _playbackPausedOffset = positionMs;
      }
      notifyListeners();
    } on TunerException catch (error) {
      errorMessage = error.message;
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _tunerService.stopPlayback();
      _stopPlaybackTimer();
      playingPath = null;
      playingName = null;
      isPlaying = false;
      isPaused = false;
      _playbackPositionMs = 0;
      _loadedRecordingHistory.clear();
      _loadedRecordingPath = null;
      notifyListeners();
    } on TunerException catch (error) {
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
    unawaited(_tunerService.stop());
    unawaited(_tunerService.stopPlayback());
    _readingSubscription?.cancel();
    super.dispose();
  }
}
