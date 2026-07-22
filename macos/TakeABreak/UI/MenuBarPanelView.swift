import AppKit
import SwiftUI

struct MenuBarPanelView: View {
    @EnvironmentObject private var model: AppModel

    /// Entrance animation state — reset each time the panel opens.
    @State private var appeared = false
    @State private var contentAppeared = false

    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.1)
    private let contentSpring = Animation.spring(response: 0.48, dampingFraction: 0.88)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(16)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 6)

            animatedDivider

            todayStatsRow
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 8)

            animatedDivider

            footerButton(title: "偏好设置…", shortcut: "⌘,") {
                model.openPreferences()
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 8)

            animatedDivider

            footerButton(title: "退出 Take a Break", shortcut: "⌘Q") {
                model.quit()
            }
            .keyboardShortcut("q", modifiers: .command)
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 8)
        }
        .frame(width: 300)
        // Panel shell: drop from menu bar + fade + slight scale
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.94, anchor: .top)
        .offset(y: appeared ? 0 : -12)
        .onAppear {
            // Reset then animate in (next open of MenuBarExtra recreates/reappears content)
            appeared = false
            contentAppeared = false
            withAnimation(spring) {
                appeared = true
            }
            withAnimation(contentSpring.delay(0.04)) {
                contentAppeared = true
            }
        }
        .onDisappear {
            appeared = false
            contentAppeared = false
        }
    }

    private var animatedDivider: some View {
        Divider()
            .opacity(contentAppeared ? 1 : 0)
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
        .buttonStyle(MenuPanelButtonStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
            .buttonStyle(.borderedProminent)
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
                .tint(Color.accentColor)
                .animation(.easeInOut(duration: 0.25), value: model.state.progress)
            HStack(spacing: 8) {
                Button(primary, action: primaryAction)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("停止") {
                    model.stop()
                }
                .buttonStyle(.bordered)
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
                .animation(.easeInOut(duration: 0.25), value: model.state.progress)
            Text("跳过请在全屏画面操作")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button("停止") {
                model.stop()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Subtle highlight on hover for footer rows (menu-like feel).
private struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.08) : Color.clear)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
