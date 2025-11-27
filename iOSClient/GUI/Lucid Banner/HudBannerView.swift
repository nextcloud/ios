// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

struct HudBannerView: View {
    @ObservedObject var state: LucidBannerState
    @Binding var isPresented: Bool

    private let circleSize: CGFloat = 90
    private let lineWidth: CGFloat = 8

    var body: some View {
        let progress = min(max(state.progress ?? 0, 0), 1) // clamp 0...1

        ZStack {
            if isPresented {
                // Background dim
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)

                containerView {
                    VStack(spacing: 18) {

                        // TITLE
                        if let title = state.title, !title.isEmpty {
                            Text(title)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }

                        // SUBTITLE
                        if let subtitle = state.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.95))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }

                        // PROGRESS CIRCLE
                        ZStack {
                            Circle()
                                .stroke(
                                    .white.opacity(0.22),
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                                )
                                .frame(width: circleSize, height: circleSize)

                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    .white,
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: circleSize, height: circleSize)
                                .animation(.easeInOut(duration: 0.20), value: progress)

                            Text("\(Int(progress * 100))%")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isPresented)
    }

    // MARK: - Container

    @ViewBuilder
    private func containerView<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if #available(iOS 26, *) {
            content()
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black.opacity(0.45))
                )
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        } else {
            content()
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.85), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.30), radius: 16, x: 0, y: 8)
        }
    }
}

// MARK: - Preview

#Preview("HudBannerView") {
    ZStack {
        LinearGradient(colors: [.blue.opacity(0.4), .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

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

    @State private var show = true

    var body: some View {
        HudBannerView(state: state, isPresented: $show)
            .task {
                for i in 0...100 {
                    try? await Task.sleep(nanoseconds: 45_000_000)
                    state.progress = Double(i) / 100
                }
                show = false
            }
    }
}
