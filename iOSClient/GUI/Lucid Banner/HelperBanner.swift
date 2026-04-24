// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner
import Alamofire

public extension View {
    @ViewBuilder
    func containerView<Content: View>(state: LucidBannerState,
                                      coordinator: LucidBannerVariantCoordinator?,
                                      allowMinimizeOnTap: Bool,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        let isError = state.payload.stage == .error
        let isMinimized = state.variant == .alternate

        let cornerRadius: CGFloat = isMinimized ? 15 : 25
        let backgroundColor = isError ? .red : state.payload.backgroundColor.opacity(0.9)

        let base = content()
            .contentShape(Rectangle())
            .onTapGesture {
                guard allowMinimizeOnTap else { return }
                coordinator?.handleTap(state)
            }
            .frame(maxWidth: .infinity, alignment: .center)

        if #available(iOS 26, *) {
            base
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                        .id(backgroundColor)
                )
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
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

func horizontalLayoutBanner(bounds: CGRect,
                            safeAreaInsets: UIEdgeInsets,
                            idiom: UIUserInterfaceIdiom,
                            phoneSideMargin: CGFloat = 20,
                            maxPadWidth: CGFloat = 500) -> LucidBanner.HorizontalLayout {
    let availableWidth = bounds.width - safeAreaInsets.left - safeAreaInsets.right

    switch idiom {

    case .pad:
        let width = min(maxPadWidth, availableWidth)
        return .centered(width: width)

    default:
        return .stretch(margins: phoneSideMargin)
    }
}

/// Prevents the same error banner from being shown repeatedly in a short time.
/// Uses a per-error (and optional account) cooldown to avoid UI spam.
/// Call `shouldShow(...)` before presenting a banner.
actor ErrorBannerGate {
    static let shared = ErrorBannerGate()

    private var lastShownByKey: [String: Date] = [:]
    private let maxEntryAge: TimeInterval = 120

    private init() {}

    func shouldShow(errorCode: Int, account: String? = nil) -> Bool {
        cleanupOldEntries()

        let key = makeKey(errorCode: errorCode, account: account)
        let now = Date()
        let cooldown = cooldownInterval(for: errorCode)

        if let lastShown = lastShownByKey[key],
           now.timeIntervalSince(lastShown) < cooldown {
            return false
        }

        lastShownByKey[key] = now
        return true
    }

    // MARK: - Private

    private func makeKey(errorCode: Int, account: String?) -> String {
        "\(errorCode)|\(account ?? "-")"
    }

    private func cooldownInterval(for errorCode: Int) -> TimeInterval {
        switch errorCode {

        case NSURLErrorNotConnectedToInternet:
            return 30 // No internet connection (persistent until network changes)

        case NSURLErrorCannotFindHost:
            return 30 // Host/DNS not reachable (likely server down or misconfigured URL)

        case 401:
            return 30 // Unauthorized (server maintenance)

        case 423:
            return 20 // Resource locked (temporary server-side condition)

        case 507:
            return 30 // Insufficient storage (server quota exceeded, persistent)

        default:
            return 5  // Transient or unknown error
        }
    }

    private func cleanupOldEntries() {
        let now = Date()

        lastShownByKey = lastShownByKey.filter { _, lastShown in
            now.timeIntervalSince(lastShown) < maxEntryAge
        }
    }
}
