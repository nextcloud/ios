// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

struct ErrorBannerView: View {
    @ObservedObject var state: LucidBannerState

    var body: some View {
        let showSubtitle = !(state.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showFootnote = !(state.footnote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        containerView {
            VStack(spacing: 15) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("_error_")
                            .font(.subheadline.weight(.bold))
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(.white)

                        if showSubtitle, let subtitle = state.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .lineLimit(4)
                                .truncationMode(.tail)
                                .foregroundStyle(.white)
                        }
                        if showFootnote, let footnote = state.footnote {
                            Text(footnote)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Container

    @ViewBuilder
    func containerView<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if #available(iOS 26, *) {
            content()
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.red.opacity(1))
                )
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

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [.white, .gray.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )

        ErrorBannerView(
            state: LucidBannerState(
                title: "Error",
                subtitle: "Not avalilable",
                footnote: "ErroCode. 12",
                imageAnimation: .breathe)
        )
        .padding()
    }
}
