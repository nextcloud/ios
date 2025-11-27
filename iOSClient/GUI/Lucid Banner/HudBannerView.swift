// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

struct HudBannerView: View {
    @ObservedObject var state: LucidBannerState

    private let circleSize: CGFloat = 90
    private let lineWidth: CGFloat = 8

    var body: some View {
        let progress = min(max(state.progress ?? 0, 0), 1) // clamp 0...1

        containerView {
            VStack(spacing: 18) {

                // TITLE
                if let title = state.title, !title.isEmpty {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                // SUBTITLE
                if let subtitle = state.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }

                // PROGRESS CIRCLE
                ZStack {
                    Circle()
                        .stroke(
                            .gray.opacity(0.1),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .frame(width: circleSize, height: circleSize)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            .primary,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: circleSize, height: circleSize)
                        .animation(.easeInOut(duration: 0.20), value: progress)

                    Text("\(Int(progress * 100))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.primary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
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
func showHudBanner(
    scene: UIWindowScene?,
    title: String? = nil,
    subtitle: String? = nil,
    onTap: ((_ token: Int, _ stage: String?) -> Void)? = nil) -> Int {

    LucidBanner.shared.show(
        scene: scene,
        title: title,
        subtitle: subtitle,
        maxWidth: 300,
        vPosition: .center,
        swipeToDismiss: false,
        blocksTouches: true,
        onTap: { token, stage in
            onTap?(token, stage)
        }
    ) { state in
        HudBannerView(state: state)
    }
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
            }
    }
}
