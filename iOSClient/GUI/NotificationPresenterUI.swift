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

// MARK: - Stato condiviso (osservabile da qualunque contenuto SwiftUI)
@MainActor
final class HUDState: ObservableObject {
    @Published var title: String
    @Published var subtitle: String?
    @Published var progress: Double?   // nil o <= 0 = nascosta
    @Published var extra: [String: Any] = [:] // opzionale per dati custom

    init(title: String, subtitle: String? = nil, progress: Double? = nil) {
        self.title = title
        self.subtitle = (subtitle?.isEmpty == true) ? nil : subtitle
        self.progress = progress
    }
}

// MARK: - Finestra passthrough
final class PassthroughWindow: UIWindow {
    weak var hitTargetView: UIView?
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let target = hitTargetView else { return nil }
        let p = target.convert(point, from: self)
        return target.bounds.contains(p) ? super.hitTest(point, with: event) : nil
    }
}

// MARK: - Manager generico (accetta qualunque contenuto SwiftUI)
@MainActor
final class GlassHUDWindow {
    static let shared = GlassHUDWindow()

    // Builder del contenuto: riceve lo stato e ritorna una View
    private var contentBuilder: ((HUDState) -> AnyView)?

    private var window: PassthroughWindow?
    private var hostController: UIHostingController<AnyView>?
    private var topConstraint: NSLayoutConstraint?
    private var dismissTimer: Task<Void, Never>?

    let state = HUDState(title: "", subtitle: nil, progress: nil)

    var isSwipeToDismissEnabled = true
    private var autoDismissAfter: TimeInterval = 0

    func show<Content: View>(
        initialTitle: String,
        initialSubtitle: String? = nil,
        initialProgress: Double? = nil,
        autoDismissAfter: TimeInterval = 0,
        @ViewBuilder content: @escaping (HUDState) -> Content
    ) {
        // Aggiorna lo stato iniziale
        state.title = initialTitle
        state.subtitle = (initialSubtitle?.isEmpty == true) ? nil : initialSubtitle
        state.progress = initialProgress
        self.autoDismissAfter = autoDismissAfter

        // Cattura locale del riferimento per evitare problemi con self
        let currentState = self.state

        // 🔧 Qui il type system vuole un’annotazione esplicita
        self.contentBuilder = { (_ state: HUDState) -> AnyView in
            AnyView(content(currentState))
        }

        if window == nil {
            attachWindowAndPresent()
        } else {
            replaceContent() // stesso contenitore, nuovo contenuto
        }

        scheduleAutoDismiss()
    }

    // UPDATE: cambia solo lo stato (la view si aggiorna da sola)
    func update(title: String? = nil, subtitle: String? = nil, progress: Double? = nil) {
        if let t = title { state.title = t }
        if let s = subtitle { state.subtitle = (s.isEmpty ? nil : s) }
        if let p = progress { state.progress = (p > 0) ? p : nil }
        // Nessun recreate: SwiftUI rinfresca osservando HUDState
    }

    // REPLACE CONTENT: swap della view mantenendo lo stato
    @MainActor
    func replaceContent<Content: View>(
        @ViewBuilder _ builder: @escaping (HUDState) -> Content
    ) {
        let currentState = self.state
        self.contentBuilder = { (_: HUDState) -> AnyView in
            AnyView(builder(currentState))
        }
        replaceContent() // chiama l'interno che fa host.rootView = contentBuilder(state)
    }

    func dismiss() {
        dismissTimer?.cancel(); dismissTimer = nil
        guard let win = window,
              let host = hostController,
              let top = topConstraint else {
            hostController = nil; window?.isHidden = true; window = nil; topConstraint = nil; return
        }
        top.constant = -(host.view.bounds.height + 40)
        UIView.animate(withDuration: 0.25, delay: 0,
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

    // MARK: - Internals

    private func attachWindowAndPresent() {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState != .background }) else { return }

        let win = PassthroughWindow(windowScene: scene)
        win.frame = scene.screen.bounds
        win.windowLevel = .statusBar + 1
        win.backgroundColor = .clear

        let view = contentBuilder?(state) ?? AnyView(EmptyView())
        let host = UIHostingController(rootView: view)
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

        // Slide-in
        win.layoutIfNeeded()
        host.view.alpha = 0
        let targetTop: CGFloat = 10
        top.constant = targetTop
        UIView.animate(withDuration: 0.32, delay: 0,
                       usingSpringWithDamping: 0.9,
                       initialSpringVelocity: 0.6,
                       options: [.curveEaseOut, .beginFromCurrentState]) {
            host.view.alpha = 1
            win.layoutIfNeeded()
        }
    }

    private func replaceContent() {
        guard let host = hostController else { return }
        let newView = contentBuilder?(state) ?? AnyView(EmptyView())
        host.rootView = newView
    }

    private func scheduleAutoDismiss() {
        dismissTimer?.cancel()
        guard autoDismissAfter > 0 else {
            return
        }
        dismissTimer = Task { [self] in
            try? await Task.sleep(nanoseconds: UInt64(self.autoDismissAfter * 1_000_000_000))
            self.dismiss()
        }
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard let win = window, let host = hostController?.view, let top = topConstraint else { return }
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
        default: break
        }
    }
}
// Una versione rapida del contenuto vetroso
struct GlassBannerView: View {
    @ObservedObject var state: HUDState
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                if #available(iOS 18, *) {
                    Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                        .symbolEffect(.rotate, options: .repeat(.continuous))
                } else {
                    Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title).font(.subheadline.weight(.bold)).lineLimit(2)
                    if let s = state.subtitle { Text(s).font(.caption).lineLimit(2) }
                }
                Spacer(minLength: 0)
            }
            if let p = state.progress, p > 0 {
                ProgressView(value: min(p, 1))
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .scaleEffect(x: 1, y: 0.8)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .foregroundStyle(.white)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.25), lineWidth: 0.5))
    }
}
