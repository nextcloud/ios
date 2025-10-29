// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

struct ToastBannerView: View {
    @ObservedObject var state: LucidBannerState

    var body: some View {
        let showTitle = !state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let showSubtitle = !(state.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showFootnote = !(state.footnote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showProgress = (state.progress ?? 0) > 0
        let measuring = (state.flags["measuring"] as? Bool) ?? false

        containerView {
            VStack(spacing: 15) {
                HStack(alignment: .top, spacing: 10) {
                    if let systemImage = state.systemImage {
                        Image(systemName: systemImage)
                            .symbolRenderingMode(.monochrome)
                            .applyBannerAnimation(state.imageAnimation)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Color(uiColor: state.imageColor))
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        if showTitle {
                            Text(state.title)
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.9)
                                .foregroundStyle(Color(uiColor: state.textColor))
                        }
                        if showSubtitle, let subtitle = state.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                                .truncationMode(.tail)
                                .foregroundStyle(Color(uiColor: state.textColor))
                        }
                        if showFootnote, let footnote = state.footnote {
                            Text(footnote)
                                .font(.caption2)
                                .multilineTextAlignment(.leading)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(Color(uiColor: state.textColor))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                if showProgress && !measuring {
                    ProgressView(value: min(state.progress ?? 0, 1))
                        .progressViewStyle(.linear)
                        .tint(Color(uiColor: state.progressColor))
                        .scaleEffect(x: 1, y: 0.8, anchor: .center)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: 44, alignment: .leading)
        }
    }

    @ViewBuilder
    func containerView<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                content()
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.9), lineWidth: 0.6)
                    )
            }
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

private extension View {
    @ViewBuilder
    func applyBannerAnimation(_ style: LucidBanner.LucidBannerAnimationStyle) -> some View {
        if #available(iOS 18, *) {
            switch style {
            case .rotate:
                self.symbolEffect(.rotate, options: .repeat(.continuous))
            case .pulse:
                self.symbolEffect(.pulse, options: .repeat(.continuous))
            case .pulsebyLayer:
                self.symbolEffect(.pulse.byLayer, options: .repeat(.continuous))
            case .breathe:
                self.symbolEffect(.breathe, options: .repeat(.continuous))
            case .bounce:
                self.symbolEffect(.bounce, options: .repeat(.continuous))
            case .wiggle:
                self.symbolEffect(.wiggle, options: .repeat(.continuous))
            case .scale:
                self.symbolEffect(.scale, options: .repeat(.continuous))
            case .none:
                self
            }
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [.white, .red],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        ToastBannerView(
            state: LucidBannerState(
                title: "Downloading …",
                subtitle: "Keep application active until the transfers are completed …",
                footnote: "Touch for cancel",
                textColor: .label,
                systemImage: "gearshape.arrow.triangle.2.circlepath",
                imageColor: .red,
                imageAnimation: .rotate,
                progress: 0.42,
                progressColor: .systemBlue)
        )
        .padding()
    }
}
