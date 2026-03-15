// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner
import NextcloudKit
import Alamofire

// MARK: - Show Banner

@discardableResult
@MainActor
func showBanner(windowScene: UIWindowScene?,
                title: String?,
                subtitle: String? = nil,
                footnote: String? = nil,
                systemImage: String?,
                imageAnimation: LucidBanner.LucidBannerAnimationStyle,
                backgroundColor: UIColor = .systemBackground.withAlphaComponent(0.4),
                textColor: UIColor = .label,
                imageColor: UIColor,
                vPosition: LucidBanner.VerticalPosition = .top,
                verticalMargin: CGFloat = 10,
                autoDismissAfter: TimeInterval = NCGlobal.shared.dismissAfterSecond,
                swipeToDismiss: Bool = true,
                policy: LucidBanner.ShowPolicy = .replace,
                errorCode: Int? = nil) async -> (banner: LucidBanner?, token: Int?) {
    guard let windowScene, let window = windowScene.windows.first else {
        return(nil, nil)
    }

#if !EXTENSION
    guard !bannerContainsError(errorCode: errorCode) else {
        return (nil, nil)
    }
#endif

    let banner = LucidBannerRegistry.shared.banner(for: windowScene)
    let horizontalLayout = horizontalLayoutBanner(bounds: window.bounds,
                                                  safeAreaInsets: window.safeAreaInsets,
                                                  idiom: window.traitCollection.userInterfaceIdiom)

    let payload = LucidBannerPayload(
        title: NSLocalizedString(title ?? "", comment: ""),
        subtitle: NSLocalizedString(subtitle ?? "", comment: ""),
        footnote: NSLocalizedString(footnote ?? "", comment: ""),
        systemImage: systemImage,
        imageAnimation: imageAnimation,
        backgroundColor: Color(uiColor: backgroundColor),
        textColor: Color(uiColor: textColor),
        imageColor: Color(uiColor: imageColor),
        vPosition: vPosition,
        verticalMargin: verticalMargin,
        horizontalLayout: horizontalLayout,
        autoDismissAfter: autoDismissAfter,
        swipeToDismiss: swipeToDismiss
    )

    let token = banner.show(
        payload: payload,
        policy: policy,
        onTap: { _, _ in
        }
    ) { state in
        BannerView(state: state)
    }

    return(banner, token)
}

// MARK: - SwiftUI

struct BannerView: View {
    @ObservedObject var state: LucidBannerState

    var body: some View {
        let showTitle = !(state.payload.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showSubtitle = !(state.payload.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showFootnote = !(state.payload.footnote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        containerView(state: state, coordinator: nil, allowMinimizeOnTap: false) {
            VStack(spacing: 15) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: state.payload.systemImage ?? "info.circle")
                        .applyBannerAnimation(state.payload.imageAnimation)
                        .font(.icon())
                        .foregroundStyle(state.payload.imageColor)

                    VStack(alignment: .leading, spacing: 7) {
                        if showTitle, let title = state.payload.title {
                            Text(title)
                                .cappedFont(.title3, maxDynamicType: .accessibility2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(state.payload.textColor)
                        }

                        if showSubtitle, let subtitle = state.payload.subtitle {
                            Text(subtitle)
                                .cappedFont(.subheadline, maxDynamicType: .accessibility1)
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(state.payload.textColor)
                        }
                        if showFootnote, let footnote = state.payload.footnote {
                            Text(footnote)
                                .cappedFont(.footnote, maxDynamicType: .xxxLarge)
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

#Preview("maintenance mode") {
    ZStack {
        Text(
            Array(0...500)
                .map(String.init)
                .joined(separator: "  ")
            )
            .font(.system(size: 16, design: .monospaced))
            .foregroundStyle(.primary)
            .padding()

        let state = LucidBannerState(
            payload: LucidBannerPayload(
                title: "_warning_",
                subtitle: "_maintenance_mode_",
                systemImage: "xmark.icloud.fill",
                imageAnimation: .none,
                backgroundColor: Color(UIColor.systemOrange.withAlphaComponent(0.12)),
                textColor: Color(uiColor: .label),
                imageColor: Color(uiColor: .systemOrange),
            )
        )

        BannerView(state: state)
        .padding()
    }
}

#Preview("creating db photo") {
    ZStack {
        Text(
            Array(0...500)
                .map(String.init)
                .joined(separator: "  ")
            )
            .font(.system(size: 16, design: .monospaced))
            .foregroundStyle(.primary)
            .padding()

        let state = LucidBannerState(
            payload: LucidBannerPayload(
                title: "_info_",
                subtitle: "_creating_db_photo_progress_",
                systemImage: "photo.on.rectangle.angled",
                imageAnimation: .none,
                backgroundColor: Color(UIColor.systemBlue.withAlphaComponent(0.12)),
                textColor: Color(uiColor: .label),
                imageColor: Color(uiColor: .systemBlue),
            )
        )

        BannerView(state: state)
        .padding()
    }
}

