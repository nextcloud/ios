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


// MARK: - Passthrough window that only captures touches inside a target view
final class PassthroughWindow: UIWindow {
    weak var hitTargetView: UIView? // the banner view

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let target = hitTargetView else { return nil }
        let p = target.convert(point, from: self)
        // Touches inside the banner -> handled; outside -> pass-through
        return target.bounds.contains(p) ? super.hitTest(point, with: event) : nil
    }
}

// MARK: - SwiftUI banner with a progress bar
import SwiftUI

/// Glass banner content.
/// Hides subtitle if empty; hides progress bar when progress ≤ 0 or nil.
struct GlassBannerView: View {
    let title: String
    let subtitle: String?
    let progress: Double?

    init(title: String, subtitle: String? = nil, progress: Double? = nil) {
        self.title = title
        self.subtitle = subtitle?.isEmpty == true ? nil : subtitle
        self.progress = progress
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // Example animated icon
                if #available(iOS 18.0, *) {
                    Image(systemName: "arrowshape.up.circle")
                        .symbolEffect(.breathe, options: .repeat(.continuous))
                } else {
                    Image(systemName: "arrowshape.up.circle")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(2)

                    if let s = subtitle {
                        Text(s)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }

            if let p = progress, p > 0 {
                ProgressView(value: min(p, 1)) // clamps naturally by min()
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .scaleEffect(x: 1, y: 0.8, anchor: .center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
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
        .shadow(radius: 8)
    }
}

import SwiftUI
import UIKit

@MainActor
final class GlassHUDWindow {
    static let shared = GlassHUDWindow()

    private var window: PassthroughWindow?
    private var hostController: UIHostingController<GlassBannerView>?
    private var topConstraint: NSLayoutConstraint?
    private var dismissTimer: Task<Void, Never>?

    private var title: String = ""
    private var subtitle: String?
    private var progress: Double?
    private var autoDismissAfter: TimeInterval = 0

    var isSwipeToDismissEnabled = true

    // MARK: - Show
    func show(title: String,
              subtitle: String? = nil,
              progress: Double? = nil,
              autoDismissAfter: TimeInterval = 0) {
        self.title = title
        self.subtitle = subtitle?.isEmpty == true ? nil : subtitle
        self.progress = progress
        self.autoDismissAfter = autoDismissAfter

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
        }

        // schedule auto-dismiss if requested
        scheduleAutoDismiss()
    }

    // MARK: - Attach UIWindow
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
        let startOffset: CGFloat = -80
        let top = host.view.topAnchor.constraint(equalTo: win.safeAreaLayoutGuide.topAnchor,
                                                 constant: startOffset)
        NSLayoutConstraint.activate([
            top,
            host.view.centerXAnchor.constraint(equalTo: win.centerXAnchor),
            host.view.leadingAnchor.constraint(greaterThanOrEqualTo: win.leadingAnchor, constant: 12)
        ])

        win.hitTargetView = host.view

        if isSwipeToDismissEnabled {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.cancelsTouchesInView = false
            host.view.addGestureRecognizer(pan)
        }

        self.window = win
        self.hostController = host
        self.topConstraint = top

        // Slide-in animation
        win.layoutIfNeeded()
        host.view.alpha = 0
        let targetTop: CGFloat = 10
        top.constant = targetTop
        UIView.animate(withDuration: 0.32,
                       delay: 0,
                       usingSpringWithDamping: 0.9,
                       initialSpringVelocity: 0.6,
                       options: [.curveEaseOut, .beginFromCurrentState]) {
            host.view.alpha = 1
            win.layoutIfNeeded()
        }
    }

    // MARK: - Update content
    func update(title: String? = nil, subtitle: String? = nil, progress: Double? = nil) {
        if let t = title { self.title = t }
        if let s = subtitle { self.subtitle = s.isEmpty ? nil : s }
        if let p = progress { self.progress = (p > 0) ? p : nil }

        hostController?.rootView = GlassBannerView(
            title: self.title,
            subtitle: self.subtitle,
            progress: self.progress
        )
    }

    // MARK: - Auto dismiss logic
    private func scheduleAutoDismiss() {
        dismissTimer?.cancel()
        guard autoDismissAfter > 0 else { return } // 0 → stays forever
        dismissTimer = Task {
            try? await Task.sleep(nanoseconds: UInt64(autoDismissAfter * 1_000_000_000))
            await dismiss()
        }
    }

    // MARK: - Pan gesture (swipe up)
    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard let win = window,
              let host = hostController?.view,
              let top = topConstraint else { return }

        let translation = g.translation(in: host).y
        let baseTop: CGFloat = 10

        switch g.state {
        case .changed:
            let limited = min(0, translation)
            top.constant = baseTop + limited
            host.alpha = max(0.4, 1.0 + limited / 120.0)
            win.layoutIfNeeded()

        case .ended, .cancelled:
            let velocityY = g.velocity(in: host).y
            let shouldDismiss = (translation < -30) || (velocityY < -500)
            if shouldDismiss {
                dismiss()
            } else {
                top.constant = baseTop
                UIView.animate(withDuration: 0.25,
                               delay: 0,
                               usingSpringWithDamping: 0.85,
                               initialSpringVelocity: 0.5,
                               options: [.curveEaseOut, .beginFromCurrentState]) {
                    host.alpha = 1
                    win.layoutIfNeeded()
                }
            }
        default:
            break
        }
    }

    // MARK: - Dismiss
    func dismiss() {
        dismissTimer?.cancel()
        dismissTimer = nil

        guard let win = window,
              let host = hostController,
              let top = topConstraint else {
            hostController = nil
            window?.isHidden = true
            window = nil
            return
        }

        top.constant = -(host.view.bounds.height + 40)
        UIView.animate(withDuration: 0.25,
                       delay: 0,
                       options: [.curveEaseIn, .beginFromCurrentState]) {
            host.view.alpha = 0
            win.layoutIfNeeded()
        } completion: { _ in
            self.hostController = nil
            self.window?.isHidden = true
            self.window = nil
            self.topConstraint = nil
        }
    }
}
