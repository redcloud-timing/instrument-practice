import 'package:flute_practice/models/practice_log.dart';
import 'package:flute_practice/services/database_service.dart';

class MockDatabaseService implements DatabaseService {
  final Map<String, String> _settings = {};
  final Map<String, PracticeLog> _logs = {};

  @override
  Future<void> init() async {}

  @override
  Future<List<PracticeLog>> getAllLogs() async {
    return _logs.values.toList()
      ..sort((a, b) => b.practiceDate.compareTo(a.practiceDate));
  }

  @override
  Future<PracticeLog?> getLogByDate(String practiceDate) async {
    return _logs[practiceDate];
  }

  @override
  Future<void> upsertLog({
    required String practiceDate,
    required int durationSeconds,
    required String note,
  }) async {
    final now = DateTime.now().toIso8601String();
    _logs[practiceDate] = PracticeLog(
      id: _logs.length + 1,
      practiceDate: practiceDate,
      durationSeconds: durationSeconds,
      note: note,
      createdAt: _logs[practiceDate]?.createdAt ?? now,
      updatedAt: now,
    );
  }

  @override
  Future<void> addDurationToDate({
    required String practiceDate,
    required int addedSeconds,
  }) async {
    final existing = _logs[practiceDate];
    if (existing == null) {
      await upsertLog(
        practiceDate: practiceDate,
        durationSeconds: addedSeconds,
        note: '',
      );
    } else {
      await upsertLog(
        practiceDate: practiceDate,
        durationSeconds: existing.durationSeconds + addedSeconds,
        note: existing.note,
      );
    }
  }

  @override
  Future<String?> getSetting(String key) async => _settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _settings.remove(key);
  }

  /// 测试辅助：直接注入数据
  void seedLog(PracticeLog log) {
    _logs[log.practiceDate] = log;
  }

  /// 测试辅助：获取已保存的设置
  String? storedSetting(String key) => _settings[key];
}
