// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

@MainActor
func showBanner(scene: UIWindowScene?,
                title: String?,
                subtitle: String? = nil,
                footnote: String? = nil,
                textColor: UIColor,
                image: String?,
                imageAnimation: LucidBanner.LucidBannerAnimationStyle,
                imageColor: UIColor,
                vPosition: LucidBanner.VerticalPosition = .top,
                backgroundColor: UIColor) async {
    var scene = scene
    if scene == nil {
        scene = UIApplication.shared.mainAppWindow?.windowScene
    }

    let payload = LucidBannerPayload(
        title: NSLocalizedString(title ?? "", comment: ""),
        subtitle: NSLocalizedString(subtitle ?? "", comment: ""),
        footnote: NSLocalizedString(footnote ?? "", comment: ""),
        systemImage: image,
        imageAnimation: imageAnimation,
        backgroundColor: Color(uiColor: backgroundColor),
        textColor: Color(uiColor: textColor),
        imageColor: Color(uiColor: imageColor),
        vPosition: vPosition,
        autoDismissAfter: NCGlobal.shared.dismissAfterSecond,
        swipeToDismiss: true
    )

    LucidBanner.shared.show(
        scene: scene,
        payload: payload,
        onTap: { _, _ in
            LucidBanner.shared.dismiss()
        }
    ) { state in
        MessageBannerView(state: state)
    }
}

@MainActor
func showInfoBanner(scene: UIWindowScene?,
                    title: String?,
                    subtitle: String? = nil,
                    footnote: String? = nil
    ) async {
    var scene = scene
    if scene == nil {
        scene = UIApplication.shared.mainAppWindow?.windowScene
    }

    let payload = LucidBannerPayload(
        title: NSLocalizedString(title ?? "", comment: ""),
        subtitle: NSLocalizedString(subtitle ?? "", comment: ""),
        footnote: NSLocalizedString(footnote ?? "", comment: ""),
        systemImage: "checkmark",
        backgroundColor: Color(uiColor: .black),
        textColor: .primary,
        imageColor: .white,
        vPosition: .top,
        autoDismissAfter: NCGlobal.shared.dismissAfterSecond,
        swipeToDismiss: true,
    )
    LucidBanner.shared.show(
        scene: scene,
        payload: payload,
        onTap: { _, _ in
            LucidBanner.shared.dismiss()
        }
    ) { state in
        MessageBannerView(state: state)
    }
}

@MainActor
func showErrorBanner(controller: UITabBarController?, errorDescription: String, footnote: String? = nil, sleepBefore: Double = 1) async {
    let scene = SceneManager.shared.getWindow(controller: controller)?.windowScene
    await showErrorBanner(scene: scene,
                          errorDescription: NSLocalizedString(errorDescription, comment: ""),
                          footnote: NSLocalizedString(footnote ?? "", comment: ""),
                          sleepBefore: sleepBefore)
}

@MainActor
func showErrorBanner(scene: UIWindowScene?, errorDescription: String, footnote: String? = nil, sleepBefore: Double = 1) async {
    try? await Task.sleep(nanoseconds: UInt64(sleepBefore * 1e9))
    var scene = scene
    if scene == nil {
        scene = UIApplication.shared.mainAppWindow?.windowScene
    }

    let payload = LucidBannerPayload(
        subtitle: NSLocalizedString(errorDescription, comment: ""),
        footnote: NSLocalizedString(footnote ?? "", comment: ""),
        systemImage: "xmark.circle.fill",
        backgroundColor: .red,
        textColor: .primary,
        imageColor: .white,
        vPosition: .top,
        autoDismissAfter: NCGlobal.shared.dismissAfterSecond,
        swipeToDismiss: true,
    )
    LucidBanner.shared.show(
        scene: scene,
        payload: payload,
        onTap: { _, _ in
            LucidBanner.shared.dismiss()
        }
    ) { state in
        MessageBannerView(state: state)
    }
}

// MARK: - SwiftUI

struct MessageBannerView: View {
    @ObservedObject var state: LucidBannerState

    var body: some View {
        let showTitle = !(state.payload.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showSubtitle = !(state.payload.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showFootnote = !(state.payload.footnote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        containerView(state: state, allowMinimizeOnTap: false) {
            VStack(spacing: 15) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: state.payload.systemImage ?? "info.circle")
                        .applyBannerAnimation(state.payload.imageAnimation)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(state.payload.imageColor)

                    VStack(alignment: .leading, spacing: 7) {
                        if showTitle, let title = state.payload.title {
                            Text(title)
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(state.payload.textColor)
                        }

                        if showSubtitle, let subtitle = state.payload.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(state.payload.textColor)
                        }
                        if showFootnote, let footnote = state.payload.footnote {
                            Text(footnote)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(state.payload.textColor)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            imageAnimation: .variableColor
        ))

        MessageBannerView(state: state)
        .padding()
    }
}
