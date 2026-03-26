// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner
import NextcloudKit
import Alamofire

@MainActor
func showInfoBanner(windowScene: UIWindowScene?,
                    title: String = "_info_",
                    text: String,
                    footnote: String? = nil,
                    errorCode: Int? = nil) async {
    guard let windowScene, let window = windowScene.windows.first else {
        return
    }

#if !EXTENSION
    guard !bannerContainsError(errorCode: errorCode) else {
        return
    }
#endif

    let banner = LucidBannerRegistry.shared.banner(for: windowScene)
    let horizontalLayout = horizontalLayoutBanner(bounds: window.bounds,
                                                  safeAreaInsets: window.safeAreaInsets,
                                                  idiom: window.traitCollection.userInterfaceIdiom)

    let payload = LucidBannerPayload(
        title: NSLocalizedString(title, comment: ""),
        subtitle: NSLocalizedString(text, comment: ""),
        footnote: NSLocalizedString(footnote ?? "", comment: ""),
        systemImage: "checkmark.circle",
        backgroundColor: Color(.systemBackground).opacity(0.4),
        textColor: Color(uiColor: .label),
        imageColor: Color(uiColor: .systemBlue),
        vPosition: .top,
        verticalMargin: 10,
        horizontalLayout: horizontalLayout,
        autoDismissAfter: NCGlobal.shared.dismissAfterSecond,
        swipeToDismiss: true,
    )

    banner.show(
        payload: payload,
        policy: .replace,
        onTap: { _, _ in
            banner.dismiss()
        }
    ) { state in
        InfoBannerView(state: state)
    }
}

// MARK: - SwiftUI

struct InfoBannerView: View {
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
                title: "Info",
                subtitle: "Subtitle",
                footnote: "footnote",
                systemImage: "checkmark.circle",
                backgroundColor: Color(UIColor.systemBlue.withAlphaComponent(0.12)),
                textColor: Color(uiColor: .label),
                imageColor: Color(uiColor: .systemBlue)
            )
        )

        InfoBannerView(state: state)
        .padding()
    }
}
