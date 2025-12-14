// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

@MainActor
func showErrorBanner(controller: UITabBarController?, errorDescription: String, errorCode: Int, sleepBefore: Double = 1) async {
    let scene = SceneManager.shared.getWindow(controller: controller)?.windowScene
    await showErrorBanner(scene: scene, errorDescription: errorDescription, errorCode: errorCode, sleepBefore: sleepBefore)
}

@MainActor
func showErrorBanner(scene: UIWindowScene?, errorDescription: String, errorCode: Int, sleepBefore: Double = 1) async {
    try? await Task.sleep(nanoseconds: UInt64(sleepBefore * 1e9))
    var scene = scene
    if scene == nil {
        scene = UIApplication.shared.mainAppWindow?.windowScene
    }

    LucidBanner.shared.show(
        scene: scene,
        subtitle: errorDescription,
        footnote: "(Code: \(errorCode))",
        vPosition: .top,
        autoDismissAfter: NCGlobal.shared.dismissAfterSecond,
        swipeToDismiss: true,
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
        let showSubtitle = !(state.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showFootnote = !(state.footnote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        containerView {
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

                        if showSubtitle, let subtitle = state.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .foregroundStyle(textColor)
                        }
                        if showFootnote, let footnote = state.footnote {
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

    // MARK: - Container

    @ViewBuilder
    func containerView<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let cornerRadius: CGFloat = 22
        let errorColor = Color.red.opacity(0.75)
        let contentBase = content()
            .contentShape(Rectangle())
            .frame(maxWidth: 500)

        if #available(iOS 26, *) {
            contentBase
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(errorColor)
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

        ErrorBannerView(
            state: LucidBannerState(
                title: "Error",
                subtitle: "Not avalilable",
                footnote: "ErroCode. 12",
                imageAnimation: .breathe)
        )
        .padding()
    }
}
