/// 应用全局常量，集中管理共享配置
///
/// 将分散在各模块的公共常量统一收敛到此处，
/// 便于维护和避免重复定义。
class AppConstants {
  AppConstants._();

  // ── 练习记录 ──────────────────────────────────────────
  /// 练习记录数据库表名
  static const practiceLogsTable = 'practice_logs';

  /// 练习计时器状态存储键
  static const timerStartKey = 'active_timer_start_iso';

  /// 首页练习图片存储键
  static const homePracticeImageKey = 'home_practice_image_v1';

  /// 每日阅读内容存储键
  static const dailyReadKey = 'daily_read';

  /// 每日阅读字号存储键
  static const dailyReadFontSizeKey = 'daily_read_font_size';

  /// 练习笔记字号存储键
  static const practiceNoteFontSizeKey = 'practice_note_font_size';

  // ── 字号范围 ──────────────────────────────────────────
  static const minFontSize = 14.0;
  static const maxFontSize = 24.0;
  static const defaultFontSize = 16.0;
  static const firstLineIndent = '　　';

  // ── 节拍 ────────────────────────────────────────────
  /// 节拍设置存储键
  static const metronomeSettingsKey = 'metronome_settings_v4';

  /// 自定义预设名称
  static const customPresetName = '自定义';

  /// 最小 BPM
  static const minBpm = 10;

  /// 最大 BPM
  static const maxBpm = 600;

  /// 最小每拍小节数
  static const minBeatsPerBar = 1;

  /// 最大每拍小节数
  static const maxBeatsPerBar = 8;

  /// 每拍最大细分点数
  static const maxSubdivisionDotsPerBeat = 4;

  // ── 听音 ──────────────────────────────────────────
  /// 听音设置存储键
  static const pitchTraceSettingsKey = 'pitch_trace_settings_v1';

  /// 录音元数据存储键
  static const recordingMetadataKey = 'pitch_trace_recording_metadata_v1';

  /// 默认最小频率 (Hz)
  static const defaultMinFrequency = 80.0;

  /// 默认最大频率 (Hz)
  static const defaultMaxFrequency = 2200.0;

  /// 允许的最小频率 (Hz)
  static const minAllowedFrequency = 80.0;

  /// 允许的最大频率 (Hz)
  static const maxAllowedFrequency = 2600.0;

  /// 默认可见时长 (ms)
  static const defaultVisibleDurationMs = 8000.0;

  /// 默认 MIDI 音域跨度
  static const defaultMidiSpan = 24.0;

  /// 音高历史时间窗口 (ms)，即 5 分钟
  static const historyWindowMs = 300000;

  // ── 资料库 ────────────────────────────────────────────
  /// 资料库存储键
  static const libraryDocumentsKey = 'library_documents_v1';

  /// 资料库最大条目数
  static const maxLibraryItems = 60;

  /// “全部”栏目的排序位置
  static const allCategorySortOrderKey = 'category_all_sort_order';

  /// 默认 PDF 阅读器
  static const defaultPdfViewerKey = 'default_pdf_viewer';

  // ── 主题 ────────────────────────────────────────────
  static const themeColorKey = 'theme_color';
  static const themeModeKey = 'theme_mode';
  static const themeAmbienceKey = 'theme_ambience';
  static const imageRevealStyleKey = 'image_reveal_style';

  // ── 参考音高 ──────────────────────────────────────────
  /// 默认 A4 参考频率 (Hz)
  static const defaultReferenceA4Hz = 440.0;

  /// 允许的 A4 参考频率最小值
  static const minReferenceA4Hz = 438.0;

  /// 允许的 A4 参考频率最大值
  static const maxReferenceA4Hz = 442.0;

  // ── 数据库 ────────────────────────────────────────────
  /// 数据库文件名
  static const databaseName = 'flute_practice.db';

  /// SQLite 结构版本
  static const databaseVersion = 3;
}
