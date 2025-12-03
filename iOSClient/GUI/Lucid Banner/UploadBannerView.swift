// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

struct UploadBannerView: View {
    @ObservedObject var state: LucidBannerState

    var body: some View {
        let showTitle = !(state.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showSubtitle = !(state.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showFootnote = !(state.footnote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        containerView(state: state) {
            VStack(spacing: 15) {
                HStack(alignment: .top, spacing: 10) {
                    if state.stage == "error" {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        if let systemImage = state.systemImage {
                            Image(systemName: systemImage)
                                .applyBannerAnimation(state.imageAnimation)
                                .font(.system(size: 30, weight: .regular))
                                .foregroundStyle(Color(uiColor: NCBrandColor.shared.customer))
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        if showTitle, let title = state.title {
                            Text(title)
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.9)
                                .foregroundStyle(.primary)
                        }
                        if showSubtitle, let subtitle = state.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(.primary)
                        }
                        if showFootnote, let footnote = state.footnote {
                            Text(footnote)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(.primary)
                        }
                    }
                }

                ProgressView(value: state.progress ?? 0)
                    .tint(.accentColor)
                    .opacity(state.progress == nil ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: state.progress == nil)

            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Container

    @ViewBuilder
    func containerView<Content: View>(state: LucidBannerState, @ViewBuilder _ content: () -> Content) -> some View {
        if #available(iOS 26, *) {
            if state.stage == "error" {
                content()
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.red.opacity(1))
                    )
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
            } else {
                content()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
            }
        } else {
            let colorBg = state.stage == "error" ? Color.red.opacity(0.9) : Color.white.opacity(0.9)
            content()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(colorBg, lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
        }
    }
}

public extension View {
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
            case .scaleUpbyLayer:
                self.symbolEffect(.scale.up.byLayer, options: .repeat(.continuous))
            case .none:
                self
            }
        } else {
            self
        }
    }
}

// MARK: - Helper

@MainActor
func showUploadBanner(
    scene: UIWindowScene?,
    title: String? = nil,
    subtitle: String? = nil,
    footnote: String? = nil,
    systemImage: String?,
    imageAnimation: LucidBanner.LucidBannerAnimationStyle = .none,
    stage: String? = nil,
    onTap: ((_ token: Int, _ stage: String?) -> Void)? = nil) -> Int {

    return LucidBanner.shared.show(
        scene: scene,
        title: title,
        subtitle: subtitle,
        footnote: footnote,
        systemImage: systemImage,
        imageAnimation: imageAnimation,
        vPosition: .bottom,
        hAlignment: .center,
        verticalMargin: 55,
        swipeToDismiss: false,
        stage: stage,
        onTap: { token, stage in
            onTap?(token, stage)
        }
    ) { state in
        UploadBannerView(state: state)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [.white, .gray.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )

        UploadBannerView(
            state: LucidBannerState(
                title: "Downloading …",
                subtitle: "Keep application active until the transfers are completed …",
                footnote: "Touch for cancel",
                systemImage: "gearshape.arrow.triangle.2.circlepath",
                imageAnimation: .rotate,
                progress: 0.42)
        )
        .padding()
    }
}
