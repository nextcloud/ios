// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

@MainActor
func showMessageBanner(scene: UIWindowScene?,
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

    LucidBanner.shared.show(
        scene: scene,
        title: title,
        subtitle: subtitle,
        footnote: footnote,
        textColor: Color(uiColor: textColor),
        systemImage: image,
        imageAnimation: imageAnimation,
        imageColor: Color(uiColor: imageColor),
        backgroundColor: Color(uiColor: backgroundColor),
        vPosition: vPosition,
        autoDismissAfter: NCGlobal.shared.dismissAfterSecond,
        swipeToDismiss: true,
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
        let showTitle = !(state.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showSubtitle = !(state.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showFootnote = !(state.footnote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        containerView(state: state) {
            VStack(spacing: 15) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: state.systemImage ?? "info.circle")
                        .applyBannerAnimation(state.imageAnimation)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(state.imageColor)

                    VStack(alignment: .leading, spacing: 7) {
                        if showTitle, let title = state.title {
                            Text(title)
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(state.textColor)
                        }

                        if showSubtitle, let subtitle = state.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(state.textColor)
                        }
                        if showFootnote, let footnote = state.footnote {
                            Text(footnote)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(state.textColor)
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
    func containerView<Content: View>(state: LucidBannerState, @ViewBuilder _ content: () -> Content) -> some View {
        let cornerRadius: CGFloat = 22
        let contentBase = content()
            .contentShape(Rectangle())
            .frame(maxWidth: 500)

        if #available(iOS 26, *) {
            contentBase
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(state.backgroundColor)
                )
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 22))
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            contentBase
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
                .frame(maxWidth: .infinity, alignment: .center)
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

        MessageBannerView(
            state: LucidBannerState(
                title: "Title",
                subtitle: "Subtitle",
                footnote: "footnote",
                systemImage: "wifi.circle",
                imageAnimation: .variableColor,
            )
        )
        .padding()
    }
}
