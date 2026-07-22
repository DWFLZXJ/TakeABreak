import AppKit
import SwiftUI

struct MenuBarPanelView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(16)

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
        .frame(width: 280)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state.phase {
        case .idle:
            idleContent
        case .working:
            runningContent(label: "工作中", primary: "暂停", primaryAction: model.pause)
        case .paused:
            runningContent(label: "已暂停", primary: "继续", primaryAction: model.resume)
        case .breaking:
            breakingContent
        }
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("准备开始")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("工作 \(model.state.workMinutes) 分 · 休息 \(model.state.breakMinutes) 分")
                .font(.body.weight(.medium))
            Button("开始专注") {
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
            Text("跳过请在全屏画面长按 2 秒")
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
