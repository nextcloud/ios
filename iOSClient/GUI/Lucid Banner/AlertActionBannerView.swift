// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

@MainActor
func showAlertActionBanner(lucidBanner: LucidBanner?,
                           title: String? = nil,
                           subtitle: String? = nil,
                           onConfirm: (() -> Void)? = nil) {
    guard let lucidBanner else {
        return
    }
    let isPad = lucidBanner.windowScene.traitCollection.userInterfaceIdiom == .pad
    let horizontalLayout: LucidBanner.HorizontalLayout =
        isPad
        ? .centered(width: 450)
        : .stretch(margins: 20)

    let payload = LucidBannerPayload(
        title: title,
        subtitle: subtitle,
        vPosition: .top,
        horizontalLayout: horizontalLayout,
        swipeToDismiss: true
    )

    lucidBanner.show(payload: payload,
                     policy: .enqueue) { state in
        AlertActionBannerView(
            state: state,
            onConfirm: {
                onConfirm?()
                lucidBanner.dismiss()
            },
            onCancel: {
                lucidBanner.dismiss()
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
                // Title
                if let title = state.payload.title, !title.isEmpty {
                    Text(title)
                        .cappedFont(.title3, maxDynamicType: .accessibility2)
                        .fontWeight(.semibold)
                        .foregroundStyle(state.payload.textColor)
                        .multilineTextAlignment(.center)
                }

                // Subtitle
                if let subtitle = state.payload.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .cappedFont(.subheadline, maxDynamicType: .accessibility1)
                        .foregroundStyle(state.payload.textColor)
                        .multilineTextAlignment(.center)
                }

                // Buttons
                HStack(spacing: 12) {
                    Button {
                        onCancel?()
                    } label: {
                        Text("_cancel_")
                            .cappedFont(.footnote, maxDynamicType: .xxxLarge)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    )
                    .foregroundStyle(.primary)
                    .buttonStyle(.plain)

                    Button {
                        onConfirm?()
                    } label: {
                        Text("_ok_")
                            .cappedFont(.footnote, maxDynamicType: .xxxLarge)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
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
