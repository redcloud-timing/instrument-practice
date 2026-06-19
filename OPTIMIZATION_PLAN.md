# Flute Practice App 优化计划

> 基于代码审查的系统性优化方案，分 4 阶段推进，每阶段可独立验收。

---

## 总览

| 阶段 | 主题 | 优先级 | 预估工时 | 风险 |
|------|------|--------|----------|------|
| P0 | 测试基础建设 | 🔴 高 | 3-5 天 | 低 |
| P1 | 耗电与后台生命周期 | 🔴 高 | 2-3 天 | 中 |
| P2 | 性能与内存优化 | ⚠️ 中 | 2-3 天 | 中 |
| P3 | 代码规范与可维护性 | ⚠️ 中 | 2-3 天 | 低 |

---

## P0：测试基础建设 🔴

**目标**：让每次后续优化都有回归保障，避免改一处坏一处。

### 0.1 添加 Mockito 依赖

```yaml
# pubspec.yaml dev_dependencies 中添加
dev_dependencies:
  mockito: ^5.4.4
  build_runner: ^2.4.8
```

### 0.2 Controller 单元测试

为每个 Controller 编写纯 Dart 单元测试，不依赖 Flutter 引擎。

| 测试目标 | 覆盖场景 | 优先级 |
|----------|----------|--------|
| `PracticeController` | 启停计时器、自动保存日志、日期边界（跨天、跨月） | P0 |
| `PracticeController` | 花朵成长状态机（浇水/听音乐点击次数 → 阶段变化） | P1 |
| `MetronomeController` | BPM 边界（10/600）、节拍模式切换、预设保存/加载 | P0 |
| `MetronomeController` | Subdivision 模式（三连音、十六分音符）的 beatPattern 生成 | P1 |
| `PitchTraceController` | 音高历史容量限制（500 条截断）、频率范围设置 | P0 |
| `PitchTraceController` | Recording 元数据的序列化/反序列化 | P1 |
| `LibraryController` | 添加/删除/收藏/搜索/60 条上限 | P0 |
| `ThemeController` | 主题持久化、色值解析 | P2 |

**实现示例**：

```dart
// test/controllers/practice_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:flute_practice/controllers/practice_controller.dart';
import 'package:flute_practice/services/database_service.dart';

@GenerateMocks([DatabaseService])
import 'practice_controller_test.mocks.dart';

void main() {
  late MockDatabaseService mockDb;
  late PracticeController controller;

  setUp(() async {
    mockDb = MockDatabaseService();
    when(mockDb.getSetting(any)).thenAnswer((_) async => null);
    when(mockDb.saveSetting(any, any)).thenAnswer((_) async {});
    when(mockDb.getAllLogs()).thenAnswer((_) async => []);
    
    controller = PracticeController(mockDb);
    await controller.init();
  });

  test('计时器启停', () async {
    expect(controller.isTimerRunning, isFalse);

    await controller.startTimer();
    expect(controller.isTimerRunning, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    final seconds = await controller.stopTimerAndSave();

    expect(seconds, greaterThanOrEqualTo(0));
    expect(controller.isTimerRunning, isFalse);
  });

  test('花朵成长状态：浇水 3 次达到最大阶段', () {
    for (var i = 0; i < 3; i++) {
      controller.waterFlower();
    }
    expect(controller.flowerGrowthStage, equals(5));
  });
}
```

### 0.3 Model 序列化测试

| 测试目标 | 覆盖场景 |
|----------|----------|
| `PracticeLog.fromMap / toMap` | 正常数据、缺失字段默认值、null 安全 |
| `LibraryItem.fromPickedMap` | 原生端返回的各种 Map 格式兼容性 |
| `PitchReading.fromMap` | 频率为 0（无音高）、负数、超大值 |
| `MetronomePreset` JSON 序列化 | `beatPattern` / `subdivisionPatterns` 的边界数组 |

**实现示例**：

```dart
// test/models/pitch_reading_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flute_practice/models/pitch_reading.dart';

void main() {
  group('PitchReading', () {
    test('hasPitch 为 false 当频率为 0', () {
      const reading = PitchReading(
        frequency: 0, amplitude: 0, clarity: 0, timestampMillis: 0,
      );
      expect(reading.hasPitch, isFalse);
      expect(reading.midiNumberFor(440), equals(0));
    });

    test('A4 音高计算正确', () {
      const reading = PitchReading(
        frequency: 440, amplitude: 1, clarity: 1, timestampMillis: 0,
      );
      expect(reading.midiNumberFor(440), equals(69));
      expect(reading.noteNameFor(440), equals('A'));
      expect(reading.centsFor(440), equals(0));
    });

    test('微分音偏差计算', () {
      // A4 + 10 cents ≈ 442.54 Hz
      const reading = PitchReading(
        frequency: 442.54, amplitude: 1, clarity: 1, timestampMillis: 0,
      );
      expect(reading.centsFor(440), closeTo(10, 1));
    });
  });
}
```

### 0.4 静态分析集成

```yaml
# analysis_options.yaml — 替换为更严格的规则集
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_single_quotes
    - avoid_print
    - prefer_const_constructors
    - prefer_const_declarations
    - always_declare_return_types
    - annotate_overrides
    - avoid_unnecessary_containers
    - sized_box_for_whitespace
    - use_build_context_synchronously
```

**验收标准**：
- [ ] `flutter test` 通过，覆盖率 ≥ 60%
- [ ] `flutter analyze` 无 error，warning ≤ 10
- [ ] CI 可配置为每次提交自动运行

---

## P1：耗电与后台生命周期 🔴

**目标**：节拍器和音高轨迹在 App 进入后台时自动暂停，避免无意义耗电。

### 1.1 Controller 注册 AppLifecycleListener

在 `MetronomeController` 和 `PitchTraceController` 中监听生命周期：

```dart
// metronome_controller.dart 新增
import 'dart:ui';

class MetronomeController extends ChangeNotifier {
  // ... 现有代码 ...

  AppLifecycleListener? _lifecycleListener;

  void attachLifecycleObserver() {
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleLifecycleChange,
    );
  }

  void _handleLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (isRunning) {
          _wasPausedByLifecycle = true;
          stop();
        }
      case AppLifecycleState.resumed:
        if (_wasPausedByLifecycle) {
          _wasPausedByLifecycle = false;
          start(); // 恢复节拍器
        }
      default:
        break;
    }
  }

  bool _wasPausedByLifecycle = false;

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _ticker?.cancel();
    super.dispose();
  }
}
```

```dart
// pitch_trace_controller.dart — 同理
void _handleLifecycleChange(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.paused:
    case AppLifecycleState.hidden:
      if (isRunning) {
        _wasPausedByLifecycle = true;
        stop(); // 停止麦克风录音
      }
    case AppLifecycleState.resumed:
      if (_wasPausedByLifecycle) {
        _wasPausedByLifecycle = false;
        start(); // 恢复录音
      }
    default:
      break;
  }
}
```

### 1.2 在 main.dart 中注册

```dart
// main.dart — MyApp 的 State 中
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<MetronomeController>().attachLifecycleObserver();
    context.read<PitchTraceController>().attachLifecycleObserver();
  });
}
```

**验收标准**：
- [ ] 节拍器运行中切换到后台 → 自动停止
- [ ] 从后台恢复 → 自动继续
- [ ] 音高轨迹同理
- [ ] 手动停止后再切后台 → 不会误恢复

---

## P2：性能与内存优化 ⚠️

**目标**：消除高频操作的性能瓶颈，减少 I/O 压力。

### 2.1 音高历史改用 Queue

**问题**：`_history.removeAt(0)` 是 O(n) 操作，在高频采集场景下（每帧一次）性能差。

```dart
// pitch_trace_controller.dart — 修改前
final List<PitchReading> _history = [];
List<PitchReading> get history => List.unmodifiable(_history);

void _addReading(PitchReading reading) {
  _history.add(reading);
  if (_history.length > _maxHistoryLength) {
    _history.removeAt(0); // O(n) — 每次移除都要移动整个数组
  }
}

// pitch_trace_controller.dart — 修改后
import 'dart:collection';

final Queue<PitchReading> _history = Queue();
List<PitchReading> get history => List.unmodifiable(_history);

void _addReading(PitchReading reading) {
  _history.addLast(reading);
  if (_history.length > _maxHistoryLength) {
    _history.removeFirst(); // O(1)
  }
}
```

> 注意：`Queue` 的 `removeFirst()` 不会释放底层数组容量，但由于上限为 500 条，实际影响很小。如果需要更严格的控制，可实现环形缓冲区。

### 2.2 减少 SharedPreferences 写入频率

**问题**：`PracticeController._saveTimerState()` 每秒调用一次 `saveSetting`，对闪存 I/O 不友好。

**方案**：改为 debounce，仅在计时器停止时或 App 进入后台时持久化。

```dart
// practice_controller_controller.dart — 修改前
void _tickTimer() {
  _timerElapsedSeconds++;
  _saveTimerState(); // 每秒写一次 SharedPreferences
  notifyListeners();
}

// practice_controller.dart — 修改后
Timer? _persistDebounce;

void _tickTimer() {
  _timerElapsedSeconds++;
  _schedulePersist();
  notifyListeners();
}

void _schedulePersist() {
  _persistDebounce?.cancel();
  _persistDebounce = Timer(const Duration(seconds: 10), _saveTimerState);
}

Future<int> stopTimerAndSave() async {
  _persistDebounce?.cancel();
  _timer?.cancel();
  // ... 保存逻辑不变
}

@override
void dispose() {
  _persistDebounce?.cancel();
  _timer?.cancel();
  _autoSaveTimer?.cancel();
  super.dispose();
}
```

### 2.3 练习记录分页加载

**问题**：`PracticeController.init()` 加载全部记录到内存，长期用户数据量会持续增长。

```dart
// practice_controller.dart — 新增分页加载
static const _pageSize = 90; // 加载最近 90 天

Future<void> loadMore() async {
  if (_allLoaded) return;
  final offset = practiceLogs.length;
  final page = await _databaseService.getLogsPaged(
    offset: offset,
    limit: _pageSize,
  );
  practiceLogs.addAll(page);
  if (page.length < _pageSize) _allLoaded = true;
  notifyListeners();
}
```

```dart
// database_service.dart — 新增分页查询
Future<List<PracticeLog>> getLogsPaged({
  required int offset,
  required int limit,
}) async {
  final db = await _db;
  final rows = await db.query(
    'practice_logs',
    orderBy: 'practice_date DESC',
    limit: limit,
    offset: offset,
  );
  return rows.map(PracticeLog.fromMap).toList();
}
```

**验收标准**：
- [ ] 音高轨迹记录 500 条后，旧数据正确丢弃，无内存泄漏
- [ ] 计时器运行 10 秒内不触发 SharedPreferences 写入
- [ ] 练习日志首页加载 < 100ms（模拟 365 条数据）

---

## P3：代码规范与可维护性 ⚠️

**目标**：提升代码一致性和可维护性，降低新人上手成本。

### 3.1 集中路由管理

**问题**：所有页面跳转使用 `Navigator.push` 硬编码，路由路径分散。

```dart
// lib/routes/app_router.dart — 新建
class AppRouter {
  static const home = '/';
  static const calendar = '/calendar';
  static const dayDetail = '/calendar/day';
  static const library = '/library';
  static const documentViewer = '/library/viewer';
  static const metronome = '/metronome';
  static const pitchTrace = '/pitch-trace';
  static const themeSettings = '/settings/theme';
  static const textEdit = '/edit/text';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case dayDetail:
        final date = settings.arguments as DateTime;
        return MaterialPageRoute(
          builder: (_) => DayDetailScreen(date: date),
        );
      // ... 其他路由
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('页面不存在')),
          ),
        );
    }
  }
}
```

### 3.2 统一错误处理

```dart
// lib/utils/app_exception.dart — 新建
sealed class AppException implements Exception {
  const AppException(this.message, {this.technical});
  final String message;
  final Object? technical;
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.technical});
}

class PlatformChannelException extends AppException {
  const PlatformChannelException(super.message, {super.technical});
}

class PitchTraceException extends AppException {
  const PitchTraceException(super.message, {super.technical});
}
```

```dart
// lib/utils/error_handler.dart — 新建
void handleAppError(BuildContext context, AppException error) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(error.message),
      action: SnackBarAction(
        label: '详情',
        onPressed: () => _showErrorDialog(context, error),
      ),
    ),
  );
  
  // 开发模式下打印技术细节
  if (kDebugMode && error.technical != null) {
    debugPrint('AppException: ${error.technical}');
  }
}
```

### 3.3 抽取魔法数字为常量

```dart
// lib/utils/app_constants.dart — 新建
class AppConstants {
  // 练习记录
  static const maxPracticeLogs = 365 * 3; // 最多保留 3 年
  static const timerPersistDebounceSeconds = 10;
  static const autoSaveDelayMs = 250;
  
  // 音高轨迹
  static const maxPitchHistoryLength = 500;
  static const defaultMinFrequency = 80.0;
  static const defaultMaxFrequency = 2200.0;
  
  // 资料库
  static const maxLibraryItems = 60;
  
  // 节拍器
  static const minBpm = 10;
  static const maxBpm = 600;
}
```

### 3.4 补充 dartdoc 注释

对所有公共 API 添加文档注释，至少覆盖：

- Controller 类及其公共方法
- Model 类的字段含义
- Service 类的平台通道约定
- 工具类的使用方式

```dart
/// 练习记录管理控制器
///
/// 管理练习计时器、每日日志、花朵成长状态。
/// 通过 [DatabaseService] 持久化数据。
class PracticeController extends ChangeNotifier {
  /// 启动练习计时器
  ///
  /// 如果已有计时器在运行，此方法无效。
  /// 计时器启动后每秒递增 [_timerElapsedSeconds]。
  Future<void> startTimer() async { /* ... */ }
}
```

**验收标准**：
- [ ] 所有页面跳转通过 `AppRouter` 统一管理
- [ ] Controller 层异常统一抛出 `AppException` 子类
- [ ] 魔法数字全部收敛到 `AppConstants`
- [ ] 公共 API 的 dartdoc 覆盖率 ≥ 80%

---

## 执行顺序与依赖关系

```
P0 (测试基础)
 │
 ├──→ P1 (耗电优化)  ← 需要测试保障后台生命周期逻辑
 │
 ├──→ P2 (性能优化)  ← 需要测试保障 Queue/debounce 改动
 │
 └──→ P3 (代码规范)  ← 可与 P1/P2 并行，互不依赖
```

**推荐执行顺序**：P0 → P1 → P2 → P3

> P0 是所有后续优化的安全网，必须先完成。P1 和 P2 改动有实际用户价值（省电、流畅），优先于 P3 的工程规范。

---

## 每阶段验收 Checklist

### P0 验收
- [ ] `flutter test` 全部通过
- [ ] 测试覆盖率 ≥ 60%
- [ ] `flutter analyze` 无 error

### P1 验收
- [ ] 节拍器后台自动暂停/恢复
- [ ] 音高轨迹后台自动停止/恢复
- [ ] 手动停止后不误恢复
- [ ] 相关单元测试通过

### P2 验收
- [ ] 音高历史 500 条无内存泄漏
- [ ] 计时器 10 秒内不触发 SP 写入
- [ ] 练习日志分页加载正常
- [ ] 相关单元测试通过

### P3 验收
- [ ] 路由集中管理
- [ ] 异常体系统一
- [ ] 魔法数字已收敛
- [ ] 公共 API dartdoc 覆盖率 ≥ 80%

---

## 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| 生命周期监听在不同平台行为不一致 | P1 后台恢复可能失效 | Android/iOS 分别真机测试 |
| Queue 替换 List 可能影响 `history` getter 的使用方 | P2 UI 层可能需要适配 | getter 返回 `List.unmodifiable` 保持接口不变 |
| 分页加载改变初始化时序 | P2 数据未加载完时 UI 显示空状态 | 保留 loading 状态，首次加载仍全量 |
| 路由集中管理改动面大 | P3 可能引入回归 | 逐页面迁移，每改一个页面跑一次 |
