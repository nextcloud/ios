// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

@MainActor
func showUploadBanner(scene: UIWindowScene?,
                      payload: LucidBannerPayload,
                      allowMinimizeOnTap: Bool,
                      onButtonTap: (() -> Void)? = nil) -> Int? {

    let token = LucidBanner.shared.show(scene: scene,
                                        payload: payload,
                                        policy: .drop) { state in
        UploadBannerView(state: state,
                         allowMinimizeOnTap: allowMinimizeOnTap,
                         onButtonTap: onButtonTap)
    }

#if !EXTENSION
    if allowMinimizeOnTap {
        LucidBannerVariantCoordinator.shared.register(token: token) { context in
            let bounds = context.bounds
            let controller = SceneManager.shared.getController(scene: scene)
            var height: CGFloat = 0
            let over: CGFloat = 30
            if let scene,
               let controller,
               let window = scene.windows.first {
                let regularLayout = (window.rootViewController?.traitCollection.horizontalSizeClass == .regular)
                let iPad = UIDevice.current.userInterfaceIdiom == .pad
                if iPad, regularLayout {
                    height = over
                } else {
                    height = controller.barHeightBottom + context.safeAreaInsets.bottom + over
                }
            }

            return CGPoint(
                x: bounds.midX,
                y: bounds.maxY - height
            )
        }
    }
#endif
    return token
}

// MARK: - SwiftUI

struct UploadBannerView: View {
    @ObservedObject var state: LucidBannerState
    @State var trigger = true
    let onButtonTap: (() -> Void)?
    let allowMinimizeOnTap: Bool
    let textColor = Color(.label)

    init(state: LucidBannerState,
         allowMinimizeOnTap: Bool = false,
         onButtonTap: (() -> Void)? = nil) {
        self.state = state
        self.allowMinimizeOnTap = allowMinimizeOnTap
        self.onButtonTap = onButtonTap
    }

    var body: some View {
        let showTitle = !(state.payload.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showSubtitle = !(state.payload.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showFootnote = !(state.payload.footnote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        let isSuccess = (state.payload.stage == .success)
        let isError = (state.payload.stage == .error)
        let isButton = (state.payload.stage == .button)

        containerView(state: state, allowMinimizeOnTap: allowMinimizeOnTap) {
            if state.variant == .alternate {
                HStack(spacing: 5) {
                    Image(systemName: state.payload.systemImage ?? "arrow.up.circle")
                        .applyBannerAnimation(state.payload.imageAnimation)
                        .font(.body.weight(.medium))
                        .frame(width: 20, height: 20)
                        .foregroundStyle(state.payload.imageColor)

                    if let p = state.payload.progress {
                        Text("\(Int(p * 100))%")
                            .font(.caption2.monospacedDigit())
                            .frame(height: 20)
                            .foregroundStyle(state.payload.textColor)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .clipShape(Capsule())
            } else if isSuccess {
                 HStack(alignment: .center, spacing: 10) {
                     if #available(iOS 26, *) {
                         Image(systemName: "checkmark")
                             .font(.system(size: 60, weight: .regular))
                             .foregroundStyle(.green)
                             .symbolEffect(.drawOn, isActive: trigger)
                             .task {
                                 try? await Task.sleep(for: .seconds(0.1))
                                 trigger = false
                             }
                     } else {
                         Image(systemName: "checkmark")
                             .font(.system(size: 80, weight: .regular))
                             .foregroundStyle(.green)
                     }
                 }
                 .padding(.horizontal, 20)
                 .padding(.vertical, 20)
            } else if isError {
                VStack(spacing: 15) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 7) {
                            Text("_error_")
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.9)
                                .foregroundStyle(textColor)
                            if showSubtitle, let subtitle = state.payload.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
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
            } else {
                VStack(spacing: 15) {
                    HStack(alignment: .top, spacing: 10) {
                        if let systemImage = state.payload.systemImage {
                            Image(systemName: systemImage)
                                .applyBannerAnimation(state.payload.imageAnimation)
                                .font(.system(size: 30, weight: .regular))
                                .foregroundStyle(state.payload.imageColor)
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            if showTitle, let title = state.payload.title {
                                Text(title)
                                    .font(.subheadline.weight(.bold))
                                    .multilineTextAlignment(.leading)
                                    .truncationMode(.tail)
                                    .minimumScaleFactor(0.9)
                                    .foregroundStyle(textColor)
                            }
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
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ProgressView(value: state.payload.progress ?? 0)
                        .tint(.accentColor)
                        .opacity(state.payload.progress == nil ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: state.payload.progress == nil)
                        .padding(.horizontal, 5)

                    if isButton {
                        VStack {
                            Button("_cancel_") {
                                onButtonTap?()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(textColor)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .stroke(.gray, lineWidth: 1)
                            )
                        }
                        .padding(15)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let payload = LucidBannerPayload(title: "Uploading…",
                                     subtitle: "Minimized style preview",
                                     systemImage: "arrowshape.up.circle",
                                     imageAnimation: .none,
                                     progress: 0.4,
                                     stage: .button)
    let state = LucidBannerState(payload: payload)

    return ZStack {
        Text(
            Array(0...500)
                .map(String.init)
                .joined(separator: "  ")
            )
            .font(.system(size: 16, design: .monospaced))
            .foregroundStyle(.primary)
            .padding()

        UploadBannerView(
            state: state,
            allowMinimizeOnTap: false
        )
        .padding()
    }
}
