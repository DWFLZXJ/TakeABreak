import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isPickingFolder = false
    @State private var folderError: String?
    /// Draft strings so typing isn't interrupted by clamp-on-every-keystroke.
    @State private var workMinutesText = ""
    @State private var breakMinutesText = ""
    @FocusState private var focusedField: DurationField?

    private enum DurationField: Hashable {
        case work
        case breakTime
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("工作")
                    Spacer()
                    TextField("25", text: $workMinutesText)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .work)
                        .onSubmit { commitWorkMinutes() }
                    Text("分钟")
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                }

                HStack {
                    Text("休息")
                    Spacer()
                    TextField("5", text: $breakMinutesText)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .breakTime)
                        .onSubmit { commitBreakMinutes() }
                    Text("分钟")
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                }

                Text("直接输入数字，回车或点别处生效。工作 \(AppPreferences.workMinutesUIRange.lowerBound)–\(AppPreferences.workMinutesUIRange.upperBound) 分钟，休息 \(AppPreferences.breakMinutesRange.lowerBound)–\(AppPreferences.breakMinutesRange.upperBound) 分钟；修改将于下一轮生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("时长")
            }

            Section {
                TextField("休息时显示的文字", text: messageBinding, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("休息文案")
            }

            Section {
                Toggle("允许长按跳过休息", isOn: skipBinding)
                Text("关闭后须等休息倒计时结束")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("行为")
            }

            Section {
                HStack {
                    Text("文件夹")
                    Spacer()
                    Text(model.preferences.wallpaperFolderDisplayName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let path = model.preferences.wallpaperFolderPath {
                    Text(path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                    wallpaperCountLabel
                } else {
                    Text("未设置时使用默认深色背景")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button("选择壁纸文件夹…") {
                        commitWorkMinutes()
                        commitBreakMinutes()
                        NSApp.activate(ignoringOtherApps: true)
                        isPickingFolder = true
                    }
                    .buttonStyle(.borderedProminent)

                    if model.preferences.wallpaperFolderPath != nil {
                        Button("清除") {
                            folderError = nil
                            model.clearWallpaperFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let folderError {
                    Text(folderError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("休息壁纸目录")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 500)
        .padding()
        .onAppear {
            workMinutesText = "\(model.preferences.workMinutes)"
            breakMinutesText = "\(model.preferences.breakMinutes)"
        }
        .onChange(of: focusedField) { newFocus in
            // Commit when leaving a field.
            if newFocus != .work {
                commitWorkMinutes()
            }
            if newFocus != .breakTime {
                commitBreakMinutes()
            }
        }
        .onChange(of: model.preferences.workMinutes) { value in
            if focusedField != .work {
                workMinutesText = "\(value)"
            }
        }
        .onChange(of: model.preferences.breakMinutes) { value in
            if focusedField != .breakTime {
                breakMinutesText = "\(value)"
            }
        }
        .onDisappear {
            commitWorkMinutes()
            commitBreakMinutes()
        }
        .fileImporter(
            isPresented: $isPickingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if let err = model.setWallpaperFolder(from: url) {
                    folderError = err
                } else {
                    folderError = nil
                }
            case .failure(let error):
                folderError = "无法选择文件夹：\(error.localizedDescription)"
            }
        }
    }

    // MARK: - Commit helpers

    private func commitWorkMinutes() {
        let range = AppPreferences.workMinutesUIRange
        let parsed = Int(workMinutesText.trimmingCharacters(in: .whitespacesAndNewlines))
        let value = clamp(parsed ?? model.preferences.workMinutes, in: range)
        if model.preferences.workMinutes != value {
            model.preferences.workMinutes = value
        }
        workMinutesText = "\(value)"
    }

    private func commitBreakMinutes() {
        let range = AppPreferences.breakMinutesRange
        let parsed = Int(breakMinutesText.trimmingCharacters(in: .whitespacesAndNewlines))
        let value = clamp(parsed ?? model.preferences.breakMinutes, in: range)
        if model.preferences.breakMinutes != value {
            model.preferences.breakMinutes = value
        }
        breakMinutesText = "\(value)"
    }

    private func clamp(_ value: Int, in range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private var messageBinding: Binding<String> {
        Binding(
            get: { model.preferences.customMessage },
            set: { model.preferences.customMessage = $0 }
        )
    }

    private var skipBinding: Binding<Bool> {
        Binding(
            get: { model.preferences.allowLongPressSkip },
            set: { model.preferences.allowLongPressSkip = $0 }
        )
    }

    @ViewBuilder
    private var wallpaperCountLabel: some View {
        let count = model.wallpaperFolderImageCount
        Text(count > 0 ? "共 \(count) 张图片 · 每次休息随机一张" : "未找到图片")
            .font(.caption)
            .foregroundStyle(count > 0 ? Color.secondary : Color.red)
    }
}
