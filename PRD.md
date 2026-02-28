# FrameworkScanner - 产品需求文档（PRD）

> 本文档基于当前已实现版本（v1.0.0）反向整理，反映实际功能与技术实现。

## 1. 产品概述

**产品名称：** FrameworkScanner

**版本：** 1.0.0

**平台：** macOS 13.0 (Ventura) 及以上

**作者：** Geoion · eski.yin@gmail.com

**目标：** 扫描 macOS `/Applications` 及 `~/Applications` 目录下已安装的所有应用程序，自动识别每个 App 所使用的开发框架，以列表形式展示详细信息，并支持点击展开查看内嵌 Framework 详情。

---

## 2. 目标用户

- macOS 开发者，希望了解已安装应用的技术栈
- 系统优化爱好者，希望识别资源占用较高的 Electron 应用
- 技术调研人员，需要快速了解市面上应用的框架分布情况

---

## 3. 核心功能

### 3.1 应用扫描

- 扫描 `/Applications` 及 `~/Applications` 目录下的所有 `.app` 包
- 解析每个 App 的 `Contents/Info.plist` 获取基础信息
- 最多 8 个并发任务同时处理，兼顾速度与系统资源占用
- 扫描结果按应用名称字母顺序排列

**扫描数据来源：**

| 字段 | 来源 |
|------|------|
| 应用名称 | `CFBundleDisplayName` → `CFBundleName` → 文件名 |
| Bundle ID | `CFBundleIdentifier` |
| 版本号 | `CFBundleShortVersionString` |
| 应用图标 | `NSWorkspace.shared.icon(forFile:)` |
| 安装时间 | 文件系统 `creationDate` 属性 |
| 应用大小 | 递归遍历 `.app` 包内所有文件累计大小 |
| CPU 架构 | `file` 命令解析可执行文件，识别 arm64 / x86_64 / Universal |

### 3.2 框架识别

通过分析 App Bundle 内部文件和目录结构识别框架，按优先级依次检测：

| 框架 | 识别方式 |
|------|----------|
| **Electron** | `Contents/Frameworks/` 中存在以 `Electron` 开头、`.framework` 结尾的目录 |
| **CEF** | `Contents/Frameworks/Chromium Embedded Framework.framework` 存在 |
| **Flutter** | `Contents/Frameworks/FlutterMacOS.framework` 存在 |
| **Qt** | `Contents/Frameworks/` 中存在以 `Qt` 开头、`.framework` 结尾的目录 |
| **Unity** | `Contents/Frameworks/` 中含 `UnityPlayer`，或 `Contents/Data/Managed/` 目录存在 |
| **Unreal Engine** | `Contents/Frameworks/` 中含 `UE4` 或 `UnrealEngine` |
| **.NET/MAUI** | `Contents/Frameworks/` 中含 `Mono` 或 `dotnet`，或 `Contents/Resources/` 中有 `.dll` 文件 |
| **Java/JVM** | `Contents/Resources/` 中有 `.jar` 文件，或 `Contents/Java/` 目录存在，或 Frameworks 中含 `libjvm` |
| **Tauri** | Frameworks 中含 WebKit，且 Resources 中含 `tauri` 相关文件名 |
| **Catalyst** | `Info.plist` 中 `LSRequiresIPhoneOS = true` 或含 `UIRequiredDeviceCapabilities` |
| **SwiftUI** | Frameworks 中含 SwiftUI，或通过 `otool -L` 检测可执行文件链接了 SwiftUI |
| **AppKit** | 以上均不符合时的兜底分类 |
| **Unknown** | 无法读取 Info.plist 的无效 App |

### 3.3 Electron 详细信息提取

Electron 应用额外解析以下版本信息：

| 信息 | 提取方式 |
|------|----------|
| Electron 版本 | `Electron Framework.framework/Resources/Info.plist` 中的 `CFBundleShortVersionString` |
| Chromium 版本 | `LICENSES.chromium.html` 中正则匹配，或根据 Electron 主版本号推断 |
| Node.js 版本 | `Contents/Resources/package.json` 中 `engines.node`，或根据 Electron 主版本号推断 |

### 3.4 内嵌 Framework 详情

点击列表中任意一行可展开查看该 App 的内嵌 Framework 列表：

- 扫描 `Contents/Frameworks/` 下所有 `.framework` 和 `.dylib`
- 展示每个内嵌 Framework 的：**名称**、**版本号**（从其 Info.plist 解析）、**相对路径**、**大小**
- 按需异步加载（首次展开时触发），不影响初始列表加载速度
- 展开/收起使用平滑抽屉动画（`easeInOut(duration: 0.25)`）

### 3.5 列表信息展示

每行展示以下字段：

| 字段 | 说明 |
|------|------|
| 展开箭头 | `chevron.right` / `chevron.down`，点击整行触发展开 |
| App 图标 | 40×40pt，初始化时预缩放缓存，避免滚动时重复渲染 |
| App 名称 | 加粗显示，旁边附版本号 Tag |
| Bundle ID | 名称下方小字显示 |
| 框架标签 | 带 SF Symbol 图标的 Capsule 标签；Electron 应用额外显示 e/Cr/N 版本 |
| 大小 / 日期 | 磁盘占用 + 安装日期，右对齐 |
| 架构 | Apple Silicon / Intel / Universal，Capsule 样式 |

### 3.6 搜索与筛选

- **关键词搜索：** 支持按应用名称、Bundle ID 搜索，150ms debounce 防抖
- **框架筛选：** 下拉多选菜单，支持同时筛选多种框架
- **排序：** 支持按名称、大小、日期、框架类型排序，可切换升降序

### 3.7 统计概览栏

搜索栏下方横向滚动标签行，展示：

- 已扫描应用总数
- 各框架类型的数量及占比（按数量降序，最多显示前 6 种）
- Electron 应用的总磁盘占用

### 3.8 表头说明

列表上方固定表头，包含列名：

- **Application**、**Framework**、**Size / Date**、**Arch**
- Framework 和 Arch 列带 `?` 图标，支持 hover 1 秒或点击弹出 Popover 说明

---

## 4. 界面设计

### 4.1 主界面布局

```
┌──────────────────────────────────────────────────────────┐
│  FrameworkScanner                               [↺ 扫描]  │
├──────────────────────────────────────────────────────────┤
│  🔍 搜索...                    [筛选: 全部 ▾] [排序: 名称 ▾] │
│──────────────────────────────────────────────────────────│
│  Total: 251  AppKit: 90 (36%)  SwiftUI: 82 (33%)  ...    │
│──────────────────────────────────────────────────────────│
│  Application          Framework ⓘ   Size/Date   Arch ⓘ  │
│──────────────────────────────────────────────────────────│
│  › 🎯  Arc  v1.135.0              SwiftUI  845MB  Universal │
│      company.thebrowser.Browser                          │
│──────────────────────────────────────────────────────────│
│  ∨ ⚡  attu  v2.6.0              Electron  301MB  Apple   │
│      milvus                       e35.1.5                │
│    ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄  │
│    BearCore  2.6.7  Contents/Frameworks/BearCore.fra...  │
│    Sentry    2.6.7  Contents/Frameworks/Sentry.frame...  │
│    ...                                                   │
└──────────────────────────────────────────────────────────┘
```

### 4.2 扫描进度界面

```
           [当前 App 图标 64×64]
              当前 App 名称

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━  (线性进度条)
               23 / 156
```

- 图标与名称作为整体，每切换一个 App 有缩放淡入淡出动画
- 尚未开始时显示占位图标 + "Preparing scan..."

### 4.3 权限引导界面

首次启动或权限失效时显示：

- 文件夹图标 + 说明文字
- "Grant Access" 按钮，点击弹出 `NSOpenPanel` 预定位到 `/Applications`
- 用户取消时显示空状态页面

### 4.4 设计规范

- 遵循 macOS Human Interface Guidelines
- 支持 Light / Dark / System 三种外观模式，通过 `NSApp.appearance` 全局切换
- 列表使用 `.inset` 样式，无隔行变色
- 框架标签 Capsule 样式，Electron 标签橙色背景

---

## 5. 技术方案

### 5.1 技术栈

| 项目 | 选型 |
|------|------|
| 语言 | Swift 5.9 |
| UI 框架 | SwiftUI |
| 最低系统 | macOS 13.0 (Ventura) |
| 架构 | MVVM |
| 项目管理 | XcodeGen（`project.yml`） |
| 并发 | Swift Concurrency（async/await，actor） |

### 5.2 项目结构

```
Sources/
├── App/
│   ├── FrameworkScannerApp.swift   # @main 入口
│   └── AppState.swift              # 全局状态（外观/语言）
├── Models/
│   ├── AppInfo.swift               # 应用信息 + EmbeddedFramework
│   ├── FrameworkType.swift         # 框架类型枚举（13 种）
│   └── SortOption.swift            # 排序选项枚举
├── ViewModels/
│   └── ScannerViewModel.swift      # 主 ViewModel
├── Views/
│   ├── ContentView.swift           # 主界面 + 权限/扫描/空状态
│   ├── AppRowView.swift            # 单行 + 展开详情
│   ├── StatsBarView.swift          # 统计标签栏
│   ├── FilterToolbar.swift         # 搜索/筛选/排序工具栏
│   └── SettingsView.swift          # 设置面板
├── Services/
│   ├── AppScanner.swift            # 并发扫描（actor，最多 8 并发）
│   ├── FrameworkDetector.swift     # 框架识别（12 种规则）
│   ├── ElectronAnalyzer.swift      # Electron 版本提取
│   └── EmbeddedFrameworkScanner.swift  # 内嵌 Framework 扫描
└── Utilities/
    ├── BookmarkManager.swift       # Security-Scoped Bookmark
    ├── ArchitectureDetector.swift  # CPU 架构检测（file 命令）
    └── FileSizeFormatter.swift     # 目录大小递归计算
Resources/
├── en.lproj/     zh-Hans.lproj/   ja.lproj/
├── ko.lproj/     de.lproj/        es.lproj/
├── it.lproj/     ru.lproj/
├── Assets.xcassets/
├── Info.plist
└── FrameworkScanner.entitlements
```

### 5.3 权限与沙盒

- App Sandbox 启用，entitlements 包含：
  - `com.apple.security.app-sandbox`
  - `com.apple.security.files.user-selected.read-only`
  - `com.apple.security.files.bookmarks.app-scope`
- 启动时自动检查 Security-Scoped Bookmark：
  - 有效 → 自动恢复访问权限，直接开始扫描
  - 无效/过期 → 弹出 Alert 引导用户重新授权
  - 用户取消 → 显示空状态，提示需要授权
- Bookmark 持久化至 `UserDefaults`

### 5.4 性能优化

| 优化项 | 实现方式 |
|--------|----------|
| 并发扫描 | 最多 8 个并发 Task，滑动窗口补充新任务 |
| 图标缓存 | `AppInfo` 初始化时预缩放至 40×40pt，避免滚动时重复缩放 |
| 格式化缓存 | `formattedSize`、`formattedDate` 初始化时一次性计算 |
| 过滤缓存 | `filteredApps` 为 `@Published` 属性，通过 Combine 管道 debounce 后重算 |
| 按需加载 | 内嵌 Framework 详情在展开时才异步加载 |
| 进度单调递增 | ViewModel 端保证 `scanCurrent` 只增不减，防止并发乱序导致进度回跳 |

### 5.5 多语言实现

- 运行时动态切换，无需重启应用
- 切换语言时通过 `Bundle(path:)` 加载对应 `.lproj`，更新 `languageRefreshId`
- 根视图绑定 `.id(appState.languageRefreshId)`，UUID 变化时强制重建视图树
- `checkPermissionAndScan()` 有 `guard allApps.isEmpty` 保护，语言切换不触发重新扫描

---

## 6. 多语言支持

| 语言 | 代码 |
|------|------|
| English | `en` |
| 中文（简体） | `zh-Hans` |
| 日本語 | `ja` |
| 한국어 | `ko` |
| Deutsch | `de` |
| Español | `es` |
| Italiano | `it` |
| Русский | `ru` |
| 跟随系统 | 自动匹配以上语言，无匹配则回退到英文 |

---

## 7. 设置面板

| 设置项 | 选项 |
|--------|------|
| 外观 | System / Light / Dark（Segmented Control） |
| 语言 | 下拉菜单，9 个选项（含 System） |
| 版本 | 1.0.0（只读） |
| 作者 | Geoion（只读） |
| 反馈 | 点击邮件链接，打开系统邮件客户端 |

---

## 8. 未来扩展（v2.0）

- 支持扫描 `/System/Applications` 系统应用
- 支持扫描 Homebrew Cask 安装的应用
- 导出扫描结果为 CSV / JSON
- 应用详情页：Bundle 结构树、签名信息、Entitlements
- 检测 Electron 应用中已知安全漏洞（基于版本号）
- 菜单栏常驻图标，监控新安装的应用
- Homebrew 集成：一键卸载选定应用
