// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

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
        ErrorBannerView(state: state)
    }
}

// MARK: - SwiftUI

struct ErrorBannerView: View {
    @ObservedObject var state: LucidBannerState
    let textColor = Color(.label)

    var body: some View {
        let showSubtitle = !(state.payload.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showFootnote = !(state.payload.footnote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        containerView(state: state, allowMinimizeOnTap: false) {
            VStack(spacing: 15) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("_error_")
                            .font(.subheadline.weight(.bold))
                            .multilineTextAlignment(.leading)
                            .truncationMode(.tail)
                            .foregroundStyle(textColor)

                        if showSubtitle, let subtitle = state.payload.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(textColor)
                        }
                        if showFootnote, let footnote = state.payload.footnote {
                            Text(footnote)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(textColor)
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
            title: "Error",
            subtitle: "Not avalilable",
            footnote: "ErroCode. 12",
            imageAnimation: .breathe,
            stage: .error
        ))

        ErrorBannerView(state: state)
        .padding()
    }
}
