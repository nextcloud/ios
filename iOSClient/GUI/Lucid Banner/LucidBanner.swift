// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

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

    @Published var stage: String?

    // flag internal (ex. "measuring")
    @Published var flags: [String: Any] = [:]

    init(title: String,
         subtitle: String? = nil,
         textColor: UIColor,
         systemImage: String? = nil,
         imageColor: UIColor,
         imageAnimation: LucidBanner.LucidBannerAnimationStyle,
         progress: Double? = nil,
         progressColor: UIColor,
         stage: String? = nil) {
        self.title = title
        self.subtitle = (subtitle?.isEmpty == true) ? nil : subtitle
        self.textColor = textColor
        self.systemImage = systemImage
        self.imageColor = imageColor
        self.imageAnimation = imageAnimation
        self.progress = progress
        self.progressColor = progressColor
        self.stage = stage
    }
}

// MARK: - Window
@MainActor
internal final class LucidBannerWindow: UIWindow {
    var isPassthrough: Bool = true
    weak var hitTargetView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isPassthrough else {
            return super.hitTest(point, with: event)
        }
        guard let target = hitTargetView else { return nil }
        let p = target.convert(point, from: self)
        return target.bounds.contains(p) ? super.hitTest(point, with: event) : nil
    }
}

// MARK: - Manager
@MainActor
final class LucidBanner {
    static let shared = LucidBanner()

    enum ShowPolicy { case replace, enqueue, drop }

    enum LucidBannerAnimationStyle {
        case none, rotate, pulse, pulsebyLayer, breathe, bounce, wiggle, scale
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
        let stage: String?
        let autoDismissAfter: TimeInterval
        let fixedWidth: CGFloat?
        let minWidth: CGFloat
        let maxWidth: CGFloat
        let topAnchor: CGFloat
        let swipeToDismiss: Bool
        let blocksTouches: Bool
        let onTapWithContext: ((_ token: Int, _ revision: Int, _ stage: String?) -> Void)?
        let viewUI: (LucidBannerState) -> AnyView
    }

    // View factory
    private var contentView: ((LucidBannerState) -> AnyView)?

    private var blocksTouches = false
    private var window: LucidBannerWindow?
    private weak var scrimView: UIControl?
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

    // Queue
    private var queue: [PendingShow] = []

    // Shared state
    let state = LucidBannerState(title: "",
                                 subtitle: nil,
                                 textColor: .label,
                                 systemImage: nil,
                                 imageColor: .label,
                                 imageAnimation: .none,
                                 progress: nil,
                                 progressColor: .label,
                                 stage: nil)

    // Config
    private var swipeToDismiss = true
    private var autoDismissAfter: TimeInterval = 0

    // Token/revision
    private var generation: Int = 0
    private var activeToken: Int = 0
    private var revisionForVisible: Int = 0
    private var onTapWithContext: ((_ token: Int, _ revision: Int, _ stage: String?) -> Void)?

    func isAlive(_ token: Int) -> Bool { token == activeToken && window != nil }

    // MARK: - SHOW
    @discardableResult
    func show<Content: View>(title: String,
                             subtitle: String? = nil,
                             textColor: UIColor = .label,
                             systemImage: String? = nil,
                             imageColor: UIColor = .label,
                             imageAnimation: LucidBannerAnimationStyle = .none,
                             progress: Double? = nil,
                             progressColor: UIColor = .label,
                             stage: String? = nil,
                             autoDismissAfter: TimeInterval = 0,
                             policy: ShowPolicy = .enqueue,
                             fixedWidth: CGFloat? = nil,
                             minWidth: CGFloat = 220,
                             maxWidth: CGFloat = 420,
                             topAnchor: CGFloat = 10,
                             swipeToDismiss: Bool = true,
                             blocksTouches: Bool = false,
                             onTapWithContext: ((_ token: Int, _ revision: Int, _ stage: String?) -> Void)? = nil,
                             @ViewBuilder content: @escaping (LucidBannerState) -> Content) -> Int {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        state.title = trimmed.isEmpty ? "" : trimmed
        state.textColor = textColor

        if let s = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            state.subtitle = s
        } else {
            state.subtitle = nil
        }

        state.systemImage = systemImage
        state.imageColor = imageColor
        state.imageAnimation = imageAnimation
        state.stage = stage

        if let p = progress, p > 0 { state.progress = p } else { state.progress = nil }
        state.progressColor = progressColor

        self.autoDismissAfter = autoDismissAfter
        self.fixedWidth = fixedWidth
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.topAnchor = topAnchor
        self.blocksTouches = blocksTouches
        self.swipeToDismiss = blocksTouches ? false : swipeToDismiss
        self.onTapWithContext = onTapWithContext
        self.revisionForVisible = 0

        let hasTitle = !state.title.isEmpty
        let hasSubtitle = !(state.subtitle?.isEmpty ?? true)
        let hasProgress = (state.progress ?? 0) > 0
        guard hasTitle || hasSubtitle || hasProgress else {
            return activeToken
        }

        let currentState = self.state
        let anyViewUI: (LucidBannerState) -> AnyView = { _ in AnyView(content(currentState)) }

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
                                         stage: stage,
                                         autoDismissAfter: autoDismissAfter,
                                         fixedWidth: fixedWidth,
                                         minWidth: minWidth,
                                         maxWidth: maxWidth,
                                         topAnchor: topAnchor,
                                         swipeToDismiss: self.swipeToDismiss,
                                         blocksTouches: blocksTouches,
                                         onTapWithContext: onTapWithContext,
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
                                       stage: stage,
                                       autoDismissAfter: autoDismissAfter,
                                       fixedWidth: fixedWidth,
                                       minWidth: minWidth,
                                       maxWidth: maxWidth,
                                       topAnchor: topAnchor,
                                       swipeToDismiss: self.swipeToDismiss,
                                       blocksTouches: blocksTouches,
                                       onTapWithContext: onTapWithContext,
                                       viewUI: anyViewUI)
                queue.removeAll()
                queue.append(next)
                dismiss { [weak self] in
                    self?.dequeueAndStartIfNeeded()
                }
                return activeToken
            }
        }

        generation &+= 1
        activeToken = generation
        startShow(with: anyViewUI)

        return activeToken
    }

    private func startShow(with viewUI: @escaping (LucidBannerState) -> AnyView) {
        lockWidthUntilSettled = true
        isAnimatingIn = true
        pendingRelayout = false
        contentView = viewUI

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
                systemImage: String? = nil,
                imageColor: UIColor? = nil,
                imageAnimation: LucidBannerAnimationStyle? = nil,
                progress: Double? = nil,
                stage: String? = nil,
                onTapWithContext: ((_ token: Int, _ revision: Int, _ stage: String?) -> Void)? = nil,
                for token: Int? = nil) {

        if let token,
            token != activeToken,
            window == nil {
            return
        }
        let oldTitle = state.title
        let oldSub = state.subtitle
        let oldImage = state.systemImage
        let oldStage = state.stage

        if let title {
            let trim = title.trimmingCharacters(in: .whitespacesAndNewlines)
            state.title = trim.isEmpty ? "" : trim
        }
        if let subtitle {
            let trim = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            state.subtitle = trim.isEmpty ? nil : trim
        }
        if let progress { state.progress = (progress > 0) ? progress : nil }
        if let systemImage { state.systemImage = systemImage }
        if let imageColor = imageColor { state.imageColor = imageColor }
        if let imageAnimation { state.imageAnimation = imageAnimation }
        if let stage { state.stage = stage }
        if let onTapWithContext { self.onTapWithContext = onTapWithContext }

        hostController?.view.invalidateIntrinsicContentSize()

        let textChanged = (oldTitle != state.title) || (oldSub != state.subtitle)
        let imageChanged = (oldImage != state.systemImage)
        let stageChanged = (oldStage != state.stage)

        if textChanged || imageChanged || stageChanged {
            revisionForVisible &+= 1
            remeasureAndSetWidthConstraint(animated: true, force: false)
        }
    }

    // MARK: - SIZE

    func setSize(width: CGFloat?, height: CGFloat?, animated: Bool = true) {
        self.fixedWidth = width
        guard let window,
              let view = hostController?.view else {
            return
        }

        if let width {
            if let widthConstraint {
                widthConstraint.constant = width
            }
            else {
                let constraint = view.widthAnchor.constraint(equalToConstant: width)
                constraint.isActive = true
                widthConstraint = constraint
            }
        } else {
            remeasureAndSetWidthConstraint(animated: animated, force: true)
        }

        if let height {
            if let heightConstraint {
                heightConstraint.constant = height
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
            UIView.animate(withDuration: 0.2) { window.layoutIfNeeded() }
        } else {
            window.layoutIfNeeded()
        }
    }

    // MARK: - DISMISS

    func dismiss(completion: (() -> Void)? = nil) {
        dismissTimer?.cancel()
        dismissTimer = nil

        guard let window,
              let hostView = hostController?.view else {
            hostController = nil
            self.window?.isHidden = true
            self.window = nil
            widthConstraint = nil
            heightConstraint = nil
            completion?()
            return
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
        dismiss(completion: completion)
    }

    // MARK: - Private

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
        state.stage = next.stage

        // Present
        autoDismissAfter = next.autoDismissAfter
        fixedWidth = next.fixedWidth
        minWidth = next.minWidth
        maxWidth = next.maxWidth
        topAnchor = next.topAnchor
        blocksTouches = next.blocksTouches
        swipeToDismiss = next.blocksTouches ? false : next.swipeToDismiss
        onTapWithContext = next.onTapWithContext
        revisionForVisible = 0

        generation &+= 1
        activeToken = generation
        startShow(with: next.viewUI)
    }

    private func attachWindowAndPresent() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState != .background }) else {
            return
        }

        let window = LucidBannerWindow(windowScene: scene)
        window.frame = scene.screen.bounds
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        window.isPassthrough = !blocksTouches
        window.accessibilityViewIsModal = blocksTouches

        // Hosting SwiftUI
        let content = contentView?(state) ?? AnyView(EmptyView())
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear

        // Root (scrim + banner)
        let root = UIView()
        root.backgroundColor = .clear
        root.translatesAutoresizingMaskIntoConstraints = false

        let scrim = UIControl()
        scrim.translatesAutoresizingMaskIntoConstraints = false
        scrim.backgroundColor = UIColor.black.withAlphaComponent(blocksTouches ? 0.08 : 0.0)
        scrim.isUserInteractionEnabled = blocksTouches

        window.rootViewController = UIViewController()
        window.rootViewController?.view = root

        root.addSubview(scrim)
        root.addSubview(host.view)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrim.topAnchor.constraint(equalTo: root.topAnchor),
            scrim.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            host.view.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor, constant: self.topAnchor),
            host.view.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            host.view.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight)
        ])

        host.view.setContentHuggingPriority(.required, for: .vertical)
        host.view.setContentCompressionResistancePriority(.required, for: .vertical)
        host.view.setContentHuggingPriority(.required, for: .horizontal)
        host.view.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Gestures
        window.hitTargetView = host.view
        var panGesture: UIPanGestureRecognizer?
        if swipeToDismiss {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            pan.cancelsTouchesInView = false
            host.view.addGestureRecognizer(pan)
            panGesture = pan
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBannerTap))
        tap.cancelsTouchesInView = false
        if let panGesture { tap.require(toFail: panGesture) }
        host.view.addGestureRecognizer(tap)

        host.view.isAccessibilityElement = true
        host.view.accessibilityTraits.insert(.button)
        host.view.accessibilityLabel = state.title.isEmpty ? "Banner" : state.title

        self.window = window
        self.hostController = host
        self.scrimView = scrim

        if let width = fixedWidth {
            let c = host.view.widthAnchor.constraint(equalToConstant: width)
            c.isActive = true
            widthConstraint = c
        } else {
            remeasureAndSetWidthConstraint(animated: false, force: true)
        }

        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        host.view.alpha = 0
        host.view.transform = CGAffineTransform(translationX: 0, y: -host.view.bounds.height - 60)

        UIView.animate(withDuration: 0.5,
                       delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.5,
                       options: [.curveEaseOut, .beginFromCurrentState]) {
            host.view.alpha = 1
            host.view.transform = .identity
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

        if isAnimatingIn && lockWidthUntilSettled && !force {
            pendingRelayout = true
            return
        }

        if fixedWidth != nil {
            return
        }

        state.flags["measuring"] = true
        defer { state.flags["measuring"] = false }

        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let widthCap = min(max(0, window.bounds.width - 24), maxWidth)
        let fitting = host.sizeThatFits(in: CGSize(width: widthCap, height: UIView.layoutFittingCompressedSize.height))
        let target = min(max(fitting.width, minWidth), widthCap)

        if let widthConstraint {
            let current = widthConstraint.constant
            let newWidth = (force ? target : max(target, current))
            guard abs(newWidth - current) > 0.5 else { return }
            widthConstraint.constant = newWidth
        } else {
            let constraint = host.view.widthAnchor.constraint(equalToConstant: target)
            constraint.isActive = true
            widthConstraint = constraint
        }

        if animated {
            UIView.animate(withDuration: 0.20) { window.layoutIfNeeded() }
        } else {
            UIView.performWithoutAnimation { window.layoutIfNeeded() }
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

    // Gesture
    @objc private func handlePanGesture(_ g: UIPanGestureRecognizer) {
        guard let view = hostController?.view else {
            return
        }
        let dy = g.translation(in: view).y

        switch g.state {
        case .changed:
            let y = min(0, dy)
            view.transform = CGAffineTransform(translationX: 0, y: y)
            view.alpha = max(0.4, 1.0 + y / 120.0)
        case .ended, .cancelled:
            let vy = g.velocity(in: view).y
            let shouldDismiss = (dy < -30) || (vy < -500)
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

    @objc private func handleBannerTap() {
        onTapWithContext?(activeToken, revisionForVisible, state.stage)
    }
}
