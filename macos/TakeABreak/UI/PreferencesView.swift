import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isPickingFolder = false
    @State private var folderError: String?

    var body: some View {
        Form {
            Section {
                Stepper(value: workMinutesBinding, in: AppPreferences.workMinutesUIRange) {
                    HStack {
                        Text("工作")
                        Spacer()
                        Text("\(model.preferences.workMinutes) 分钟")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Stepper(value: breakMinutesBinding, in: AppPreferences.breakMinutesRange) {
                    HStack {
                        Text("休息")
                        Spacer()
                        Text("\(model.preferences.breakMinutes) 分钟")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Text("修改将于下一轮生效")
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
        .frame(width: 420, height: 480)
        .padding()
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

    private var workMinutesBinding: Binding<Int> {
        Binding(
            get: { model.preferences.workMinutes },
            set: { model.preferences.workMinutes = $0 }
        )
    }

    private var breakMinutesBinding: Binding<Int> {
        Binding(
            get: { model.preferences.breakMinutes },
            set: { model.preferences.breakMinutes = $0 }
        )
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
