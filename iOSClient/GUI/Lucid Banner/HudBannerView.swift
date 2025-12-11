// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

struct HudBannerView: View {
    @ObservedObject var state: LucidBannerState
    @State private var displayedProgress: Double = 0

    private let circleSize: CGFloat = 90
    private let lineWidth: CGFloat = 8

    var body: some View {
        let rawProgress = state.progress ?? 0
        let clampedProgress = min(max(rawProgress, 0), 1)

        let stage = state.stage?.lowercased()
        let isSuccess = (stage == "success")
        let isError = (stage == "error")

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
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }

                // SUBTITLE
                if let subtitle = state.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.95))
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
                    // - checkmark for success
                    // - xmark for error
                    // - percentage for normal progress
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
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.top, 4)
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
        if #available(iOS 26, *) {
            content()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
        } else {
            content()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Helper

@MainActor
func showHudBanner(scene: UIWindowScene?, title: String? = nil, subtitle: String? = nil, onTap: ((_ token: Int?, _ stage: String?) -> Void)? = nil) -> Int? {
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
        onTap: { token, stage in
            onTap?(token, stage)
        }
    ) { state in
        HudBannerView(state: state)
    }
}

@MainActor
func completeHudBannerSuccess(
    token: Int?
) {
    LucidBanner.shared.update(
        stage: .success,
        autoDismissAfter: 2,
        for: token
    )
}

@MainActor
func completeHudBannerError(
    subtitle: String? = nil,
    token: Int?
) {
    LucidBanner.shared.update(
        subtitle: subtitle,
        stage: .error,
        autoDismissAfter: NCGlobal.shared.dismissAfterSecond,
        for: token
    )
}

// MARK: - Preview

#Preview("HudBannerView") {
    ZStack {
        HudBannerPreviewWrapper()
    }
}

private struct HudBannerPreviewWrapper: View {
    @StateObject private var state = LucidBannerState(
        title: "Uploading files",
        subtitle: "Syncing your library…",
        footnote: nil,
        imageAnimation: .none
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
