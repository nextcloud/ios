// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

public extension View {
    @ViewBuilder
    func containerView<Content: View>(state: LucidBannerState,
                                      allowMinimizeOnTap: Bool,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        let isError = state.payload.stage == .error
        let isSuccess = state.payload.stage == .success
        let isMinimized = state.variant == .alternate

        let cornerRadius: CGFloat = isMinimized ? 15 : 25
        let maxWidth: CGFloat? = (isMinimized || isSuccess) ? nil : 500
        let backgroundColor = isError ? .red : state.payload.backgroundColor.opacity(0.9)

        let base = content()
            .contentShape(Rectangle())
            .onTapGesture {
                guard allowMinimizeOnTap else { return }
                LucidBannerVariantCoordinator.shared.handleTap(state)
            }
            .frame(maxWidth: maxWidth)

        if #available(iOS 26, *) {
            base
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                        .id(backgroundColor)
                )
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
                .frame(maxWidth: .infinity, alignment: .center)

        } else {
            base
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
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    func applyBannerAnimation(_ style: LucidBanner.LucidBannerAnimationStyle) -> some View {
        switch style {

        // ---- iOS 18+ effects ----
        case .rotate, .pulse, .pulsebyLayer, .breathe, .bounce, .wiggle, .scale, .scaleUpbyLayer, .variableColor:
            if #available(iOS 18, *) {
                switch style {
                case .rotate:
                    self.symbolEffect(.rotate, options: .repeat(.continuous))
                case .pulse:
                    self.symbolEffect(.pulse, options: .repeat(.continuous))
                case .pulsebyLayer:
                    self.symbolEffect(.pulse.byLayer, options: .repeat(.continuous))
                case .breathe:
                    self.symbolEffect(.breathe, options: .repeat(.continuous))
                case .bounce:
                    self.symbolEffect(.bounce, options: .repeat(.continuous))
                case .wiggle:
                    self.symbolEffect(.wiggle, options: .repeat(.continuous))
                case .scale:
                    self.symbolEffect(.scale, options: .repeat(.continuous))
                case .scaleUpbyLayer:
                    self.symbolEffect(.scale.up.byLayer, options: .repeat(.continuous))
                case .variableColor:
                    self.symbolEffect(.variableColor, options: .repeat(.continuous))
                default:
                    self
                }
            } else {
                self
            }

        // ---- iOS 26+ effect: drawOn ----
        case .drawOn:
            if #available(iOS 26, *) {
                self.symbolEffect(.drawOn)
            } else {
                self
            }

        // ---- no animation ----
        case .none:
            self
        }
    }
}
