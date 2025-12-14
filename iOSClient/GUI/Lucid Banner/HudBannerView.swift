// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

@MainActor
func showHudBanner(scene: UIWindowScene?,
                   title: String? = nil,
                   subtitle: String? = nil,
                   stage: LucidBanner.Stage? = nil,
                   onButtonTap: (() -> Void)? = nil) -> Int? {
    var scene = scene
    if scene == nil {
        scene = UIApplication.shared.mainAppWindow?.windowScene
    }

    return LucidBanner.shared.show(
        scene: scene,
        title: title,
        subtitle: subtitle,
        vPosition: .center,
        blocksTouches: true,
        stage: stage
    ) { state in
        HudBannerView(state: state, onButtonTap: onButtonTap)
    }
}

@MainActor
func completeHudBannerSuccess(token: Int?) {
    LucidBanner.shared.update(
        stage: .success,
        autoDismissAfter: 2,
        for: token
    )
}

@MainActor
func completeHudBannerError(subtitle: String? = nil, token: Int?) {
    LucidBanner.shared.update(
        subtitle: subtitle,
        stage: .error,
        autoDismissAfter: NCGlobal.shared.dismissAfterSecond,
        for: token
    )
}

// MARK: - SwiftUI

struct HudBannerView: View {
    @ObservedObject var state: LucidBannerState
    @State private var displayedProgress: Double = 0

    let onButtonTap: (() -> Void)?

    private let textColor = Color(.label)
    private let circleSize: CGFloat = 90
    private let lineWidth: CGFloat = 8

    init(state: LucidBannerState,
         onButtonTap: (() -> Void)? = nil) {
        self.state = state
        self.onButtonTap = onButtonTap
    }

    var body: some View {
        let rawProgress = state.progress ?? 0
        let clampedProgress = min(max(rawProgress, 0), 1)

        let isSuccess = (state.typedStage == .success)
        let isError = (state.typedStage == .error)
        let isButton = (state.typedStage == .button)

        let visualProgress: Double = {
            if isSuccess || isError {
                return 1.0
            } else {
                return displayedProgress
            }
        }()

        let strokeColor: Color = {
            if isSuccess { return .green }
            if isError { return .red }
            return .primary
        }()

        containerView {
            VStack(spacing: 18) {

                // TITLE
                if let title = state.title, !title.isEmpty {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.center)
                }

                // SUBTITLE
                if let subtitle = state.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.center)
                }

                // PROGRESS CIRCLE + CENTER CONTENT
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(
                            .gray.opacity(0.1),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .frame(width: circleSize, height: circleSize)

                    // Foreground ring
                    Circle()
                        .trim(from: 0, to: visualProgress)
                        .stroke(
                            strokeColor,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: circleSize, height: circleSize)

                    // Center content:
                    Group {
                        if isSuccess {
                            Image(systemName: "checkmark")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(strokeColor)
                        } else if isError {
                            Image(systemName: "xmark")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(strokeColor)
                        } else {
                            Text("\(Int(visualProgress * 100))%")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(textColor)
                        }
                    }
                }
                .padding(.top, 4)

                if isButton {
                    VStack {
                        Button("_cancel_") {
                            onButtonTap?()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(.gray, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
        }
        .onAppear {
            displayedProgress = clampedProgress
        }
        .onChange(of: state.progress) { _, newValue in
            guard let newValue else {
                withTransaction(Transaction(animation: nil)) {
                    displayedProgress = 0
                }
                return
            }

            let newClamped = min(max(newValue, 0), 1)

            if newClamped < displayedProgress {
                let wasComplete = displayedProgress >= 0.95
                let isNewStart = newClamped <= 0.1

                if wasComplete && isNewStart {
                    withTransaction(Transaction(animation: nil)) {
                        displayedProgress = newClamped
                    }
                } else {
                    return
                }
            } else {
                withAnimation(.easeInOut(duration: 0.20)) {
                    displayedProgress = newClamped
                }
            }
        }
        .onChange(of: state.stage) { _, newStage in
            let lower = newStage?.lowercased()
            if lower == "success" || lower == "error" {
                withAnimation(.easeInOut(duration: 0.20)) {
                    displayedProgress = 1.0
                }
            }
        }
    }

    // MARK: - Container

    @ViewBuilder
    func containerView<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let cornerRadius: CGFloat = 22
        let opacity = 0.65
        let backgroundColor = Color(.systemBackground).opacity(0.65)

        if #available(iOS 26, *) {
            content()
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                )
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Preview

#Preview("HudBannerView") {
    ZStack {
        Text(
            Array(0...500)
                .map(String.init)
                .joined(separator: "  ")
            )
            .font(.system(size: 16, design: .monospaced))
            .foregroundStyle(.primary)
            .padding()

        HudBannerPreviewWrapper()
    }
}

private struct HudBannerPreviewWrapper: View {
    @StateObject private var state = LucidBannerState(
        title: "Uploading files",
        subtitle: "Syncing your library…",
        footnote: nil,
        imageAnimation: .none,
        stage: "button"
    )

    var body: some View {
        HudBannerView(state: state)
            .task {
                for i in 0...100 {
                    try? await Task.sleep(nanoseconds: 45_000_000)
                    state.progress = Double(i) / 100
                }

                try? await Task.sleep(nanoseconds: 400_000_000)
                state.stage = "error"
            }
    }
}
