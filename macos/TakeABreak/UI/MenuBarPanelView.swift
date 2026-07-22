import AppKit
import SwiftUI

struct MenuBarPanelView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(16)

            Divider()

            todayStatsRow
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            Button {
                model.openPreferences()
            } label: {
                HStack {
                    Text("偏好设置…")
                    Spacer()
                    Text("⌘,")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            Button {
                model.quit()
            } label: {
                HStack {
                    Text("退出 Take a Break")
                    Spacer()
                    Text("⌘Q")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 300)
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
                label: model.menuBarTitle.hasPrefix("‖") ? "已暂停" : "已暂停",
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
            ProgressView(value: model.state.progress)
                .tint(Color.accentColor)
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
            ProgressView(value: model.state.progress)
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
