// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

@MainActor
func showAlertActionBannerView(scene: UIWindowScene?,
                               title: String? = nil,
                               subtitle: String? = nil,
                               stage: LucidBanner.Stage? = nil,
                               onButtonTap: (() -> Void)? = nil) -> Int? {
    let scene = scene ?? UIApplication.shared.mainAppWindow?.windowScene
    let localizedTitle = title.map { NSLocalizedString($0, comment: "") }
    let localizedSubTitle = subtitle.map { NSLocalizedString($0, comment: "") }

    let payload = LucidBannerPayload(
        title: localizedTitle,
        subtitle: localizedSubTitle,
        stage: stage,
        vPosition: .center,
        blocksTouches: true,
    )

    return LucidBanner.shared.show(
        scene: scene,
        payload: payload
    ) { state in
        HudBannerView(state: state, onButtonTap: onButtonTap)
    }
}

// MARK: - SwiftUI

struct AlertActionBannerView: View {

    @ObservedObject var state: LucidBannerState

    let onConfirm: (() -> Void)?
    let onCancel: (() -> Void)?

    init(
        state: LucidBannerState,
        onConfirm: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.state = state
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        alertActionContainerView {
            VStack(spacing: 20) {

                // MARK: - Title
                if let title = state.payload.title, !title.isEmpty {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(state.payload.textColor)
                        .multilineTextAlignment(.center)
                }

                // MARK: - Subtitle
                if let subtitle = state.payload.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(state.payload.textColor)
                        .multilineTextAlignment(.center)
                }

                // MARK: - Buttons
                HStack(spacing: 12) {

                    // Cancel
                    Button {
                        onCancel?()
                        //dismiss()
                    } label: {
                        Text("Annulla")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)

                    // Confirm
                    Button {
                        onConfirm?()
                      
                    } label: {
                        Text("OK")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

    // MARK: - Container

    @ViewBuilder
    func alertActionContainerView<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let cornerRadius: CGFloat = 22
        let backgroundColor = Color(.systemBackground).opacity(0.9)

        if #available(iOS 26, *) {
            content()
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                        .id(backgroundColor)
                )
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
        } else {
            content()
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                        .id(backgroundColor)
                )
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(backgroundColor, lineWidth: 0.6)
                        .allowsHitTesting(false)
                )
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Text(
            Array(0...500)
                .map(String.init)
                .joined(separator: "  ")
            )
            .font(.system(size: 16, design: .monospaced))
            .foregroundStyle(.primary)
            .padding()

        let state = LucidBannerState(payload: LucidBannerPayload(
            title: "Title",
            subtitle: "Subtitle",
            footnote: "footnote",
            systemImage: "wifi.circle",
            imageAnimation: .drawOn
        ))

        //MessageBannerView(state: state)
        //.padding()
    }
}
