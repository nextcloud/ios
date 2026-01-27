// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

// MARK: - Show Banner
#if !EXTENSION
@MainActor
func showBannerActiveScenes(title: String?,
                            subtitle: String? = nil,
                            footnote: String? = nil,
                            textColor: UIColor,
                            image: String?,
                            imageAnimation: LucidBanner.LucidBannerAnimationStyle,
                            imageColor: UIColor,
                            vPosition: LucidBanner.VerticalPosition = .top,
                            backgroundColor: UIColor) async {
    for scene in UIApplication.shared.foregroundActiveScenes {
        await showBanner(scene: scene,
                         title: title,
                         subtitle: subtitle,
                         footnote: footnote,
                         textColor: textColor,
                         image: image,
                         imageAnimation: imageAnimation,
                         imageColor: imageColor,
                         vPosition: vPosition,
                         backgroundColor: backgroundColor)
    }
}
#endif

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
#if !EXTENSION
    let scene = scene ?? UIApplication.shared.mainAppWindow?.windowScene
#endif
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
        payload: payload) { state in
        MessageBannerView(state: state)
    }
}

// MARK: - Show Info

#if !EXTENSION
@MainActor
func showInfoBannerActiveScenes(title: String = "_error_",
                                text: String,
                                footnote: String? = nil,
                                foregroundColor: UIColor = .label,
                                backgroundColor: UIColor = .systemBackground) async {
    for scene in UIApplication.shared.foregroundActiveScenes {
        await showInfoBanner(scene: scene,
                             title: title,
                             text: text,
                             footnote: footnote,
                             foregroundColor: foregroundColor,
                             backgroundColor: backgroundColor)
    }
}

@MainActor
func showInfoBanner(controller: UITabBarController?,
                    title: String = "_info_",
                    text: String,
                    footnote: String? = nil,
                    foregroundColor: UIColor = .label,
                    backgroundColor: UIColor = .systemBackground) async {
    let scene = SceneManager.shared.getWindow(controller: controller)?.windowScene
    await showInfoBanner(scene: scene,
                         title: title,
                         text: text,
                         foregroundColor: foregroundColor,
                         backgroundColor: backgroundColor)
}

@MainActor
func showInfoBanner(sceneIdentifier: String?,
                    title: String = "_error_",
                    text: String,
                    footnote: String? = nil,
                    foregroundColor: UIColor = .label,
                    backgroundColor: UIColor = .systemBackground) async {
    await showInfoBanner(controller: SceneManager.shared.getController(sceneIdentifier: sceneIdentifier),
                         title: title,
                         text: text,
                         footnote: footnote,
                         foregroundColor: foregroundColor,
                         backgroundColor: backgroundColor)
}

#endif

@MainActor
func showInfoBanner(scene: UIWindowScene?,
                    title: String = "_info_",
                    text: String,
                    footnote: String? = nil,
                    foregroundColor: UIColor = .label,
                    backgroundColor: UIColor = .systemBackground) async {
#if !EXTENSION
    let scene = scene ?? UIApplication.shared.mainAppWindow?.windowScene
#endif

    let payload = LucidBannerPayload(
        title: NSLocalizedString(title, comment: ""),
        subtitle: NSLocalizedString(text, comment: ""),
        footnote: NSLocalizedString(footnote ?? "", comment: ""),
        systemImage: "checkmark.circle",
        backgroundColor: Color(uiColor: backgroundColor),
        textColor: Color(uiColor: foregroundColor),
        imageColor: Color(uiColor: NCBrandColor.shared.customer),
        vPosition: .top,
        horizontalMargin: 20,
        verticalMargin: 10,
        autoDismissAfter: NCGlobal.shared.dismissAfterSecond,
        swipeToDismiss: true,
    )
    LucidBanner.shared.show(
        scene: scene,
        payload: payload) { state in
            MessageBannerView(state: state)
        }
}

// MARK: - Show Error

#if !EXTENSION
@MainActor
func showErrorBannerActiveScenes(title: String = "_error_",
                                 text: String,
                                 footnote: String? = nil,
                                 foregroundColor: UIColor = .white,
                                 backgroundColor: UIColor = .red,
                                 sleepBefore: Double = 1) async {
    for scene in UIApplication.shared.foregroundActiveScenes {
        await showErrorBanner(scene: scene,
                              title: title,
                              text: text,
                              footnote: footnote,
                              foregroundColor: foregroundColor,
                              backgroundColor: backgroundColor,
                              sleepBefore: sleepBefore)
    }
}

@MainActor
func showErrorBanner(controller: UITabBarController?,
                     title: String = "_error_",
                     text: String,
                     footnote: String? = nil,
                     foregroundColor: UIColor = .white,
                     backgroundColor: UIColor = .red,
                     sleepBefore: Double = 1) async {
    let scene = SceneManager.shared.getWindow(controller: controller)?.windowScene
    await showErrorBanner(scene: scene,
                          text: text,
                          footnote: footnote,
                          foregroundColor: foregroundColor,
                          backgroundColor: backgroundColor,
                          sleepBefore: sleepBefore)
}

@MainActor
func showErrorBanner(sceneIdentifier: String?,
                     title: String = "_error_",
                     text: String,
                     footnote: String? = nil,
                     foregroundColor: UIColor = .white,
                     backgroundColor: UIColor = .red,
                     sleepBefore: Double = 1) async {
    await showErrorBanner(controller: SceneManager.shared.getController(sceneIdentifier: sceneIdentifier),
                          title: title,
                          text: text,
                          footnote: footnote,
                          foregroundColor: foregroundColor,
                          backgroundColor: backgroundColor,
                          sleepBefore: sleepBefore)
}

#endif

@MainActor
func showErrorBanner(scene: UIWindowScene?,
                     title: String = "_error_",
                     text: String,
                     footnote: String? = nil,
                     foregroundColor: UIColor = .white,
                     backgroundColor: UIColor = .red,
                     sleepBefore: Double = 1) async {
    try? await Task.sleep(nanoseconds: UInt64(sleepBefore * 1e9))
#if !EXTENSION
    let scene = scene ?? UIApplication.shared.mainAppWindow?.windowScene
#endif

    let payload = LucidBannerPayload(
        title: NSLocalizedString(title, comment: ""),
        subtitle: NSLocalizedString(text, comment: ""),
        footnote: NSLocalizedString(footnote ?? "", comment: ""),
        systemImage: "xmark.circle.fill",
        backgroundColor: Color(uiColor: backgroundColor),
        textColor: Color(uiColor: foregroundColor),
        imageColor: .white,
        vPosition: .top,
        horizontalMargin: 20,
        verticalMargin: 10,
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
                        .font(.system(size: 30, weight: .regular))
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
            imageAnimation: .drawOn
        ))

        MessageBannerView(state: state)
        .padding()
    }
}
