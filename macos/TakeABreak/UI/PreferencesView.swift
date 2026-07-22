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
                if model.preferences.todos.isEmpty {
                    Text("暂无待办。添加后会在休息锁屏上展示已开启的项。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(model.preferences.todos) { item in
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { item.isEnabled },
                            set: { model.updateTodo(id: item.id, isEnabled: $0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .help(item.isEnabled ? "休息时显示" : "休息时隐藏")

                        TextField("提醒内容", text: Binding(
                            get: { item.text },
                            set: { model.updateTodo(id: item.id, text: $0) }
                        ))
                        .textFieldStyle(.roundedBorder)

                        Button {
                            model.removeTodo(id: item.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("删除")
                    }
                }

                HStack {
                    Button {
                        model.addTodo()
                    } label: {
                        Label("添加待办", systemImage: "plus.circle")
                    }
                    .disabled(model.preferences.todos.count >= AppPreferences.maxTodos)

                    Spacer()
                    Text("\(model.preferences.todos.count)/\(AppPreferences.maxTodos)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text("勾选表示在休息锁屏展示；最多 \(AppPreferences.maxTodos) 条，锁屏最多显示 8 条。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("待办提醒")
            }

            Section {
                Toggle("允许长按跳过休息", isOn: skipBinding)
                Text("关闭后须等休息倒计时结束")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if model.preferences.allowLongPressSkip {
                    Picker("跳过难度", selection: skipDifficultyBinding) {
                        ForEach(SkipDifficulty.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(model.preferences.skipDifficulty.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("进入休息时发送系统通知", isOn: notifyBinding)
                Text("到点全屏休息时额外弹一条通知（需授权通知权限）")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("休息开始/结束播放提示音", isOn: soundBinding)
                Text("使用系统提示音：进入休息与休息结束各一声")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("空闲检测", isOn: idleEnabledBinding)
                if model.preferences.idleDetectionEnabled {
                    HStack {
                        Text("空闲超过")
                        TextField(
                            "3",
                            text: Binding(
                                get: { "\(model.preferences.idleThresholdMinutes)" },
                                set: { text in
                                    if let v = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                        var p = model.preferences
                                        p.idleThresholdMinutes = min(
                                            max(v, AppPreferences.idleMinutesRange.lowerBound),
                                            AppPreferences.idleMinutesRange.upperBound
                                        )
                                        model.preferences = p
                                    }
                                }
                            )
                        )
                        .frame(width: 48)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        Text("分钟")
                            .foregroundStyle(.secondary)
                    }
                    Picker("空闲时", selection: idleActionBinding) {
                        ForEach(IdleAction.allCases) { action in
                            Text(action.title).tag(action)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(model.preferences.idleAction.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("休息结束且无人操作时锁定屏幕", isOn: lockWhenIdleBinding)
                Text("休息自然结束时若约 2 秒内无键鼠操作，自动锁屏，避免泄密。跳过休息不会触发。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("锁屏时会暂停计时；休息结束后需手动点「开始下一轮」。")
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
        .frame(width: 460, height: 620)
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

    private var notifyBinding: Binding<Bool> {
        Binding(
            get: { model.preferences.notifyOnBreakStart },
            set: { enabled in
                model.preferences.notifyOnBreakStart = enabled
                if enabled {
                    BreakNotifier.requestPermissionIfNeeded()
                }
            }
        )
    }

    private var skipDifficultyBinding: Binding<SkipDifficulty> {
        Binding(
            get: { model.preferences.skipDifficulty },
            set: { model.preferences.skipDifficulty = $0 }
        )
    }

    private var soundBinding: Binding<Bool> {
        Binding(
            get: { model.preferences.soundEnabled },
            set: { model.preferences.soundEnabled = $0 }
        )
    }

    private var idleEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.preferences.idleDetectionEnabled },
            set: { model.preferences.idleDetectionEnabled = $0 }
        )
    }

    private var idleActionBinding: Binding<IdleAction> {
        Binding(
            get: { model.preferences.idleAction },
            set: { model.preferences.idleAction = $0 }
        )
    }

    private var lockWhenIdleBinding: Binding<Bool> {
        Binding(
            get: { model.preferences.lockScreenWhenBreakEndsIdle },
            set: { model.preferences.lockScreenWhenBreakEndsIdle = $0 }
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
