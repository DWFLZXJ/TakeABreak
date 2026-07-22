import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isImportingWallpaper = false
    @State private var importError: String?
    /// Bumps when custom wallpaper changes so the thumbnail refreshes.
    @State private var customThumbToken = 0

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
                    customWallpaperButton
                }
                if model.preferences.wallpaperId == "custom" {
                    Text("已使用自定义图片作为休息壁纸")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("点击 + 选择本地图片")
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
        .fileImporter(
            isPresented: $isImportingWallpaper,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if let err = model.applyCustomWallpaper(from: url) {
                    importError = err
                } else {
                    importError = nil
                    customThumbToken += 1
                }
            case .failure(let error):
                importError = "无法选择图片：\(error.localizedDescription)"
            }
        }
        .onAppear {
            // If prefs say custom but file missing, fall back quietly is handled at break time.
            customThumbToken += 1
        }
    }

    private var customWallpaperButton: some View {
        let selected = model.preferences.wallpaperId == "custom"
        return Button {
            NSApp.activate(ignoringOtherApps: true)
            isImportingWallpaper = true
        } label: {
            ZStack {
                if let img = model.customWallpaperImage(), selected {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 48)
                        .clipped()
                        .cornerRadius(8)
                        .id(customThumbToken)
                } else if let img = model.customWallpaperImage() {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 48)
                        .clipped()
                        .cornerRadius(8)
                        .opacity(0.85)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        )
                        .id(customThumbToken)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .frame(width: 72, height: 48)
                    Image(systemName: "plus")
                }
            }
            .frame(width: 72, height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .help("选择本地图片")
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
            customThumbToken += 1
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
