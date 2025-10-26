// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ToastBannerView: View {
    @ObservedObject var state: LucidBannerState

    var body: some View {
        let showTitle = !state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let showSubtitle = !(state.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showProgress = (state.progress ?? 0) > 0
        let measuring = (state.flags["measuring"] as? Bool) ?? false

        VStack(spacing: 10) {
            HStack(alignment: .top, spacing:10) {
                if let systemImage = state.systemImage {
                    Image(systemName: systemImage)
                        .symbolRenderingMode(.monochrome)
                        .applyBannerAnimation(state.imageAnimation)
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 22, height: 22, alignment: .topLeading)
                        .foregroundStyle(Color(uiColor: state.imageColor))
                }

                VStack(alignment: .leading, spacing: 5) {
                    if showTitle {
                        Text(state.title)
                            .font(.subheadline.weight(.bold))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.9)
                            .foregroundStyle(Color(uiColor: state.textColor))
                    }
                    if showSubtitle, let s = state.subtitle {
                        Text(s)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
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
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .blendMode(.plusLighter)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.2))
                    .blendMode(.plusLighter)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .blendMode(.screen)
            }
            .compositingGroup()
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
        .frame(minHeight: 44, alignment: .leading)
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
            colors: [.white, .gray],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        ToastBannerView(
            state: LucidBannerState(
                title: "Downloading ...",
                subtitle: "Keep application active until the transfers are completed …",
                textColor: .label,
                systemImage: "gearshape.arrow.triangle.2.circlepath",
                imageColor: .red,
                imageAnimation: .rotate,
                progress: 0.12,
                progressColor: .systemBlue)
        )
        .padding()
    }
}
