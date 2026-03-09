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
                textColor: UIColor,
                image: String?,
                imageAnimation: LucidBanner.LucidBannerAnimationStyle,
                imageColor: UIColor,
                vPosition: LucidBanner.VerticalPosition = .top,
                backgroundColor: UIColor,
                autoDismissAfter: TimeInterval = NCGlobal.shared.dismissAfterSecond,
                swipeToDismiss: Bool = true,
                policy: LucidBanner.ShowPolicy = .replace) async -> (banner: LucidBanner?, token: Int?) {
    guard let windowScene else {
        return (nil, nil)
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
        autoDismissAfter: autoDismissAfter,
        swipeToDismiss: swipeToDismiss
    )

    let banner = LucidBannerRegistry.shared.banner(for: windowScene)

    let token = banner.show(payload: payload, policy: policy) { state in
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

        let state = LucidBannerState(
            payload: LucidBannerPayload(
                title: "Title",
                subtitle: "Subtitle",
                footnote: "footnote",
                systemImage: "wifi.circle"
            )
        )

        BannerView(state: state)
        .padding()
    }
}
