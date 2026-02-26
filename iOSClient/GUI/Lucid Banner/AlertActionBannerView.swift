// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

@MainActor
func showAlertActionBannerView(scene: UIWindowScene?,
                               title: String? = nil,
                               subtitle: String? = nil,
                               onConfirm: (() -> Void)? = nil) {
    let payload = LucidBannerPayload(
        title: title,
        subtitle: subtitle,
        vPosition: .top,
        horizontalLayout: .stretch(margins: 100),
        swipeToDismiss: true
    )

    LucidBanner.shared.show(
        scene: scene,
        payload: payload,
        policy: .replace
    ) { state in
        AlertActionBannerView(
            state: state,
            onConfirm: {
                onConfirm?()
                LucidBanner.shared.dismiss()
            },
            onCancel: {
                LucidBanner.shared.dismiss()
            }
        )
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
                    Button("_cancel_") {
                        onCancel?()
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    )
                    .foregroundStyle(.primary)

                    // Confirm
                    Button("_ok_") {
                        onConfirm?()
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
                }
            }
            .padding(20)
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

#Preview("Alert - Light") {

    let payload = LucidBannerPayload(
        title: "Title ?",
        subtitle: "Subtitle.",
        stage: .warning,
        vPosition: .center,
        blocksTouches: true
    )

    let state = LucidBannerState(payload: payload)

    return ZStack {
        Color.black.opacity(0.15)
            .ignoresSafeArea()

        AlertActionBannerView(
            state: state,
            onConfirm: {
                print("Confirm tapped")
            },
            onCancel: {
                print("Cancel tapped")
            }
        )
        .padding()
    }
}
