// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

// MARK: - Stato osservabile condiviso
@MainActor
final class NCNotificationPresenterState: ObservableObject {
    @Published var title: String
    @Published var subtitle: String?
    @Published var progress: Double?
    @Published var extra: [String: Any] = [:]

    init(title: String, subtitle: String? = nil, progress: Double? = nil) {
        self.title = title
        self.subtitle = (subtitle?.isEmpty == true) ? nil : subtitle
        self.progress = progress
    }
}

@MainActor
final class NCNotificationPresenter {
    static let shared = NCNotificationPresenter()

    enum ShowPolicy {
        case replace, enqueue, drop
    }

    private struct PendingShow {
        let title: String
        let subtitle: String?
        let progress: Double?
        let autoDismissAfter: TimeInterval
        let fixedWidth: CGFloat?
        let viewUI: (NCNotificationPresenterState) -> AnyView
    }

    // View (type-erased)
    private var contentView: ((NCNotificationPresenterState) -> AnyView)?

    // UI
    var window: NCNotificationPresenterPassthroughWindow?
    private var hostController: UIHostingController<AnyView>?

    // Timers/flags
    private var dismissTimer: Task<Void, Never>?
    private var isAnimatingIn = false
    private var isDismissing = false
    private var pendingRelayout = false
    private var lockWidthUntilSettled = true

    // Size
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private let minWidth: CGFloat = 220
    private let maxWidthCapDefault: CGFloat = 420   // iPad ?
    private let minHeight: CGFloat = 44
    private var fixedWidth: CGFloat?

    // Queue & policy
    private var queue: [PendingShow] = []

    let state = NCNotificationPresenterState(title: "", subtitle: nil, progress: nil)

    // Config
    var isSwipeToDismissEnabled = true
    private var autoDismissAfter: TimeInterval = 0

    private var generation: Int = 0        // cresce a ogni show/dismiss
    private var activeToken: Int = 0       // token corrente valido

    func isAlive(_ token: Int) -> Bool {
        return token == activeToken && window != nil
    }

    @discardableResult
    func show<Content: View>(
        initialTitle: String,
        initialSubtitle: String? = nil,
        initialProgress: Double? = nil,
        autoDismissAfter: TimeInterval = 0,
        policy: ShowPolicy = .replace,
        fixedWidth: CGFloat? = nil,
        @ViewBuilder content: @escaping (NCNotificationPresenterState) -> Content
    ) -> Int {
        // Normalizza: ""/nil/0 => non mostrare quella sezione
        let t = initialTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        state.title = t.isEmpty ? "" : t

        if let s = initialSubtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            state.subtitle = s
        } else {
            state.subtitle = nil
        }

        if let p = initialProgress, p > 0 { state.progress = p } else { state.progress = nil }

        self.autoDismissAfter = autoDismissAfter
        self.fixedWidth = fixedWidth

        // Se non c’è nulla da mostrare (icona-only non gestita qui), esci
        let hasTitle = !state.title.isEmpty
        let hasSubtitle = !(state.subtitle?.isEmpty ?? true)
        let hasProgress = (state.progress ?? 0) > 0
        if !(hasTitle || hasSubtitle || hasProgress) {
            return activeToken // non cambia token
        }

        // Builder type-erased
        let currentState = self.state
        let anyViewUI: (NCNotificationPresenterState) -> AnyView = { _ in AnyView(content(currentState)) }

        // Concorrenza
        if window != nil || isAnimatingIn || isDismissing {
            switch policy {
            case .drop:
                return activeToken // ignora e lascia il token attuale
            case .enqueue:
                queue.append(PendingShow(title: state.title,
                                         subtitle: state.subtitle,
                                         progress: state.progress,
                                         autoDismissAfter: autoDismissAfter,
                                         fixedWidth: fixedWidth,
                                         viewUI: anyViewUI))
                return activeToken
            case .replace:
                let next = PendingShow(title: state.title,
                                       subtitle: state.subtitle,
                                       progress: state.progress,
                                       autoDismissAfter: autoDismissAfter,
                                       fixedWidth: fixedWidth,
                                       viewUI: anyViewUI)
                queue.removeAll()
                queue.append(next)
                // invalidiamo subito il token corrente: il prossimo show creerà un token nuovo
                generation &+= 1
                activeToken = generation
                dismiss { [weak self] in self?.dequeueAndStartIfNeeded() }
                return activeToken
            }
        }

        // Nuova sessione: bump del token
        generation &+= 1
        activeToken = generation

        // Nessun conflitto: parti subito
        startShow(with: anyViewUI)

        return activeToken
    }

    private func startShow(with viewUI: @escaping (NCNotificationPresenterState) -> AnyView) {
        // Lock durante l’entrata
        lockWidthUntilSettled = true
        isAnimatingIn = true
        pendingRelayout = false

        self.contentView = viewUI

        if window == nil {
            attachWindowAndPresent()
        } else {
            replaceContentInternal(remeasureWidth: false)
            remeasureAndSetWidthConstraint(animated: false, force: true)
        }

        scheduleAutoDismiss()
    }

    // MARK: - UPDATE (accetta opzionalmente un token)

    /// `token`: se passato e diverso da quello attivo, l’update viene ignorato.
    func update(title: String? = nil, subtitle: String? = nil, progress: Double? = nil, for token: Int? = nil) {
        // token non valido o window assente → ignora
        if let token, token != activeToken {
            return
        }
        guard window != nil else {
            return
        }

        let oldTitle = state.title
        let oldSub = state.subtitle

        if let title {
            let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            state.title = title.isEmpty ? "" : title
        }
        if let subtitle {
            let subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            state.subtitle = subtitle.isEmpty ? nil : subtitle
        }
        if let progress {
            state.progress = (progress > 0) ? progress : nil
        }

        hostController?.view.invalidateIntrinsicContentSize()

        let textChanged = (oldTitle != state.title) || (oldSub != state.subtitle)
        if textChanged {
            remeasureAndSetWidthConstraint(animated: true, force: false)
        }
    }

    func setSize(width: CGFloat?, height: CGFloat?, animated: Bool = true) {
        self.fixedWidth = width

        guard let window,
              let view = hostController?.view else {
            return
        }

        if let width {
            if let constraint = widthConstraint {
                constraint.constant = width
            } else {
                let constraint = view.widthAnchor.constraint(equalToConstant: width)
                constraint.isActive = true
                widthConstraint = constraint
            }
        } else {
            remeasureAndSetWidthConstraint(animated: animated, force: true)
        }

        if let height {
            if let constraint = heightConstraint {
                constraint.constant = height
            } else {
                let constraint = view.heightAnchor.constraint(equalToConstant: height)
                constraint.isActive = true
                heightConstraint = constraint
            }
        } else {
            heightConstraint?.isActive = false
            heightConstraint = nil
        }

        if animated { UIView.animate(withDuration: 0.2) {window.layoutIfNeeded() }
        } else {
            window.layoutIfNeeded()
        }
    }

    // MARK: - REPLACE CONTENT (swap mantenendo lo stato)

    func replaceContent<Content: View>(
        @ViewBuilder _ viewUI: @escaping (NCNotificationPresenterState) -> Content) {

        self.contentView = { (_: NCNotificationPresenterState) -> AnyView in AnyView(viewUI(self.state)) }

        replaceContentInternal(remeasureWidth: false)
        remeasureAndSetWidthConstraint(animated: false, force: true)
    }

    // MARK: - DISMISS (verticale puro) + completion
    func dismiss(completion: (() -> Void)? = nil) {
        dismissTimer?.cancel(); dismissTimer = nil

        generation &+= 1
        activeToken = generation

        guard let window, let hostView = hostController?.view else {
            hostController = nil; self.window?.isHidden = true; self.window = nil
            widthConstraint = nil; heightConstraint = nil
            completion?(); return
        }

        isDismissing = true
        hostView.isUserInteractionEnabled = false
        let offsetY = -hostView.bounds.height - 60

        UIView.animate(withDuration: 0.35,
                       delay: 0,
                       options: [.curveEaseIn, .beginFromCurrentState]) { [weak self] in
            hostView.alpha = 0
            hostView.transform = CGAffineTransform(translationX: 0, y: offsetY)
            hostView.layer.shadowOpacity = 0
            self?.window?.layoutIfNeeded()
        } completion: { [weak self] _ in
            guard let self else { return }
            self.hostController = nil
            window.isHidden = true
            self.window = nil
            self.widthConstraint = nil
            self.heightConstraint = nil
            self.isDismissing = false
            completion?()
            self.dequeueAndStartIfNeeded()
        }
    }

    // MARK: - Interni

    private func dequeueAndStartIfNeeded() {
        guard window == nil,
              !isAnimatingIn,
              !isDismissing,
        !queue.isEmpty else {
            return
        }
        let next = queue.removeFirst()

        state.title = next.title
        state.subtitle = next.subtitle
        state.progress = next.progress
        autoDismissAfter = next.autoDismissAfter
        fixedWidth = next.fixedWidth

        generation &+= 1
        activeToken = generation

        startShow(with: next.viewUI)
    }

    private func attachWindowAndPresent() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState != .background }) else { return }

        let windows = NCNotificationPresenterPassthroughWindow(windowScene: scene)
        windows.frame = scene.screen.bounds
        windows.windowLevel = .statusBar + 1
        windows.backgroundColor = .clear

        // Hosting SwiftUI
        let content = contentView?(state) ?? AnyView(EmptyView())
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        windows.rootViewController = host
        windows.makeKeyAndVisible()

        let view = host.view!
        view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: windows.safeAreaLayoutGuide.topAnchor, constant: 10),
            view.centerXAnchor.constraint(equalTo: windows.centerXAnchor),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight)
        ])

        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Swipe-to-dismiss
        windows.hitTargetView = view
        if isSwipeToDismissEnabled {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.cancelsTouchesInView = false
            view.addGestureRecognizer(pan)
        }

        self.window = windows
        self.hostController = host

        // Se width fissa: applica; altrimenti misura iniziale
        if let width = fixedWidth {
            let constraint = view.widthAnchor.constraint(equalToConstant: width)
            constraint.isActive = true
            widthConstraint = constraint
        } else {
            remeasureAndSetWidthConstraint(animated: false, force: true)
        }

        windows.layoutIfNeeded()
        view.alpha = 0
        view.transform = CGAffineTransform(translationX: 0, y: -view.bounds.height - 60)

        UIView.animate(withDuration: 0.45,
                       delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.5,
                       options: [.curveEaseOut, .beginFromCurrentState]) {
            view.alpha = 1
            view.transform = .identity
        } completion: { [weak self] _ in
            guard let self else { return }
            self.isAnimatingIn = false
            self.lockWidthUntilSettled = false
            if self.pendingRelayout {
                self.remeasureAndSetWidthConstraint(animated: true, force: true)
                self.pendingRelayout = false
            }
        }
    }

    private func replaceContentInternal(remeasureWidth: Bool) {
        guard let host = hostController else {
            return
        }
        let newView = contentView?(state) ?? AnyView(EmptyView())

        host.rootView = newView
        if remeasureWidth {
            remeasureAndSetWidthConstraint(animated: false, force: false)
        }
        window?.layoutIfNeeded()
    }

    private func remeasureAndSetWidthConstraint(animated: Bool, force: Bool) {
        guard let window,
              let host = hostController else {
            return
        }

        // Durante l’entrata, non toccare i vincoli (evita allargamenti mentre scende)
        if isAnimatingIn && lockWidthUntilSettled && !force {
            pendingRelayout = true
            return
        }

        // Se la larghezza è fissa, non misurare
        if fixedWidth != nil { return }

        state.extra["measuring"] = true
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let cap = min(window.bounds.width - 24, maxWidthCapDefault)
        let fitting = host.sizeThatFits(
            in: CGSize(width: cap, height: UIView.layoutFittingCompressedSize.height)
        )
        let target = min(max(fitting.width, minWidth), cap)

        state.extra["measuring"] = false

        if let wc = widthConstraint {
            // Auto-mode: consenti SOLO crescita (niente shrink live)
            let newWidth = max(target, wc.constant)
            guard abs(wc.constant - newWidth) > 0.5 else { return }
            wc.constant = newWidth
        } else {
            let wc = host.view.widthAnchor.constraint(equalToConstant: target)
            wc.isActive = true
            widthConstraint = wc
        }

        if animated {
            UIView.animate(withDuration: 0.20) {
                window.layoutIfNeeded()
            }
        } else {
            window.layoutIfNeeded()
        }
    }

    private func scheduleAutoDismiss() {
        dismissTimer?.cancel()
        let seconds = self.autoDismissAfter

        guard seconds > 0 else {
            return
        }

        dismissTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            self?.dismiss()
        }
    }

    // Swipe-up (transform-based)
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = hostController?.view else {
            return
        }
        let translationY = gesture.translation(in: view).y

        switch gesture.state {
        case .changed:
            let y = min(0, translationY) // solo verso l'alto
            view.transform = CGAffineTransform(translationX: 0, y: y)
            view.alpha = max(0.4, 1.0 + y / 120.0)
        case .ended, .cancelled:
            let velocityY = gesture.velocity(in: view).y
            let shouldDismiss = (translationY < -30) || (velocityY < -500)
            if shouldDismiss {
                dismiss()
            } else {
                UIView.animate(withDuration: 0.25,
                               delay: 0,
                               usingSpringWithDamping: 0.85,
                               initialSpringVelocity: 0.5,
                               options: [.curveEaseOut, .beginFromCurrentState]) {
                    view.alpha = 1
                    view.transform = .identity
                }
            }
        default:
            break
        }
    }
}

// MARK: - UIWindow pass-through

final class NCNotificationPresenterPassthroughWindow: UIWindow {
    weak var hitTargetView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let target = hitTargetView else { return nil }
        let p = target.convert(point, from: self)
        return target.bounds.contains(p) ? super.hitTest(point, with: event) : nil
    }
}

struct BannerView: View {
    @ObservedObject var state: NCNotificationPresenterState

    var body: some View {
        let showTitle = !state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let showSubtitle = !(state.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showProgress = (state.progress ?? 0) > 0
        let measuring = (state.extra["measuring"] as? Bool) ?? false

        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                if #available(iOS 18, *) {
                    Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                        .symbolEffect(.rotate, options: .repeat(.continuous))
                        .foregroundStyle(Color(uiColor: NCBrandColor.shared.customer))
                } else {
                    Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                }

                if showTitle || showSubtitle {
                    VStack(alignment: .leading, spacing: 4) {
                        if showTitle {
                            Text(state.title)
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.9)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(Color(uiColor: NCBrandColor.shared.customer))
                        }
                        if showSubtitle, let s = state.subtitle {
                            Text(s)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(Color(uiColor: NCBrandColor.shared.customer))
                        }
                    }
                }
            }

            if showProgress && !measuring {
                ProgressView(value: min(state.progress ?? 0, 1))
                    .progressViewStyle(.linear)
                    .tint(Color(uiColor: NCBrandColor.shared.customer))
                    .scaleEffect(x: 1, y: 0.8, anchor: .center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .blendMode(.plusLighter)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .blendMode(.screen)
            }
            .compositingGroup() // Isola i blend dentro al rettangolo
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .frame(minHeight: 44, alignment: .leading)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        LinearGradient(
            colors: [.white, .gray],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        BannerView(
            state: NCNotificationPresenterState(
                title: "Uploading large file…",
                subtitle: "Please keep the app active until the process completes.",
                progress: 0.45
            )
        )
        .padding()
    }
}
