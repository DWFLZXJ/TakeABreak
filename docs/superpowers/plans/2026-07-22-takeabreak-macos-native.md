# Take a Break — macOS 原生实现计划

> **For agentic workers:** 按 Task 顺序实现；每 Task 可编译或可测后再进入下一 Task。

**Goal:** 用原生 Swift 技术栈交付可运行的 macOS 菜单栏休息提醒 App，行为对齐 `docs/superpowers/specs/2026-07-22-takeabreak-design.md`。

**Architecture:**
- **SwiftUI** `MenuBarExtra`：菜单栏图标 + 下拉面板  
- **SwiftUI** `Settings`：偏好设置小窗  
- **AppKit** `NSWindow`：多屏全屏休息遮罩（borderless、高 window level）  
- **TimerEngine**（纯 Swift，与 demo JS 语义一致）+ **AppModel**（ObservableObject）驱动 UI 与遮罩  
- **UserDefaults** 持久化偏好；壁纸为 security-scoped bookmark 或内置资源  

**Tech Stack:** Swift 6 / macOS 14+ / SwiftUI + AppKit / XCTest  
**工程路径:** `macos/TakeABreak/`（在 `feature/html-demos` worktree 内开发）

---

## File Structure

```
macos/
  TakeABreak.xcodeproj/
  TakeABreak/
    TakeABreakApp.swift          # @main, MenuBarExtra, Settings
    Info.plist                   # LSUIElement=true
    Assets.xcassets/
    Engine/
      TimerEngine.swift          # 状态机
      TimerPhase.swift
      AppPreferences.swift
    App/
      AppModel.swift             # 计时 tick、睡眠冻结、协调遮罩
      PreferencesStore.swift
    UI/
      MenuBarPanelView.swift
      PreferencesView.swift
      BreakOverlayView.swift     # SwiftUI 纯文字叠层
    Overlay/
      BreakOverlayController.swift  # 每屏一个 NSWindow
  TakeABreakTests/
    TimerEngineTests.swift
```

---

## Task 概览

| # | 内容 | 验收 |
|---|------|------|
| 1 | TimerEngine + XCTest | `xcodebuild test` 状态机用例通过 |
| 2 | Xcode 工程 + MenuBarExtra 壳 | App 启动仅菜单栏、Idle 面板可点 |
| 3 | AppModel 计时 + 菜单栏动态标题 | 开始/暂停/停止/倒计时更新 |
| 4 | Preferences + UserDefaults | 设置可改 N/M/文案/跳过开关 |
| 5 | BreakOverlay 全屏 + 长按 2s | 工作结束全屏；长按跳过 |
| 6 | 睡眠冻结 + 多屏 + 打磨 | 合盖不掉时；每屏遮罩 |

---

## 关键行为映射（规格 → 实现）

| 规格 | 实现要点 |
|------|----------|
| Working → Breaking 自动 | `AppModel` tick 检测 phase 变化 → `BreakOverlayController.show` |
| 长按 2s 跳过 | `BreakOverlayView` DragGesture/long press → `engine.skipBreak()` |
| 改 N/M 下轮生效 | 引擎已有 lock 语义 |
| 睡眠冻结 | `NSWorkspace.willSleep/didWake` 或暂停 `lastTick` |
| 无 Dock 图标 | `LSUIElement` = true |
| 纯文字叠层 | 无 material 卡片；壁纸 + 暗层 + 文字 |

---

## 非目标（v1）

- 统计、云同步、多档案、Sparkle 自动更新（可后续）
- Catalyst / iOS
- 沙盒外任意路径无 bookmark 读图（选图走 NSOpenPanel + bookmark）
