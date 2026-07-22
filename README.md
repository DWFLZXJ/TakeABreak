# Take a Break

macOS 休息提醒（原生 SwiftUI + AppKit）。

规格：`docs/superpowers/specs/2026-07-22-takeabreak-design.md`

## 运行

```bash
open macos/TakeABreak.xcodeproj
# Xcode 中 ⌘R
```

或命令行：

```bash
cd macos
xcodebuild -scheme TakeABreak -destination 'platform=macOS' -derivedDataPath ./DerivedData build
open "./DerivedData/Build/Products/Debug/Take a Break.app"
```

菜单栏应用（无 Dock 图标）：点 `◌` → 开始专注 → 到点全屏休息 → 长按 2 秒可跳过。

## 测试

```bash
cd macos
xcodebuild -scheme TakeABreak -destination 'platform=macOS' -derivedDataPath ./DerivedData test
```

## 结构

```
macos/
  TakeABreak.xcodeproj
  TakeABreak/          # App 源码
  TakeABreakTests/     # XCTest
docs/superpowers/
  specs/               # 产品规格
  plans/               # 实现计划
```

## 技术栈

- SwiftUI `MenuBarExtra` + `Settings`
- AppKit 全屏遮罩（多显示器）
- `TimerEngine` 番茄状态机
- `UserDefaults` 偏好持久化
