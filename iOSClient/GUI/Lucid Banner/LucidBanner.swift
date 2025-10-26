// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

@MainActor
final class LucidBanner {
    static let shared = LucidBanner()

    enum ShowPolicy {
        case replace, enqueue, drop
    }

    enum LucidBannerAnimationStyle {
        case none
        case rotate
        case pulse
        case bounce
        case wiggle
        case scale
    }

    private struct PendingShow {
        let title: String
        let subtitle: String?
        let textColor: UIColor
        let systemImage: String?
        let imageColor: UIColor
        let imageAnimation: LucidBannerAnimationStyle
        let progress: Double?
        let progressColor: UIColor
        let autoDismissAfter: TimeInterval
        let fixedWidth: CGFloat?
        let minWidth: CGFloat
        let maxWidth: CGFloat
        let topAnchor: CGFloat
        let viewUI: (LucidBannerState) -> AnyView
    }

    // View (type-erased)
    private var contentView: ((LucidBannerState) -> AnyView)?

    // UI
    var window: LucidBannerPassthroughWindow?
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
    private var minWidth: CGFloat = 220
    private var maxWidth: CGFloat = 420
    private let minHeight: CGFloat = 44
    private var fixedWidth: CGFloat?
    private var topAnchor: CGFloat = 10

    // Queue & policy
    private var queue: [PendingShow] = []

    let state = LucidBannerState(title: "",
                                 subtitle: nil,
                                 textColor: .label,
                                 systemImage: nil,
                                 imageColor: .label,
                                 imageAnimation: .none,
                                 progress: nil,
                                 progressColor: .label)

    // Config
    var isSwipeToDismissEnabled = true
    private var autoDismissAfter: TimeInterval = 0

    private var generation: Int = 0        // cresce a ogni show/dismiss
    private var activeToken: Int = 0       // token corrente valido

    func isAlive(_ token: Int) -> Bool {
        return token == activeToken && window != nil
    }

    @discardableResult
    func show<Content: View>(title: String,
                             subtitle: String? = nil,
                             textColor: UIColor = .label,
                             systemImage: String? = nil,
                             imageColor: UIColor = .label,
                             imageAnimation: LucidBannerAnimationStyle = .none,
                             progress: Double? = nil,
                             progressColor: UIColor = .label,
                             autoDismissAfter: TimeInterval = 0,
                             policy: ShowPolicy = .enqueue,
                             fixedWidth: CGFloat? = nil,
                             minWidth: CGFloat = 220,
                             maxWidth: CGFloat = 420,
                             topAnchor: CGFloat = 10,
                             @ViewBuilder content: @escaping (LucidBannerState) -> Content) -> Int {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        state.title = trimmed.isEmpty ? "" : trimmed
        state.textColor = textColor

        if let subtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !subtitle.isEmpty {
            state.subtitle = subtitle
        } else {
            state.subtitle = nil
        }

        state.systemImage = systemImage
        state.imageColor = imageColor
        state.imageAnimation = imageAnimation

        if let progress = progress, progress > 0 {
            state.progress = progress
        } else {
            state.progress = nil
        }
        state.progressColor = progressColor

        self.autoDismissAfter = autoDismissAfter
        self.fixedWidth = fixedWidth
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.topAnchor = topAnchor

        let hasTitle = !state.title.isEmpty
        let hasSubtitle = !(state.subtitle?.isEmpty ?? true)
        let hasProgress = (state.progress ?? 0) > 0
        if !(hasTitle || hasSubtitle || hasProgress) {
            return activeToken
        }

        // Builder type-erased
        let currentState = self.state
        let anyViewUI: (LucidBannerState) -> AnyView = { _ in AnyView(content(currentState)) }

        // Concurrent
        if window != nil || isAnimatingIn || isDismissing {
            switch policy {
            case .drop:
                return activeToken
            case .enqueue:
                queue.append(PendingShow(title: state.title,
                                         subtitle: state.subtitle,
                                         textColor: textColor,
                                         systemImage: systemImage,
                                         imageColor: imageColor,
                                         imageAnimation: imageAnimation,
                                         progress: state.progress,
                                         progressColor: progressColor,
                                         autoDismissAfter: autoDismissAfter,
                                         fixedWidth: fixedWidth,
                                         minWidth: minWidth,
                                         maxWidth: maxWidth,
                                         topAnchor: topAnchor,
                                         viewUI: anyViewUI))
                return activeToken
            case .replace:
                let next = PendingShow(title: state.title,
                                       subtitle: state.subtitle,
                                       textColor: textColor,
                                       systemImage: systemImage,
                                       imageColor: imageColor,
                                       imageAnimation: imageAnimation,
                                       progress: state.progress,
                                       progressColor: progressColor,
                                       autoDismissAfter: autoDismissAfter,
                                       fixedWidth: fixedWidth,
                                       minWidth: minWidth,
                                       maxWidth: maxWidth,
                                       topAnchor: topAnchor,
                                       viewUI: anyViewUI)
                queue.removeAll()
                queue.append(next)

                dismiss { [weak self] in self?.dequeueAndStartIfNeeded() }
                return activeToken
            }
        }

        // new: bump del token
        generation &+= 1
        activeToken = generation

        // start now
        startShow(with: anyViewUI)

        return activeToken
    }

    private func startShow(with viewUI: @escaping (LucidBannerState) -> AnyView) {
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

    // MARK: - UPDATE

    func update(title: String? = nil,
                subtitle: String? = nil,
                progress: Double? = nil,
                for token: Int? = nil) {
        if let token,
           token != activeToken {
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

        if animated {
            UIView.animate(withDuration: 0.2) {window.layoutIfNeeded() }
        } else {
            window.layoutIfNeeded()
        }
    }

    // MARK: - REPLACE CONTENT

    func replaceContent<Content: View>(
        @ViewBuilder _ viewUI: @escaping (LucidBannerState) -> Content) {

        self.contentView = { (_: LucidBannerState) -> AnyView in AnyView(viewUI(self.state)) }

        replaceContentInternal(remeasureWidth: false)
        remeasureAndSetWidthConstraint(animated: false, force: true)
    }

    // MARK: - DISMISS

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

    func dismiss(for token: Int, completion: (() -> Void)? = nil) {
        guard token == activeToken else {
            return
        }

        dismiss(completion: completion) // chiama il tuo dismiss esistente
    }

    // MARK: - Private (internal)

    private func dequeueAndStartIfNeeded() {
        guard window == nil,
              !isAnimatingIn,
              !isDismissing,
        !queue.isEmpty else {
            return
        }
        let next = queue.removeFirst()

        // State
        state.title = next.title
        state.subtitle = next.subtitle
        state.progress = next.progress
        state.textColor = next.textColor
        state.systemImage = next.systemImage
        state.imageColor = next.imageColor
        state.imageAnimation = next.imageAnimation
        state.progressColor = next.progressColor

        // Presentation
        autoDismissAfter = next.autoDismissAfter
        fixedWidth = next.fixedWidth
        minWidth = next.minWidth
        maxWidth = next.maxWidth
        topAnchor = next.topAnchor

        generation &+= 1
        activeToken = generation

        startShow(with: next.viewUI)
    }

    private func attachWindowAndPresent() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState != .background }) else { return }

        let windows = LucidBannerPassthroughWindow(windowScene: scene)
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
            view.topAnchor.constraint(equalTo: windows.safeAreaLayoutGuide.topAnchor, constant: self.topAnchor),
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
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            panGesture.cancelsTouchesInView = false
            view.addGestureRecognizer(panGesture)
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

        UIView.animate(withDuration: 0.5,
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
        guard let window, let host = hostController else { return }

        if isAnimatingIn && lockWidthUntilSettled && !force {
            pendingRelayout = true
            return
        }

        // Se la larghezza è fissa, non misurare
        if fixedWidth != nil {
            return
        }

        // Segnala "misura" alla view (nasconde progress ecc.)
        state.flags["measuring"] = true
        defer {
            state.flags["measuring"] = false
        }

        // Allinea layout prima di misurare
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let widthCap = min(max(0, window.bounds.width - 24), maxWidth)
        let fitting = host.sizeThatFits(in: CGSize(width: widthCap, height: UIView.layoutFittingCompressedSize.height))
        let target = min(max(fitting.width, minWidth), widthCap)

        if let constraint = widthConstraint {
            let current = constraint.constant
            let newWidth = (force ? target : max(target, current))

            guard abs(newWidth - current) > 0.5 else {
                return
            }

            constraint.constant = newWidth
        } else {
            let constraint = host.view.widthAnchor.constraint(equalToConstant: target)
            constraint.isActive = true
            widthConstraint = constraint
        }

        if animated {
            UIView.animate(withDuration: 0.20) {
                window.layoutIfNeeded()
            }
        } else {
            UIView.performWithoutAnimation {
                window.layoutIfNeeded()
            }
        }
    }

    private func scheduleAutoDismiss() {
        dismissTimer?.cancel()
        let seconds = self.autoDismissAfter

        guard seconds > 0 else {
            return
        }

        let tokenAtSchedule = activeToken
        dismissTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            self?.dismiss(for: tokenAtSchedule)
        }
    }

    // Swipe-up (transform-based)
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
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
                dismiss(for: activeToken)
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

internal final class LucidBannerPassthroughWindow: UIWindow {
    weak var hitTargetView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let target = hitTargetView else { return nil }
        let p = target.convert(point, from: self)
        return target.bounds.contains(p) ? super.hitTest(point, with: event) : nil
    }
}

// MARK: - Stato osservabile condiviso

@MainActor
internal final class LucidBannerState: ObservableObject {
    @Published var title: String
    @Published var subtitle: String?
    @Published var textColor: UIColor

    @Published var systemImage: String?
    @Published var imageColor: UIColor
    @Published var imageAnimation: LucidBanner.LucidBannerAnimationStyle

    @Published var progress: Double?
    @Published var progressColor: UIColor

    @Published var flags: [String: Any] = [:]

    init(title: String,
         subtitle: String? = nil,
         textColor: UIColor,
         systemImage: String? = nil,
         imageColor: UIColor,
         imageAnimation: LucidBanner.LucidBannerAnimationStyle,
         progress: Double? = nil,
         progressColor: UIColor) {
        self.title = title
        self.subtitle = (subtitle?.isEmpty == true) ? nil : subtitle
        self.textColor = textColor
        self.systemImage = systemImage
        self.imageColor = imageColor
        self.imageAnimation = imageAnimation
        self.progress = progress
        self.progressColor = progressColor
    }
}
