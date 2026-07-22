import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isImportingWallpaper = false
    @State private var importError: String?

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
                HStack(spacing: 12) {
                    wallpaperThumb(id: "default-1", colors: [.indigo, .purple])
                    wallpaperThumb(id: "default-2", colors: [.pink, .orange])
                    wallpaperThumb(id: "default-3", colors: [.cyan, .blue])
                    Button {
                        // Activate first so the importer can present in a menu-bar app.
                        NSApp.activate(ignoringOtherApps: true)
                        isImportingWallpaper = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .frame(width: 72, height: 48)
                            Image(systemName: "plus")
                        }
                    }
                    .buttonStyle(.plain)
                    .help("选择本地图片")
                }
                if model.preferences.wallpaperId == "custom" {
                    Text("已选择自定义壁纸")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let importError {
                    Text(importError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("休息壁纸")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 480)
        .padding()
        // SwiftUI fileImporter is reliable for LSUIElement / menu-bar apps.
        // NSOpenPanel.begin often hangs when there is no proper key window.
        .fileImporter(
            isPresented: $isImportingWallpaper,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importError = nil
                model.applyCustomWallpaper(from: url)
            case .failure(let error):
                importError = "无法选择图片：\(error.localizedDescription)"
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

    private func wallpaperThumb(id: String, colors: [Color]) -> some View {
        let selected = model.preferences.wallpaperId == id
        return Button {
            importError = nil
            model.selectBuiltinWallpaper(id: id)
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 72, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}
