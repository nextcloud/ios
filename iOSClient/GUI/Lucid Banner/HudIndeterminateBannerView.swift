// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

@MainActor
func showHudIndeterminateBanner(windowScene: UIWindowScene?,
                                title: String? = nil,
                                subtitle: String? = nil,
                                stage: LucidBanner.Stage? = nil,
                                onButtonTap: (() -> Void)? = nil) -> (banner: LucidBanner?, token: Int?) {
    guard let windowScene,
          let window = windowScene.windows.first(where: \.isKeyWindow) else {
        return (nil, nil)
    }
    let localizedTitle = title.map { NSLocalizedString($0, comment: "") }
    let localizedSubTitle = subtitle.map { NSLocalizedString($0, comment: "") }
    let banner = LucidBannerRegistry.shared.banner(for: windowScene)
    let horizontalLayout = horizontalLayoutBanner(bounds: window.bounds,
                                                  safeAreaInsets: window.safeAreaInsets,
                                                  idiom: window.traitCollection.userInterfaceIdiom)

    let payload = LucidBannerPayload(
        title: localizedTitle,
        subtitle: localizedSubTitle,
        stage: stage,
        vPosition: .center,
        horizontalLayout: horizontalLayout,
        blocksTouches: true,
    )

    let token = banner.show(
        payload: payload,
        policy: .enqueue
    ) { state in
        HudBannerViewIndeterminate(state: state, onButtonTap: onButtonTap)
    }

    return(banner, token)
}

@MainActor
func completeHudIndeterminateBannerSuccess(token: Int?, banner: LucidBanner?) {
    guard let banner else {
        return
    }

    let payload = LucidBannerPayload.Update(
        stage: .success,
        autoDismissAfter: 2
    )

    banner.update(payload: payload, for: token)
}

@MainActor
func completeHudIndeterminateBannerError(description: String, token: Int?, banner: LucidBanner?) {
    guard let banner else {
        return
    }

    let payload = LucidBannerPayload.Update(
        subtitle: NSLocalizedString(description, comment: ""),
        stage: .error,
        autoDismissAfter: NCGlobal.shared.dismissAfterSecond
    )

    banner.update(payload: payload, for: token)
}

struct HudBannerViewIndeterminate: View {
    @ObservedObject var state: LucidBannerState
    @State private var rotation: Double = 0

    let onButtonTap: (() -> Void)?

    private let textColor = Color(.label)
    private let circleSize: CGFloat = 90
    private let lineWidth: CGFloat = 8

    init(state: LucidBannerState,
         onButtonTap: (() -> Void)? = nil) {
        self.state = state
        self.onButtonTap = onButtonTap
    }

    var body: some View {

        let isSuccess = (state.payload.stage == .success)
        let isError = (state.payload.stage == .error)
        let isButton = (state.payload.stage == .button)

        let strokeColor: Color = {
            if isSuccess { return .green }
            if isError { return .red }
            return .primary
        }()

        hudContainerView {
            VStack(spacing: 18) {

                // TITLE
                if let title = state.payload.title, !title.isEmpty {
                    Text(title)
                        .cappedFont(.headline, maxDynamicType: .accessibility2)
                        .fontWeight(.semibold)
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.center)
                }

                // SUBTITLE
                if let subtitle = state.payload.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .cappedFont(.subheadline, maxDynamicType: .accessibility1)
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.center)
                }

                // SPINNER
                ZStack {
                    if isSuccess || isError {
                        // FULL RING (no trim)
                        Circle()
                            .stroke(
                                strokeColor,
                                style: StrokeStyle(lineWidth: lineWidth)
                            )
                            .frame(width: circleSize, height: circleSize)

                    } else {
                        // Background ring
                        Circle()
                            .stroke(
                                .gray.opacity(0.1),
                                style: StrokeStyle(lineWidth: lineWidth)
                            )
                            .frame(width: circleSize, height: circleSize)

                        // Spinning arc
                        Circle()
                            .trim(from: 0.0, to: 0.25)
                            .stroke(
                                strokeColor,
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                            )
                            .rotationEffect(.degrees(rotation))
                            .frame(width: circleSize, height: circleSize)
                    }

                    // Center content
                    Group {
                        if isSuccess {
                            Image(systemName: "checkmark")
                                .font(.icon(34, weight: .bold))
                                .foregroundStyle(strokeColor)
                        } else if isError {
                            Image(systemName: "xmark")
                                .font(.icon(34, weight: .bold))
                                .foregroundStyle(strokeColor)
                        }
                    }
                }
                .padding(.top, 4)

                if isButton {
                    VStack {
                        Button("_cancel_") {
                            onButtonTap?()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(.gray, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
        }
        .onAppear {
            startSpinning()
        }
        .onChange(of: state.payload.stage) { _, newStage in
            if newStage == .success || newStage == .error {
                stopSpinning()
            }
        }
    }

    // MARK: - Spinner animation

    private func startSpinning() {
        rotation = 0
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }

    private func stopSpinning() {
        withAnimation(.easeOut(duration: 0.2)) {
            rotation = rotation.truncatingRemainder(dividingBy: 360)
        }
    }

    // MARK: - Container (identico)

    @ViewBuilder
    func hudContainerView<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let cornerRadius: CGFloat = 22
        let backgroundColor = Color(.systemBackground).opacity(0.7)

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
