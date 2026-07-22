import AppKit
import SwiftUI

struct BreakOverlayView: View {
    let message: String
    let remainingMs: Int
    let progress: Double
    let allowSkip: Bool
    let wallpaperId: String
    let wallpaperImage: NSImage?

    var onSkip: () -> Void

    @State private var holdProgress: CGFloat = 0
    @State private var holdTask: Task<Void, Never>?

    private let holdDuration: TimeInterval = 2.0

    var body: some View {
        ZStack {
            wallpaper
            Color.black.opacity(0.32)
            RadialGradient(
                colors: [.clear, .black.opacity(0.28)],
                center: .center,
                startRadius: 80,
                endRadius: 900
            )

            VStack(spacing: 20) {
                Text("休息中")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.45))

                Text(message)
                    .font(.system(size: 28, weight: .light))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 2)
                    .padding(.horizontal, 48)

                Text(TimeFormatting.mmss(fromMilliseconds: remainingMs))
                    .font(.system(size: 56, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 2)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        Capsule()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: max(0, geo.size.width * progress))
                    }
                }
                .frame(width: 160, height: 2)
            }

            if allowSkip {
                VStack {
                    Spacer()
                    skipControl
                        .padding(.bottom, 48)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var wallpaper: some View {
        if let wallpaperImage {
            Image(nsImage: wallpaperImage)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: gradientColors(for: wallpaperId),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var skipControl: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)
                Text("跳过")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginHoldIfNeeded() }
                    .onEnded { _ in cancelHold() }
            )
            Text("长按 2 秒跳过")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.28))
        }
    }

    private func beginHoldIfNeeded() {
        guard holdTask == nil else { return }
        holdProgress = 0
        holdTask = Task { @MainActor in
            let steps = 40
            let step = holdDuration / Double(steps)
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
                if Task.isCancelled { return }
                holdProgress = CGFloat(i) / CGFloat(steps)
            }
            holdTask = nil
            holdProgress = 0
            onSkip()
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        holdProgress = 0
    }

    private func gradientColors(for id: String) -> [Color] {
        switch id {
        case "default-2":
            return [Color(red: 0.94, green: 0.58, blue: 0.98), Color(red: 0.96, green: 0.34, blue: 0.42)]
        case "default-3":
            return [Color(red: 0.31, green: 0.67, blue: 1.0), Color(red: 0.0, green: 0.95, blue: 1.0)]
        default:
            return [Color(red: 0.15, green: 0.18, blue: 0.28), Color(red: 0.28, green: 0.35, blue: 0.55), Color(red: 0.12, green: 0.14, blue: 0.22)]
        }
    }
}
