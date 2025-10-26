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

        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                if #available(iOS 18, *) {
                    Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                        .symbolEffect(.rotate, options: .repeat(.continuous))
                        .foregroundStyle(Color(uiColor: NCBrandColor.shared.customer))
                } else {
                    Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                }

                if showTitle || showSubtitle {
                    VStack(alignment: .leading, spacing: 4) {
                        if showTitle {
                            Text(state.title)
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.9)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(Color(uiColor: NCBrandColor.shared.customer))
                        }
                        if showSubtitle, let s = state.subtitle {
                            Text(s)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(Color(uiColor: NCBrandColor.shared.customer))
                        }
                    }
                }
            }

            if showProgress && !measuring {
                ProgressView(value: min(state.progress ?? 0, 1))
                    .progressViewStyle(.linear)
                    .tint(Color(uiColor: NCBrandColor.shared.customer))
                    .scaleEffect(x: 1, y: 0.8, anchor: .center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
        .frame(minHeight: 44, alignment: .leading)
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
                title: "Uploading large file…",
                subtitle: "Please keep the app active until the process completes.",
                progress: 0.45
            )
        )
        .padding()
    }
}
