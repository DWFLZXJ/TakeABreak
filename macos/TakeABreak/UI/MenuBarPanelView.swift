import AppKit
import SwiftUI

struct MenuBarPanelView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    /// Native SwiftUI Settings opener (macOS 14+); still reinforced by PreferencesOpener.
    @Environment(\.openSettings) private var openSettings

    /// Entrance animation state — reset each time the panel opens.
    @State private var appeared = false

    /// Snappy bounce: quick pop with a short overshoot.
    private let popSpring = Animation.spring(response: 0.28, dampingFraction: 0.62, blendDuration: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(16)

            softDivider

            todayStatsRow
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            softDivider

            footerButton(title: "偏好设置…", shortcut: "⌘,") {
                openPreferencesFromMenu()
            }

            softDivider

            footerButton(title: "退出 Take a Break", shortcut: "⌘Q") {
                model.quit()
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 300)
        // Lighter frosted glass — more transparent, less “solid card”
        .background {
            ZStack {
                // Ultra-thin material reads more premium / airy
                Rectangle()
                    .fill(.ultraThinMaterial)
                // Extra veil so blur shows through more (lower opacity = glassier)
                Rectangle()
                    .fill(colorScheme == .dark
                          ? Color.black.opacity(0.12)
                          : Color.white.opacity(0.18))
            }
            .ignoresSafeArea()
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.10)
                        : Color.black.opacity(0.06),
                    lineWidth: 0.5
                )
        )
        // Clear host window so material can blur the desktop
        .background(MenuBarGlassWindowConfigurer())
        // Fast bounce pop from menu bar
        .opacity(appeared ? 1 : 0)
        .scaleEffect(x: appeared ? 1 : 0.88, y: appeared ? 1 : 0.82, anchor: .top)
        .offset(y: appeared ? 0 : -16)
        .onAppear {
            appeared = false
            DispatchQueue.main.async {
                withAnimation(popSpring) {
                    appeared = true
                }
            }
        }
        .onDisappear {
            appeared = false
        }
    }

    private var softDivider: some View {
        Divider()
            .opacity(colorScheme == .dark ? 0.35 : 0.45)
    }

    private func footerButton(title: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(shortcut)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .buttonStyle(MenuRowButtonStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func openPreferencesFromMenu() {
        openSettings()
        PreferencesOpener.open()
    }

    private var todayStatsRow: some View {
        let s = model.todayStats
        return VStack(alignment: .leading, spacing: 4) {
            Text("今日")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                statChip(title: "完成", value: "\(s.completedRounds) 轮")
                statChip(title: "专注", value: s.focusDisplay)
                statChip(title: "跳过", value: "\(s.skipCount) 次")
            }
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state.phase {
        case .idle:
            idleContent
        case .working:
            runningContent(label: "工作中", primary: "暂停", primaryAction: model.pause)
        case .paused:
            runningContent(
                label: "已暂停",
                primary: "继续",
                primaryAction: model.resume
            )
        case .breaking:
            breakingContent
        }
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.state.roundIndex > 0 {
                Text("休息结束 · 已完成 \(model.state.roundIndex) 轮")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("点击开始下一轮专注")
                    .font(.body.weight(.medium))
            } else {
                Text("准备开始")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("工作 \(model.state.workMinutes) 分 · 休息 \(model.state.breakMinutes) 分")
                    .font(.body.weight(.medium))
            }
            Button(model.state.roundIndex > 0 ? "开始下一轮" : "开始专注") {
                model.start()
            }
            .buttonStyle(QuietPrimaryButtonStyle())
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
    }

    private func runningContent(label: String, primary: String, primaryAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.state.roundIndex > 0 {
                    Text("第 \(model.state.roundIndex) 轮")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(TimeFormatting.mmss(fromMilliseconds: model.state.remainingMs))
                .font(.system(size: 36, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: model.state.remainingMs)
            ProgressView(value: model.state.progress)
                .tint(Color.primary.opacity(0.35))
                .animation(.easeInOut(duration: 0.25), value: model.state.progress)
            HStack(spacing: 8) {
                Button(primary, action: primaryAction)
                    .buttonStyle(QuietSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                Button("停止") {
                    model.stop()
                }
                .buttonStyle(QuietSecondaryButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var breakingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("休息中")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(TimeFormatting.mmss(fromMilliseconds: model.state.remainingMs))
                .font(.system(size: 36, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: model.state.remainingMs)
            ProgressView(value: model.state.progress)
                .tint(Color.primary.opacity(0.35))
                .animation(.easeInOut(duration: 0.25), value: model.state.progress)
            Text("跳过请在全屏画面操作")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button("停止") {
                model.stop()
            }
            .buttonStyle(QuietSecondaryButtonStyle())
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Styles

/// Soft gray primary — no system blue.
private struct QuietPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.88))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(configuration.isPressed ? 0.16 : 0.12)
                          : Color.black.opacity(configuration.isPressed ? 0.10 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06),
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct QuietSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.regular))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundStyle(.primary.opacity(0.85))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(configuration.isPressed ? 0.10 : 0.06)
                          : Color.black.opacity(configuration.isPressed ? 0.07 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05),
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct MenuRowButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed
                          ? Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06)
                          : Color.clear)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Window glass

/// Makes the MenuBarExtra host window transparent so `.ultraThinMaterial` can blur the desktop.
private struct MenuBarGlassWindowConfigurer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        // Slightly stronger blur vignette via titlebar-less visual effect if available
        window.hasShadow = true
        if let content = window.contentView {
            content.wantsLayer = true
            content.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}
