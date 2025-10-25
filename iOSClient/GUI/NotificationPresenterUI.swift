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

@MainActor
final class GlassHUDWindow {
    static let shared = GlassHUDWindow()

    var isSwipeToDismissEnabled = true // <— FLAG

    private var window: PassthroughWindow?
    private var hostController: UIHostingController<GlassBannerView>?
    private var topConstraint: NSLayoutConstraint?

    private var title: String = ""
    private var subtitle: String?
    private var progress: Double = 0

    func show(title: String, subtitle: String? = nil, progress: Double = 0) {
        self.title = title; self.subtitle = subtitle; self.progress = progress

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
        let startOffset: CGFloat = -80
        let top = host.view.topAnchor.constraint(equalTo: win.safeAreaLayoutGuide.topAnchor,
                                                 constant: startOffset)
        NSLayoutConstraint.activate([
            top,
            host.view.centerXAnchor.constraint(equalTo: win.centerXAnchor),
            host.view.leadingAnchor.constraint(greaterThanOrEqualTo: win.leadingAnchor, constant: 12)
        ])

        // Allow touches only inside the banner view
        win.hitTargetView = host.view

        // Enable swipe-to-dismiss if requested
        if isSwipeToDismissEnabled {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.cancelsTouchesInView = false // keep interactions inside SwiftUI view
            host.view.addGestureRecognizer(pan)
        }

        self.window = win
        self.hostController = host
        self.topConstraint = top

        // Initial layout + slide-in
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

    // Pan handler: drag up to dismiss, drag down small -> snap back
    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard let win = window,
              let host = hostController?.view,
              let top = topConstraint else { return }

        let translation = g.translation(in: host).y
        let baseTop: CGFloat = 10 // resting position
        switch g.state {
        case .changed:
            // Only allow moving upward (negative y); tiny forgiveness downward
            let limited = min(0, translation) // <= 0
            top.constant = baseTop + limited
            // Optional: fade a bit while dragging
            host.alpha = max(0.4, 1.0 + limited / 120.0)
            win.layoutIfNeeded()

        case .ended, .cancelled:
            let velocityY = g.velocity(in: host).y
            let shouldDismiss = (translation < -30) || (velocityY < -500)
            if shouldDismiss {
                // Slide out upwards and dismiss
                top.constant = -(host.bounds.height + 40)
                UIView.animate(withDuration: 0.22,
                               delay: 0,
                               options: [.curveEaseIn, .beginFromCurrentState]) {
                    host.alpha = 0
                    win.layoutIfNeeded()
                } completion: { _ in
                    self.dismiss()
                }
            } else {
                // Snap back to baseTop
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

    func update(title: String? = nil, subtitle: String? = nil, progress: Double? = nil) {
        if let title { self.title = title }
        if let subtitle { self.subtitle = subtitle }
        if let progress { self.progress = max(0, min(progress, 1)) }

        hostController?.rootView = GlassBannerView(
            title: self.title,
            subtitle: self.subtitle,
            progress: self.progress
        )
    }

    func dismiss() {
        hostController = nil
        window?.isHidden = true
        window = nil
        topConstraint = nil
    }
}
