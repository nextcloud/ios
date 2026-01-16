// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

public extension View {
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
                self
            } else {
                self
            }

        // ---- no animation ----
        case .none:
            self
        }
    }
}
