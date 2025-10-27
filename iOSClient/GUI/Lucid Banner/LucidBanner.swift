// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

/// - Each banner is displayed in its own UIWindow above the status bar.
/// - Only one banner is visible at a time; others are queued if `enqueue` policy is used.
/// - Tap events trigger the `onTapWithContext` closure with contextual info.
/// - Supports swipe-to-dismiss and automatic timed dismissal.
/// - Resizes dynamically when content or orientation changes.

/// LucidBannerState holds all observable data shared with the SwiftUI view.
/// It is updated whenever the banner’s appearance or content changes.
@MainActor
internal final class LucidBannerState: ObservableObject {
    @Published var title: String
    @Published var subtitle: String?
    @Published var footnote: String?
    @Published var textColor: UIColor

    @Published var systemImage: String?
    @Published var imageColor: UIColor
    @Published var imageAnimation: LucidBanner.LucidBannerAnimationStyle

    @Published var progress: Double?
    @Published var progressColor: UIColor

    @Published var stage: String?

    /// Internal flags (e.g. “measuring” during layout updates).
    @Published var flags: [String: Any] = [:]

    init(title: String,
         subtitle: String? = nil,
         footnote: String? = nil,
         textColor: UIColor,
         systemImage: String? = nil,
         imageColor: UIColor,
         imageAnimation: LucidBanner.LucidBannerAnimationStyle,
         progress: Double? = nil,
         progressColor: UIColor,
         stage: String? = nil) {
        self.title = title
        self.subtitle = (subtitle?.isEmpty == true) ? nil : subtitle
        self.footnote = (footnote?.isEmpty == true) ? nil : footnote
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

/// Custom UIWindow subclass that allows optional passthrough touches.
/// When `isPassthrough` is true, only the banner view intercepts touch events.
@MainActor
internal final class LucidBannerWindow: UIWindow {
    var isPassthrough: Bool = true
    weak var hitTargetView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isPassthrough else {
            return super.hitTest(point, with: event)
        }
        guard let target = hitTargetView else {
            return nil
        }

        let p = target.convert(point, from: self)
        return target.bounds.contains(p) ? super.hitTest(point, with: event) : nil
    }
}

// MARK: - Manager

/// LucidBanner is a singleton manager for showing animated, SwiftUI-based banners.
/// Each banner is rendered in a transparent UIWindow above the status bar.
@MainActor
final class LucidBanner {
    /// Shared instance used to show and update banners.
    static let shared = LucidBanner()

    /// Determines what happens if a banner is already showing.
    enum ShowPolicy {
        /// Replaces the current banner immediately.
        case replace
        /// Queues the new banner to be shown after the current one.
        case enqueue
        /// Drops the new banner entirely.
        case drop
    }

    /// Supported image animation styles.
    enum LucidBannerAnimationStyle {
        case none, rotate, pulse, pulsebyLayer, breathe, bounce, wiggle, scale
    }

    enum VerticalPosition {
        case top, center, bottom
    }

    enum HorizontalAlignment {
        case left, center, right
    }

    /// Internal structure for queued banners.
    private struct PendingShow {
        let title: String
        let subtitle: String?
        let footnote: String?
        let textColor: UIColor
        let systemImage: String?
        let imageColor: UIColor
        let imageAnimation: LucidBannerAnimationStyle
        let progress: Double?
        let progressColor: UIColor
        let fixedWidth: CGFloat?
        let minWidth: CGFloat
        let maxWidth: CGFloat
        let vPosition: VerticalPosition
        let hAlignment: HorizontalAlignment
        let horizontalMargin: CGFloat
        let verticalMargin: CGFloat
        let autoDismissAfter: TimeInterval
        let swipeToDismiss: Bool
        let blocksTouches: Bool
        let stage: String?
        let onTapWithContext: ((_ token: Int, _ revision: Int, _ stage: String?) -> Void)?
        let viewUI: (LucidBannerState) -> AnyView
    }

    // View factory
    private var contentView: ((LucidBannerState) -> AnyView)?

    private var scene: UIScene?
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

    // Position
    private var vPosition: VerticalPosition = .top
    private var hAlignment: HorizontalAlignment = .center
    private var horizontalMargin: CGFloat = 12
    private var verticalMargin: CGFloat = 10

    // Queue
    private var queue: [PendingShow] = []

    // Shared state
    let state = LucidBannerState(title: "",
                                 subtitle: nil,
                                 footnote: nil,
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

    // MARK: - PUBLIC

    /// Displays a new banner.
    ///
    /// - Parameters:

    /// - Returns: A unique token identifying this banner instance.
    @discardableResult
    func show<Content: View>(scene: UIScene? = nil,
                             title: String,
                             subtitle: String? = nil,
                             footnote: String? = nil,
                             textColor: UIColor = .label,

                             systemImage: String? = nil,
                             imageColor: UIColor = .label,
                             imageAnimation: LucidBannerAnimationStyle = .none,

                             progress: Double? = nil,
                             progressColor: UIColor = .label,

                             fixedWidth: CGFloat? = nil,
                             minWidth: CGFloat = 220,
                             maxWidth: CGFloat = 420,
                             vPosition: VerticalPosition = .top,
                             hAlignment: HorizontalAlignment = .center,
                             horizontalMargin: CGFloat = 12,
                             verticalMargin: CGFloat = 10,

                             autoDismissAfter: TimeInterval = 0,
                             swipeToDismiss: Bool = true,
                             blocksTouches: Bool = false,

                             stage: String? = nil,

                             policy: ShowPolicy = .enqueue,

                             onTapWithContext: ((_ token: Int, _ revision: Int, _ stage: String?) -> Void)? = nil,
                             @ViewBuilder content: @escaping (LucidBannerState) -> Content) -> Int {
        self.scene = scene

        // Title
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        state.title = trimmed.isEmpty ? "" : trimmed

        // Subtitle
        if let s = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            state.subtitle = s
        } else {
            state.subtitle = nil
        }

        // footnote
        if let f = footnote?.trimmingCharacters(in: .whitespacesAndNewlines), !f.isEmpty {
            state.footnote = f
        } else {
            state.footnote = nil
        }

        // Text color
        state.textColor = textColor

        // Image
        state.systemImage = systemImage
        state.imageColor = imageColor
        state.imageAnimation = imageAnimation

        // State
        state.stage = stage

        // Progress
        if let progress,
           progress > 0 {
            state.progress = progress
        } else {
            state.progress = nil
        }
        state.progressColor = progressColor

        self.autoDismissAfter = autoDismissAfter
        self.fixedWidth = fixedWidth
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.blocksTouches = blocksTouches
        self.swipeToDismiss = blocksTouches ? false : swipeToDismiss

        self.vPosition = vPosition
        self.hAlignment = hAlignment
        self.horizontalMargin = horizontalMargin
        self.verticalMargin = verticalMargin

        self.onTapWithContext = onTapWithContext
        self.revisionForVisible = 0

        let hasTitle = !state.title.isEmpty
        let hasSubtitle = !(state.subtitle?.isEmpty ?? true)
        let hasFootnote = !(state.footnote?.isEmpty ?? true)

        let hasProgress = (state.progress ?? 0) > 0
        guard hasTitle || hasSubtitle || hasFootnote || hasProgress else {
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
                                         footnote: state.footnote,
                                         textColor: textColor,
                                         systemImage: systemImage,
                                         imageColor: imageColor,
                                         imageAnimation: imageAnimation,
                                         progress: state.progress,
                                         progressColor: progressColor,
                                         fixedWidth: fixedWidth,
                                         minWidth: minWidth,
                                         maxWidth: maxWidth,
                                         vPosition: vPosition,
                                         hAlignment: hAlignment,
                                         horizontalMargin: horizontalMargin,
                                         verticalMargin: verticalMargin,
                                         autoDismissAfter: autoDismissAfter,
                                         swipeToDismiss: self.swipeToDismiss,
                                         blocksTouches: blocksTouches,
                                         stage: stage,
                                         onTapWithContext: onTapWithContext,
                                         viewUI: anyViewUI))
                return activeToken
            case .replace:
                let next = PendingShow(title: state.title,
                                       subtitle: state.subtitle,
                                       footnote: state.footnote,
                                       textColor: textColor,
                                       systemImage: systemImage,
                                       imageColor: imageColor,
                                       imageAnimation: imageAnimation,
                                       progress: state.progress,
                                       progressColor: progressColor,
                                       fixedWidth: fixedWidth,
                                       minWidth: minWidth,
                                       maxWidth: maxWidth,
                                       vPosition: vPosition,
                                       hAlignment: hAlignment,
                                       horizontalMargin: horizontalMargin,
                                       verticalMargin: verticalMargin,
                                       autoDismissAfter: autoDismissAfter,
                                       swipeToDismiss: self.swipeToDismiss,
                                       blocksTouches: blocksTouches,
                                       stage: stage,
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

    /// Updates the current banner’s content and appearance.
    ///
    /// Only applies if the banner with the given token is still active.
    /// Use this to change progress, image, or stage without dismissing.
    ///
    /// - Parameters:
    ///   - title: Optional new title.
    ///   - subtitle: Optional new subtitle.
    ///   - footnote: Optional new footnote.
    ///   - systemImage: Optional new icon.
    ///   - imageColor: Optional new tint color.
    ///   - imageAnimation: Optional new animation style.
    ///   - progress: Optional progress (0…1).
    ///   - stage: Optional new logical stage.
    ///   - onTapWithContext: Updated tap handler.
    ///   - token: Token of the banner to update.
    func update(title: String? = nil,
                subtitle: String? = nil,
                footnote: String? = nil,
                systemImage: String? = nil,
                imageColor: UIColor? = nil,
                imageAnimation: LucidBannerAnimationStyle? = nil,
                progress: Double? = nil,
                stage: String? = nil,
                onTapWithContext: ((_ token: Int, _ revision: Int, _ stage: String?) -> Void)? = nil,
                for token: Int? = nil) {
        if (token != nil && token != activeToken) || window == nil {
            return
        }

        // Snapshot old values for change detection
        let oldTitle = state.title
        let oldSub = state.subtitle
        let oldFootnote = state.footnote
        let oldImage = state.systemImage
        let oldStage = state.stage

        // Normalize title/subtitle/footnote
        if let title {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            state.title = trimmed.isEmpty ? "" : trimmed
        }
        if let subtitle {
            let trimmed = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            state.subtitle = trimmed.isEmpty ? nil : trimmed
        }
        if let footnote {
            let trimmed = footnote.trimmingCharacters(in: .whitespacesAndNewlines)
            state.footnote = trimmed.isEmpty ? nil : trimmed
        }

        // Clamp progress to [0,1] and hide when <= 0
        if let progress {
            let clamped = max(0, min(1, progress))
            state.progress = (clamped > 0) ? clamped : nil
        }

        if let systemImage { state.systemImage = systemImage }
        if let imageColor { state.imageColor = imageColor }
        if let imageAnimation { state.imageAnimation = imageAnimation }
        if let stage { state.stage = stage }
        if let onTapWithContext { self.onTapWithContext = onTapWithContext }

        hostController?.view.invalidateIntrinsicContentSize()

        // Detect what actually changed
        let textChanged = (oldTitle != state.title) || (oldSub != state.subtitle) || (oldFootnote != state.footnote)
        let imageChanged = (oldImage != state.systemImage)
        let stageChanged = (oldStage != state.stage)

        // Bump revision for any meaningful state change so tap handlers can disambiguate
        if textChanged || imageChanged || stageChanged {
            revisionForVisible &+= 1
        }

        // Re-measure only when text or image changed (stage-only changes shouldn't resize)
        if textChanged || imageChanged {
            remeasureAndSetWidthConstraint(animated: true, force: false)
        }
    }

    /// Dismisses the current banner, optionally calling a completion handler.
    ///
    /// - Parameter completion: Executed after the animation completes.
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

        let offsetY: CGFloat = {
            switch vPosition {
            case .top: return -hostView.bounds.height - 60
            case .bottom: return hostView.bounds.height + 60
            case .center: return 0
            }
        }()

        UIView.animate(withDuration: 0.35,
                       delay: 0,
                       options: [.curveEaseIn, .beginFromCurrentState]) { [weak self] in
            hostView.transform = (self?.vPosition == .center)
                ? CGAffineTransform(scaleX: 0.9, y: 0.9)
                : CGAffineTransform(translationX: 0, y: offsetY)
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

    /// Dismisses a banner by token, if it is still active.
    ///
    /// - Parameters:
    ///   - token: The token returned from `show`.
    ///   - completion: Executed after the animation completes.
    func dismiss(for token: Int, completion: (() -> Void)? = nil) {
        guard token == activeToken else {
            return
        }
        dismiss(completion: completion)
    }

    // MARK: - Private

    private func setSize(width: CGFloat?, height: CGFloat?, animated: Bool = true) {
        self.fixedWidth = width
        guard let window,
              let view = hostController?.view else {
            return
        }

        if let width {
            if let widthConstraint {
                widthConstraint.constant = width
            } else {
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
        state.footnote = next.footnote
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
        vPosition = next.vPosition
        hAlignment = next.hAlignment
        horizontalMargin = next.horizontalMargin
        verticalMargin = next.verticalMargin
        blocksTouches = next.blocksTouches
        swipeToDismiss = next.blocksTouches ? false : next.swipeToDismiss
        onTapWithContext = next.onTapWithContext
        revisionForVisible = 0

        generation &+= 1
        activeToken = generation
        startShow(with: next.viewUI)
    }

    private func attachWindowAndPresent() {
        guard let scene: UIWindowScene = (self.scene as? UIWindowScene) ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })
        else {
            return
        }

        let window = LucidBannerWindow(windowScene: scene)
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

        var constraints: [NSLayoutConstraint] = []
        // Scrim full screen
        constraints += [
            scrim.topAnchor.constraint(equalTo: root.topAnchor),
            scrim.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ]

        // Vertical position
        switch vPosition {
        case .top:
            constraints.append(host.view.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor,
                                                              constant: verticalMargin))
        case .center:
            constraints.append(host.view.centerYAnchor.constraint(equalTo: root.centerYAnchor))
        case .bottom:
            constraints.append(host.view.bottomAnchor.constraint(equalTo: root.safeAreaLayoutGuide.bottomAnchor,
                                                                 constant: -verticalMargin))
        }

        // Horizontal alignment
        switch hAlignment {
        case .center:
            constraints.append(host.view.centerXAnchor.constraint(equalTo: root.centerXAnchor))
        case .left:
            constraints.append(host.view.leadingAnchor.constraint(equalTo: root.leadingAnchor,
                                                                  constant: horizontalMargin))
        case .right:
            constraints.append(host.view.trailingAnchor.constraint(equalTo: root.trailingAnchor,
                                                                   constant: -horizontalMargin))
        }

        // Min height stays
        constraints.append(host.view.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight))
        NSLayoutConstraint.activate(constraints)

        // Hugging/Compression as before
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
        host.view.accessibilityTraits.insert(UIAccessibilityTraits.button)
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
        switch vPosition {
        case .top:
            host.view.transform = CGAffineTransform(translationX: 0, y: -host.view.bounds.height - 60)
        case .bottom:
            host.view.transform = CGAffineTransform(translationX: 0, y: host.view.bounds.height + 60)
        case .center:
            host.view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }

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

        let availableWidth = window.bounds.width - (horizontalMargin * 2)
        let widthCap = min(max(0, availableWidth), maxWidth)
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

    @objc private func handlePanGesture(_ g: UIPanGestureRecognizer) {
        guard let view = hostController?.view else { return }
        let dy = g.translation(in: view).y

        func transformFor(_ y: CGFloat) {
            switch vPosition {
            case .top:
                view.transform = CGAffineTransform(translationX: 0, y: min(0, y))
            case .bottom:
                view.transform = CGAffineTransform(translationX: 0, y: max(0, y))
            case .center:
                let t = max(-80, min(80, y))
                let s = max(0.9, 1.0 - abs(t) / 800.0)
                view.transform = CGAffineTransform(translationX: 0, y: t).scaledBy(x: s, y: s)
            }
        }

        switch g.state {
        case .changed:
            transformFor(dy)
            view.alpha = max(0.4, 1.0 - abs(view.transform.ty) / 120.0)
        case .ended, .cancelled:
            let vy = g.velocity(in: view).y
            let shouldDismiss: Bool = {
                switch vPosition {
                case .top:    return (dy < -30) || (vy < -500)
                case .bottom: return (dy > 30) || (vy > 500)
                case .center: return abs(dy) > 40 || abs(vy) > 600
                }
            }()
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
        guard !isDismissing else { return }
        onTapWithContext?(activeToken, revisionForVisible, state.stage)
    }
}
