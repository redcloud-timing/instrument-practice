# 资料模块详细说明

本文档详细介绍「练琴乐时」App 中「资料」模块的功能、实现和使用方式。

---

## 功能概述

「资料」模块用于管理乐谱（PDF）和图片资料，主要功能包括：

- 📄 导入 PDF 和图片资料
- ⭐ 收藏管理
- 📝 资料笔记
- 📂 自定义栏目分类
- 🔍 搜索功能
- 📱 默认 PDF 阅读器设置

---

## 界面布局

```
┌─────────────────────────────────────────────────────────────┐
│  🎵 乐谱(12) ⭐3  [🔍] [阅读器图标] [+添加]                │
├─────────────────────────────────────────────────────────────┤
│  [全部] [练习曲] [考级曲] [流行曲] [+]                      │
├─────────────────────────────────────────────────────────────┤
│  📄 乐谱1.pdf   6月19日   [⭐] [⋮]                         │
│  📄 乐谱2.pdf   6月18日   [☆] [⋮]                         │
│  🖼️ 图片1.png   6月17日   [☆] [⋮]                         │
│  ...                                                        │
└─────────────────────────────────────────────────────────────┘
```

### 顶部标题栏

- 左侧：🎵 图标 + 乐谱数量 + ⭐ 收藏数量
- 右侧：
  - 🔍 搜索按钮（点击展开/收起搜索框）
  - 默认阅读器图标（点击可更换）
  - +添加 按钮

### 栏目标签栏

- 「全部」：显示所有资料
- 自定义栏目：点击切换，长按编辑，左滑删除
- 「+」按钮：创建新栏目

### 资料列表

每个资料项显示：
- 左侧：PDF 或图片图标
- 中间：标题 + 更新时间
- 右侧：⭐ 收藏按钮 + ⋮ 更多菜单

---

## 功能详解

### 1. 导入资料

**操作方式**：
1. 点击顶部「+添加」按钮
2. 系统弹出文件选择器
3. 选择 PDF 或图片文件
4. 自动导入到资料库

**支持格式**：
- PDF：`application/pdf`
- 图片：`image/*`（JPEG、PNG 等）

**容量限制**：最多 60 条资料，超出时自动裁剪未收藏的旧资料。

---

### 2. 收藏管理

**操作方式**：
- 点击资料右侧的 ⭐ 图标切换收藏状态

**特点**：
- 收藏的资料不会被自动裁剪
- 收藏数量显示在标题栏

---

### 3. 资料笔记

**操作方式**：
1. 点击资料右侧的 ⋮ 菜单
2. 选择「笔记」
3. 进入独立编辑页面
4. 输入笔记内容（自动保存）

**特点**：
- 使用 `TextEditScreen` 独立页面编辑
- 支持中文输入
- 笔记内容可被搜索

---

### 4. 重命名资料

**操作方式**：
1. 点击资料右侧的 ⋮ 菜单
2. 选择「重命名」
3. 输入新名称
4. 点击保存

---

### 5. 删除资料

**操作方式**：
1. 点击资料右侧的 ⋮ 菜单
2. 选择「移除」
3. 确认删除

**特点**：
- 删除资料时会同时删除该资料的所有栏目关联
- 删除后无法恢复

---

### 6. 自定义栏目

#### 创建栏目

**操作方式**：
1. 点击栏目标签栏右侧的「+」按钮
2. 输入栏目名称
3. 点击「创建」

#### 编辑栏目

**操作方式**：
1. 长按栏目名称
2. 修改名称
3. 点击「保存」

#### 删除栏目

**操作方式**：
1. 左滑栏目名称
2. 确认删除

**特点**：
- 删除栏目不会删除栏目下的资料
- 资料仍然保留在「全部」中

#### 添加资料到栏目

**操作方式**：
1. 点击资料右侧的 ⋮ 菜单
2. 选择「添加到栏目」
3. 选择要添加到的栏目（可多选）
4. 点击栏目切换选中状态

**特点**：
- 一个资料可以属于多个栏目
- 已添加的栏目会显示 ✓ 图标
- 点击已添加的栏目可以取消

#### 筛选栏目

**操作方式**：
- 点击栏目名称切换筛选
- 点击「全部」显示所有资料

---

### 7. 搜索功能

**操作方式**：
1. 点击顶部 🔍 搜索按钮
2. 展开搜索框
3. 输入关键词
4. 实时筛选结果

**搜索范围**：
- 资料标题
- 资料笔记内容

---

### 8. 默认 PDF 阅读器

#### 设置默认阅读器

**操作方式**：
1. 点击顶部右侧的阅读器图标
2. 底部弹出应用选择器
3. 选择一个应用作为默认阅读器
4. 图标自动更新为所选应用的图标

**选项说明**：
- 「每次选择」：清除默认应用，每次打开 PDF 时弹出选择器
- 应用列表：显示手机上所有已安装的 PDF 阅读器

#### 打开 PDF

**操作方式**：
1. 点击 PDF 资料
2. 如果有默认应用，直接用默认应用打开
3. 如果没有默认应用，弹出选择器
4. 选择后自动保存为默认应用
5. 打开后自动返回「资料」界面

**特点**：
- 使用系统原生 PDF 阅读器，性能好
- 支持 Android 11+ 的包可见性限制
- 自动记住上次阅读位置

---

## 数据存储

### 资料元数据

存储在 `app_settings` 表的 `library_documents_v1` key 中，JSON 格式：

```json
[
  {
    "uri": "content://...",
    "title": "乐谱1.pdf",
    "mimeType": "application/pdf",
    "addedAtIso": "2026-06-19T00:00:00.000",
    "openedAtIso": "2026-06-19T12:00:00.000",
    "isFavorite": true,
    "note": "练习重点：第三乐章",
    "sizeBytes": 1024000,
    "lastPageIndex": 5
  }
]
```

### 栏目数据

存储在 SQLite 数据库中：

**categories 表**：
```sql
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
)
```

**category_items 表**：
```sql
CREATE TABLE category_items (
  category_id INTEGER NOT NULL,
  item_uri TEXT NOT NULL,
  PRIMARY KEY (category_id, item_uri),
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
)
```

### 默认阅读器

存储在 `app_settings` 表的 `default_pdf_viewer` key 中，值为应用包名。

---

## 相关文件

### Dart 文件

| 文件 | 说明 |
|------|------|
| `lib/screens/library_screen.dart` | 资料列表界面 |
| `lib/screens/document_viewer_screen.dart` | 资料查看界面 |
| `lib/controllers/library_controller.dart` | 资料控制器 |
| `lib/models/library_item.dart` | 资料数据模型 |
| `lib/models/category.dart` | 栏目数据模型 |
| `lib/models/category_item.dart` | 栏目-资料关联模型 |
| `lib/services/document_library_service.dart` | 资料服务 |
| `lib/services/database_service.dart` | 数据库服务 |

### Kotlin 文件

| 文件 | 说明 |
|------|------|
| `MainActivity.kt` | 原生方法实现 |

### 原生 MethodChannel 方法

| 方法 | 说明 |
|------|------|
| `pickDocument` | 选择 PDF 文件 |
| `pickImage` | 选择图片文件 |
| `loadImage` | 加载图片字节 |
| `loadPdfBytes` | 加载 PDF 字节 |
| `getPdfViewerApps` | 获取已安装的 PDF 阅读器列表 |
| `getAppIcon` | 获取应用图标 |
| `openWithSpecificApp` | 用指定应用打开 PDF |
| `openWithSystemViewer` | 用系统选择器打开 PDF |
| `openDocument` | 打开文档 |

---

## AndroidManifest.xml 配置

### 权限

```xml
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### 包可见性声明（Android 11+）

```xml
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:mimeType="application/pdf" />
    </intent>
</queries>
```

---

## 常见问题

### Q: 为什么只能看到 Edge 浏览器？

A: Android 11+ 引入了包可见性限制，需要在 `AndroidManifest.xml` 中添加 `<queries>` 声明才能查询其他应用。

### Q: 打开 PDF 后为什么没有回到「资料」界面？

A: 当前实现会在打开 PDF 后自动调用 `Navigator.pop` 返回。如果仍有问题，请检查是否使用了最新版本的代码。

### Q: 如何清除默认阅读器？

A: 点击阅读器图标，在弹出的选择器中选择「每次选择」即可清除默认应用。

### Q: 栏目删除后资料会丢失吗？

A: 不会。删除栏目只会删除栏目和资料的关联关系，资料本身仍然保留在「全部」中。

### Q: 一个资料可以属于多个栏目吗？

A: 可以。一个资料可以同时属于多个栏目，通过 `category_items` 关联表存储多对多关系。

---

## 开发注意事项

1. **数据库版本**：当前版本是 2，新增了 `categories` 和 `category_items` 表。
2. **中文输入**：重命名和笔记编辑使用 `TextEditScreen` 独立页面，避免 Dialog/BottomSheet 中的中文输入问题。
3. **PDF 打开**：使用系统原生阅读器，不再使用内置的 PdfRenderer。
4. **包可见性**：Android 11+ 需要在 `AndroidManifest.xml` 中添加 `<queries>` 声明。
5. **容量限制**：资料列表最多 60 条，超出时自动裁剪未收藏的旧资料。

---

*最后更新：2026-06-19*
