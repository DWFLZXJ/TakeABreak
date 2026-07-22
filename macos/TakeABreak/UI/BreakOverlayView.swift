import AppKit
import SwiftUI

struct BreakOverlayView: View {
    let message: String
    /// Random famous quote / poem line for this break session.
    let quote: QuoteItem
    /// Enabled todo reminder lines for this break.
    let todos: [String]
    let remainingMs: Int
    let progress: Double
    let allowSkip: Bool
    let wallpaperImage: NSImage?

    var onSkip: () -> Void

    @State private var holdProgress: CGFloat = 0
    @State private var holdTask: Task<Void, Never>?
    @State private var isHolding = false

    /// Skip button center in container coordinates.
    @State private var skipOrigin: CGPoint = .zero
    @State private var containerSize: CGSize = .zero
    @State private var fleeTask: Task<Void, Never>?
    @State private var ghostOrigin: CGPoint?
    @State private var spinAngle: Double = 0
    @State private var pulse = false
    @State private var hoverFleeTask: Task<Void, Never>?

    private let holdDuration: TimeInterval = 2.0
    private let skipButtonSize: CGFloat = 84
    private let labelExtraHeight: CGFloat = 28
    /// Auto-jump interval (slower = easier to catch).
    private let fleeIntervalNs: ClosedRange<UInt64> = 2_200_000_000...3_600_000_000
    /// Grace time after pointer enters before it flees — enough to click/hold.
    private let hoverFleeDelayNs: UInt64 = 450_000_000

    var body: some View {
        ZStack {
            wallpaperLayer
            Color.black.opacity(0.32)
            RadialGradient(
                colors: [.clear, .black.opacity(0.28)],
                center: .center,
                startRadius: 80,
                endRadius: 900
            )

            VStack(spacing: 18) {
                Text("休息中")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.45))

                Text(message)
                    .font(.system(size: 26, weight: .light))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 2)
                    .padding(.horizontal, 48)

                VStack(spacing: 8) {
                    Text(quote.text)
                        .font(.system(size: 17, weight: .regular))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.78))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 1)
                        .padding(.horizontal, 56)
                        .lineLimit(4)
                    Text("—— \(quote.source)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.top, 4)

                if !todos.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("待办提醒")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .center)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(todos.prefix(8).enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(Color.cyan.opacity(0.75))
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 7)
                                    Text(item)
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundStyle(.white.opacity(0.88))
                                        .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .frame(maxWidth: 420)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.28))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.top, 8)
                }

                Text(TimeFormatting.mmss(fromMilliseconds: remainingMs))
                    .font(.system(size: 56, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 2)
                    .padding(.top, 6)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        Capsule()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: max(0, geo.size.width * progress))
                    }
                }
                .frame(width: 160, height: 2)

                if allowSkip {
                    Text("抓住乱跳的「跳过」并长按 2 秒")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.28))
                        .padding(.top, 20)
                }
            }

            if allowSkip {
                GeometryReader { geo in
                    ZStack {
                        // Ghost trail
                        if let ghost = ghostOrigin, !isHolding {
                            skipButtonVisual(hold: 0, interactive: false)
                                .position(ghost)
                                .opacity(0.22)
                                .blur(radius: 1.5)
                                .allowsHitTesting(false)
                        }

                        skipButton
                            .position(skipOrigin == .zero ? CGPoint(x: geo.size.width / 2, y: geo.size.height - 80) : skipOrigin)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear {
                        containerSize = geo.size
                        if skipOrigin == .zero {
                            skipOrigin = randomPoint(in: geo.size)
                        }
                        startFleeLoop()
                        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                            spinAngle = 360
                        }
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
                    .onChange(of: geo.size) { newSize in
                        containerSize = newSize
                        skipOrigin = clamp(skipOrigin, in: newSize)
                    }
                    .onDisappear {
                        stopFleeLoop()
                        cancelHold()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    // MARK: - Skip button (fleeing)

    private var skipButton: some View {
        VStack(spacing: 6) {
            skipButtonVisual(hold: holdProgress, interactive: true)
                // Larger hit area so catching is fairer
                .contentShape(Circle().scale(1.35))
                .onHover { hovering in
                    hoverFleeTask?.cancel()
                    hoverFleeTask = nil
                    // Delay flee so the user has a window to press and hold.
                    guard hovering, !isHolding else { return }
                    hoverFleeTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: hoverFleeDelayNs)
                        guard !Task.isCancelled, !isHolding else { return }
                        fleeNow(aggressive: false)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            hoverFleeTask?.cancel()
                            hoverFleeTask = nil
                            beginHoldIfNeeded()
                        }
                        .onEnded { _ in
                            cancelHold()
                        }
                )

            Text(isHolding ? "按住别松…" : "长按 2 秒")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(isHolding ? 0.75 : 0.35))
                .shadow(color: .black.opacity(0.5), radius: 4)
        }
        .frame(width: skipButtonSize + 24, height: skipButtonSize + labelExtraHeight)
    }

    private func skipButtonVisual(hold: CGFloat, interactive: Bool) -> some View {
        let glow = isHolding ? Color.cyan.opacity(0.85) : Color.white.opacity(0.55)
        return ZStack {
            // Soft outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (isHolding ? Color.cyan : Color.white).opacity(pulse ? 0.28 : 0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: skipButtonSize * 0.85
                    )
                )
                .frame(width: skipButtonSize + 36, height: skipButtonSize + 36)
                .scaleEffect(pulse && interactive ? 1.08 : 1.0)

            // Orbit dashed ring
            Circle()
                .stroke(
                    style: StrokeStyle(lineWidth: 1.2, dash: [3, 5])
                )
                .foregroundStyle(Color.white.opacity(0.25))
                .frame(width: skipButtonSize + 10, height: skipButtonSize + 10)
                .rotationEffect(.degrees(interactive ? spinAngle : 0))

            // Core plate
            Circle()
                .fill(Color.black.opacity(0.45))
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.cyan.opacity(isHolding ? 0.9 : 0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .frame(width: skipButtonSize, height: skipButtonSize)
                .shadow(color: glow.opacity(0.55), radius: isHolding ? 16 : 8)

            // Hold progress ring
            Circle()
                .trim(from: 0, to: hold)
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .white, .mint, .cyan],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: skipButtonSize - 6, height: skipButtonSize - 6)

            VStack(spacing: 2) {
                Image(systemName: isHolding ? "hand.tap.fill" : "hare.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .symbolEffect(.bounce, value: skipOrigin.x)
                Text("跳过")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
            }
        }
        .frame(width: skipButtonSize + 36, height: skipButtonSize + 36)
        .scaleEffect(isHolding ? 1.08 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.55), value: isHolding)
    }

    // MARK: - Flee motion

    private func startFleeLoop() {
        stopFleeLoop()
        fleeTask = Task { @MainActor in
            while !Task.isCancelled {
                let ns = UInt64.random(in: fleeIntervalNs)
                try? await Task.sleep(nanoseconds: ns)
                if Task.isCancelled { break }
                if !isHolding {
                    // Short hops — still playful, but catchable.
                    fleeNow(maxJumpRatio: 0.35)
                }
            }
        }
    }

    private func stopFleeLoop() {
        fleeTask?.cancel()
        fleeTask = nil
        hoverFleeTask?.cancel()
        hoverFleeTask = nil
    }

    /// - Parameter maxJumpRatio: fraction of screen diagonal for max jump distance (smaller = easier).
    private func fleeNow(maxJumpRatio: CGFloat = 0.35) {
        guard containerSize.width > 1, containerSize.height > 1 else { return }
        ghostOrigin = skipOrigin
        let next = randomNearbyPoint(from: skipOrigin, in: containerSize, maxJumpRatio: maxJumpRatio)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            skipOrigin = next
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 320_000_000)
            if ghostOrigin != nil {
                withAnimation(.easeOut(duration: 0.25)) {
                    ghostOrigin = nil
                }
            }
        }
    }

    private func randomPoint(in size: CGSize) -> CGPoint {
        let marginX = skipButtonSize
        let marginY = skipButtonSize + labelExtraHeight
        let minX = marginX
        let maxX = max(marginX, size.width - marginX)
        let minY = marginY + 40
        let maxY = max(minY, size.height - marginY - 20)
        return CGPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY)
        )
    }

    /// Jump a limited distance so the button does not teleport across the whole screen.
    private func randomNearbyPoint(from current: CGPoint, in size: CGSize, maxJumpRatio: CGFloat) -> CGPoint {
        let diagonal = hypot(size.width, size.height)
        let maxJump = max(120, diagonal * maxJumpRatio)
        let minJump = max(48, maxJump * 0.35)

        for _ in 0..<12 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: minJump...maxJump)
            let candidate = CGPoint(
                x: current.x + cos(angle) * dist,
                y: current.y + sin(angle) * dist
            )
            let clamped = clamp(candidate, in: size)
            if hypot(clamped.x - current.x, clamped.y - current.y) >= minJump * 0.5 {
                return clamped
            }
        }
        return randomPoint(in: size)
    }

    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let marginX = skipButtonSize
        let marginY = skipButtonSize + labelExtraHeight
        return CGPoint(
            x: min(max(point.x, marginX), max(marginX, size.width - marginX)),
            y: min(max(point.y, marginY), max(marginY, size.height - marginY))
        )
    }

    // MARK: - Hold

    private func beginHoldIfNeeded() {
        guard holdTask == nil else { return }
        isHolding = true
        hoverFleeTask?.cancel()
        hoverFleeTask = nil
        holdProgress = 0
        holdTask = Task { @MainActor in
            let steps = 50
            let step = holdDuration / Double(steps)
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
                if Task.isCancelled { return }
                holdProgress = CGFloat(i) / CGFloat(steps)
            }
            holdTask = nil
            isHolding = false
            holdProgress = 0
            onSkip()
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        isHolding = false
        holdProgress = 0
    }

    // MARK: - Wallpaper

    @ViewBuilder
    private var wallpaperLayer: some View {
        if let wallpaperImage {
            Image(nsImage: wallpaperImage)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.14, blue: 0.18),
                    Color(red: 0.18, green: 0.22, blue: 0.28),
                    Color(red: 0.10, green: 0.11, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
