// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Wraps a SwiftUI view in a transparent `UIView` for use as a custom left or right view
/// in JDStatusBarNotification. Useful to display animated SwiftUI symbols.
@MainActor
func makeHostingNotificationPresenterView<Content: View>(_ content: Content, size: CGSize) -> UIView {
    let host = UIHostingController(rootView: content)
    host.view.backgroundColor = .clear
    host.view.isUserInteractionEnabled = false
    host.view.frame = .init(origin: .zero, size: size)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    return host.view
}

/// Animated gear symbol for JDStatusBarNotification.
struct NotificationPresenterGearSymbol: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                .symbolEffect(.rotate, options: .repeat(.continuous))
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        } else {
            Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        }
    }
}

/// Animated gear symbol for JDStatusBarNotification.
struct NotificationPresenterTryArrowSymbol: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            Image(systemName: "tray.and.arrow.down")
                .symbolEffect(.pulse.byLayer, options: .repeat(.continuous))
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        } else {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        }
    }
}

/// Animated gear symbol for JDStatusBarNotification.
struct NotificationPresenterArrowShapeSymbol: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            Image(systemName: "arrowshape.up.circle")
                .symbolEffect(.breathe, options: .repeat(.continuous))
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        } else {
            Image(systemName: "arrowshape.up.circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        }
    }
}

import SwiftUI
import UIKit

// MARK: - Passthrough window (doesn't block touches outside the banner)
final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Pass touches through (no blocking). If you want the banner tappable,
        // you can return super.hitTest(point, with: event) only when inside a subview.
        return nil
    }
}

// MARK: - SwiftUI banner with a progress bar
struct GlassBannerView: View {
    let title: String
    let subtitle: String?
    let progress: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                if #available(iOS 18.0, *) {
                    Image(systemName: "arrowshape.up.circle")
                        .symbolEffect(.breathe, options: .repeat(.continuous))
                } else {
                    Image(systemName: "arrowshape.up.circle")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline).bold()
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            ProgressView(value: max(0, min(progress, 1)))
                .progressViewStyle(.linear)
                .tint(.white)
                .scaleEffect(x: 1, y: 0.8, anchor: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 0.5)
        )
        .compositingGroup()
        .shadow(radius: 8)
    }
}

// MARK: - HUD Window Manager (attaches to foregroundActive scene)
@MainActor
final class GlassHUDWindow {
    static let shared = GlassHUDWindow()

    private var window: PassthroughWindow?
    private var hostController: UIHostingController<GlassBannerView>?

    // NEW: keep a reference to the top constraint to animate slide-in/out
    private var topConstraint: NSLayoutConstraint?

    private var title: String = ""
    private var subtitle: String?
    private var progress: Double = 0

    func show(title: String, subtitle: String? = nil, progress: Double = 0) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress

        if window == nil {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState != .background }) else { return }

            attachWindow(to: scene)
        } else {
            update(title: title, subtitle: subtitle, progress: progress)
            // Se già visibile non serve ri-animare
        }
    }

    private func attachWindow(to scene: UIWindowScene) {
        let win = PassthroughWindow(windowScene: scene)
        win.frame = scene.screen.bounds
        win.windowLevel = .statusBar + 1
        win.backgroundColor = .clear

        let host = UIHostingController(rootView: GlassBannerView(
            title: title, subtitle: subtitle, progress: progress
        ))
        host.view.backgroundColor = .clear
        win.rootViewController = host
        win.makeKeyAndVisible()

        host.view.translatesAutoresizingMaskIntoConstraints = false
        // Partenza fuori dallo schermo (sopra la safe area)
        let startOffset: CGFloat = -80
        let top = host.view.topAnchor.constraint(equalTo: win.safeAreaLayoutGuide.topAnchor,
                                                 constant: startOffset)
        NSLayoutConstraint.activate([
            top,
            host.view.centerXAnchor.constraint(equalTo: win.centerXAnchor),
            host.view.leadingAnchor.constraint(greaterThanOrEqualTo: win.leadingAnchor, constant: 12)
        ])

        self.window = win
        self.hostController = host
        self.topConstraint = top

        // Layout iniziale
        win.layoutIfNeeded()
        host.view.alpha = 0

        // Calcola una destinazione “pulita”
        let targetTop: CGFloat = 10

        // ANIMAZIONE: slide-in + fade-in
        top.constant = targetTop
        UIView.animate(withDuration: 1,
                       delay: 0,
                       usingSpringWithDamping: 0.9,
                       initialSpringVelocity: 0.6,
                       options: [.curveEaseOut, .beginFromCurrentState],
                       animations: {
            host.view.alpha = 1
            win.layoutIfNeeded()
        }, completion: nil)
    }

    func update(title: String? = nil, subtitle: String? = nil, progress: Double? = nil) {
        if let title { self.title = title }
        if let subtitle { self.subtitle = subtitle }
        if let progress { self.progress = progress }

        hostController?.rootView = GlassBannerView(
            title: self.title,
            subtitle: self.subtitle,
            progress: self.progress
        )
    }

    func dismiss() {
        guard let win = window, let host = hostController, let top = topConstraint else {
            hostController = nil; window?.isHidden = true; window = nil; return
        }

        // Porta di nuovo la pill fuori dallo schermo (in alto) e sfuma
        let outOffset = -(host.view.bounds.height + 40)
        top.constant = outOffset

        UIView.animate(withDuration: 0.25,
                       delay: 0,
                       options: [.curveEaseIn, .beginFromCurrentState],
                       animations: {
            host.view.alpha = 0
            win.layoutIfNeeded()
        }, completion: { _ in
            self.hostController = nil
            self.window?.isHidden = true
            self.window = nil
            self.topConstraint = nil
        })
    }
}
