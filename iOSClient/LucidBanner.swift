//
//  LucidBanner.swift
//  LucidBannerDemo
//
//  Created by Marino Faggiana on 28/10/25.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Shared State

@MainActor
public final class LucidBannerState: ObservableObject {
    // Text
    @Published public var title: String?
    @Published public var subtitle: String?
    @Published public var footnote: String?

    // Icon & animation
    @Published public var systemImage: String?
    @Published public var imageAnimation: LucidBanner.LucidBannerAnimationStyle

    // Progress
    @Published public var progress: Double?

    // Misc
    @Published public var stage: String?
    @Published public var flags: [String: Any] = [:]

    public init(title: String? = nil,
                subtitle: String? = nil,
                footnote: String? = nil,
                systemImage: String? = nil,
                imageAnimation: LucidBanner.LucidBannerAnimationStyle,
                progress: Double? = nil,
                stage: String? = nil) {
        self.title = (title?.isEmpty == true) ? nil : title
        self.subtitle = (subtitle?.isEmpty == true) ? nil : subtitle
        self.footnote = (footnote?.isEmpty == true) ? nil : footnote
        self.systemImage = systemImage
        self.imageAnimation = imageAnimation
        self.progress = progress
        self.stage = stage
    }
}

// MARK: - Passthrough Window

@MainActor
internal final class LucidBannerWindow: UIWindow {
    var isPassthrough: Bool = true
    weak var hitTargetView: UIView?

    // Called whenever window lays out subviews (e.g. on rotation)
    var onLayoutChange: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayoutChange?()
    }

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

@MainActor
public final class LucidBanner: NSObject, UIGestureRecognizerDelegate {
    public static let shared = LucidBanner()
    public static var useSafeArea: Bool = true

    public enum ShowPolicy { case replace, enqueue, drop }
    public enum LucidBannerAnimationStyle {
        case none, rotate, pulse, pulsebyLayer, breathe, bounce, wiggle, scale, scaleUpbyLayer
    }
    public enum VerticalPosition { case top, center, bottom }
    public enum HorizontalAlignment { case left, center, right }

    // Pending payload used for queueing
    private struct PendingShow {
        let scene: UIScene?
        let title: String?
        let subtitle: String?
        let footnote: String?
        let systemImage: String?
        let imageAnimation: LucidBannerAnimationStyle
        let progress: Double?
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
        let token: Int
    }

    // View factory for the current visible banner
    private var contentView: ((LucidBannerState) -> AnyView)?

    // Window/UI
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
    private var lastMeasuredHeight: CGFloat = 0
    private var minWidth: CGFloat = 220
    private var maxWidth: CGFloat = 420
    private let minHeight: CGFloat = 44
    private var fixedWidth: CGFloat?

    // Position
    private var vPosition: VerticalPosition = .top
    private var hAlignment: HorizontalAlignment = .center
    private var horizontalMargin: CGFloat = 12
    private var verticalMargin: CGFloat = 10
    private var presentedVPosition: VerticalPosition = .top

    // Queue
    private var queue: [PendingShow] = []

    // Gestures
    private var interactionUnlockTime: CFTimeInterval = 0
    private weak var panGestureRef: UIPanGestureRecognizer?

    // Shared observable state
    let state = LucidBannerState(title: nil,
                                 subtitle: nil,
                                 footnote: nil,
                                 systemImage: nil,
                                 imageAnimation: .none,
                                 progress: nil,
                                 stage: nil)

    // Config
    private var swipeToDismiss = true
    private var autoDismissAfter: TimeInterval = 0

    // Token/revision
    private var generation: Int = 0
    private var activeToken: Int = 0
    private var revisionForVisible: Int = 0
    private var onTapWithContext: ((_ token: Int, _ revision: Int, _ stage: String?) -> Void)?

    // MARK: - Public API

    /// Presents a new banner. If one is already visible, behavior follows `policy`.
    @discardableResult
    public func show<Content: View>(scene: UIScene? = nil,
                                    title: String? = nil,
                                    subtitle: String? = nil,
                                    footnote: String? = nil,
                                    systemImage: String? = nil,
                                    imageAnimation: LucidBannerAnimationStyle = .none,
                                    progress: Double? = nil,
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
        let normalizedTitle: String? = {
            guard let text = title?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return nil
            }
            return text
        }()

        let normalizedSubtitle: String? = {
            guard let text = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return nil
            }
            return text
        }()

        let normalizedFootnote: String? = {
            guard let text = footnote?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return nil
            }
            return text
        }()

        let normalizedProgress: Double? = {
            guard let progress,
                  progress > 0 else {
                return nil
            }
            return progress
        }()

        // If nothing meaningful to show, keep current token
        let hasContent = normalizedTitle != nil || normalizedSubtitle != nil || normalizedFootnote != nil || (normalizedProgress ?? 0) > 0
        guard hasContent else {
            return activeToken
        }

        // Prepare view factory bound to the shared state
        let viewFactory: (LucidBannerState) -> AnyView = { s in AnyView(content(s)) }

        // Generate a token
        generation &+= 1
        let newToken = generation

        // Build pending payload
        let pending = PendingShow(
            scene: scene,
            title: normalizedTitle,
            subtitle: normalizedSubtitle,
            footnote: normalizedFootnote,
            systemImage: systemImage,
            imageAnimation: imageAnimation,
            progress: normalizedProgress,
            fixedWidth: fixedWidth,
            minWidth: minWidth,
            maxWidth: maxWidth,
            vPosition: vPosition,
            hAlignment: hAlignment,
            horizontalMargin: horizontalMargin,
            verticalMargin: verticalMargin,
            autoDismissAfter: autoDismissAfter,
            swipeToDismiss: swipeToDismiss,
            blocksTouches: blocksTouches,
            stage: stage,
            onTapWithContext: onTapWithContext,
            viewUI: viewFactory,
            token: newToken
        )

        // If a window is active/animating, queue or replace
        if window != nil || isAnimatingIn || isDismissing {
            switch policy {
            case .drop:
                return activeToken
            case .enqueue:
                queue.append(pending)
                return activeToken
            case .replace:
                queue.removeAll()
                queue.append(pending)
                dismiss { [weak self] in self?.dequeueAndStartIfNeeded() }
                return newToken
            }
        }

        // No banner visible: present now
        activeToken = newToken
        applyPending(pending)
        startShow(with: pending.viewUI)
        return newToken
    }

    @MainActor
    public func update(title: String? = nil,
                       subtitle: String? = nil,
                       footnote: String? = nil,
                       systemImage: String? = nil,
                       imageAnimation: LucidBanner.LucidBannerAnimationStyle? = nil,
                       progress: Double? = nil,
                       stage: String? = nil,
                       onTapWithContext: ((_ token: Int, _ revision: Int, _ stage: String?) -> Void)? = nil,
                       for token: Int? = nil) {
        // Must target the active banner
        guard window != nil, (token == nil || token == activeToken) else {
            return
        }

        // Snapshot to detect progress visibility change
        let wasProgressVisible = (state.progress ?? 0) > 0

        if let title {
            let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
            state.title = t.isEmpty ? nil : t
        }
        if let subtitle {
            let s = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            state.subtitle = s.isEmpty ? nil : s
        }
        if let footnote {
            let f = footnote.trimmingCharacters(in: .whitespacesAndNewlines)
            state.footnote = f.isEmpty ? nil : f
        }

        if let systemImage {
            state.systemImage = systemImage
        }
        if let imageAnimation {
            state.imageAnimation = imageAnimation
        }

        if let progress {
            // Clamp and set visibility
            let clamped = max(0, min(1, progress))
            state.progress = clamped > 0 ? clamped : nil
        }

        if let stage {
            state.stage = stage
        }
        if let onTapWithContext {
            self.onTapWithContext = onTapWithContext
        }

        // Detect if progress view appeared/disappeared
        let isProgressVisibleNow = (state.progress ?? 0) > 0
        let progressVisibilityChanged = wasProgressVisible != isProgressVisibleNow

        // Any content change bumps revision (optional, but useful for tap context)
        revisionForVisible &+= 1

        hostController?.view.invalidateIntrinsicContentSize()

        // If only the numeric progress changed (visible -> visible), DO NOT remeasure
        if progressVisibilityChanged {
            // Structure of the view changed -> remeasure
            if isAnimatingIn && lockWidthUntilSettled && fixedWidth == nil {
                pendingRelayout = true
            } else {
                remeasureAndSetWidthConstraint(animated: true)
            }
        } else {
            // No structural change: just layout the window without animation
            if let window {
                UIView.performWithoutAnimation {
                    window.layoutIfNeeded()
                }
            }
        }
    }

    /// Whether a token still refers to the visible banner.
    public func isAlive(_ token: Int) -> Bool {
        token == activeToken && window != nil
    }

    // MARK: - Dismiss

    public func dismiss(completion: (() -> Void)? = nil) {
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

        hostView.isUserInteractionEnabled = false
        panGestureRef?.isEnabled = false
        isDismissing = true

        let offsetY: CGFloat = {
            switch presentedVPosition {
            case .top:    return -window.bounds.height
            case .bottom: return  window.bounds.height
            case .center: return 0
            }
        }()

        UIView.animate(withDuration: 0.35,
                       delay: 0,
                       options: [.curveEaseIn, .beginFromCurrentState]) { [weak self] in
            guard let self else { return }
            hostView.alpha = 0
            hostView.transform = (self.presentedVPosition == .center)
                ? CGAffineTransform(scaleX: 0.9, y: 0.9)
                : CGAffineTransform(translationX: 0, y: offsetY)
            hostView.layer.shadowOpacity = 0
            self.window?.layoutIfNeeded()
        } completion: { [weak self] _ in
            guard let self else { return }
            self.hostController = nil
            window.isHidden = true
            self.window = nil
            self.widthConstraint = nil
            self.heightConstraint = nil
            self.isDismissing = false

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self else { return }
                if self.window == nil, !self.isDismissing {
                    self.dequeueAndStartIfNeeded()
                }
                completion?()
            }
        }
    }

    public func dismiss(for token: Int, completion: (() -> Void)? = nil) {
        guard token == activeToken else { return }
        dismiss(completion: completion)
    }

    // MARK: - Internals

    private func startShow(with viewUI: @escaping (LucidBannerState) -> AnyView) {
        lockWidthUntilSettled = true
        isAnimatingIn = true
        pendingRelayout = false
        contentView = viewUI
        attachWindowAndPresent()
        scheduleAutoDismiss()
    }

    private func applyPending(_ p: PendingShow) {
        // Text & image
        scene = p.scene
        state.title = p.title
        state.subtitle = p.subtitle
        state.footnote = p.footnote
        state.systemImage = p.systemImage
        state.imageAnimation = p.imageAnimation

        // Progress & stage
        state.progress = p.progress
        state.stage = p.stage

        // Layout & behavior
        autoDismissAfter = p.autoDismissAfter
        fixedWidth = p.fixedWidth
        minWidth = p.minWidth
        maxWidth = p.maxWidth
        vPosition = p.vPosition
        hAlignment = p.hAlignment
        horizontalMargin = p.horizontalMargin
        verticalMargin = p.verticalMargin
        blocksTouches = p.blocksTouches
        swipeToDismiss = p.blocksTouches ? false : p.swipeToDismiss

        // Tap & revision
        onTapWithContext = p.onTapWithContext
        revisionForVisible = 0
    }

    private func dequeueAndStartIfNeeded() {
        guard !isAnimatingIn, !isDismissing, window == nil else { return }
        guard !queue.isEmpty else {
            return
        }

        let next = queue.removeFirst()
        isAnimatingIn = true
        activeToken = next.token

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.applyPending(next)
            self.presentedVPosition = next.vPosition
            self.startShow(with: next.viewUI)
        }
    }

    /// Attach the banner window to the current foreground scene and present it with animation.
    /// The banner is always constrained inside the safe area, both vertically and horizontally.
    /// - Note:
    ///   - If `fixedWidth == 0` or (`fixedWidth == nil` and `maxWidth == 0`),
    ///     the banner expands to the full safe-area width.
    ///   - Otherwise it uses alignment + margins inside the safe area.
    private func attachWindowAndPresent() {
        // Resolve the target UIWindowScene
        guard let scene: UIWindowScene = (self.scene as? UIWindowScene) ??
            UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })
        else {
            return
        }

        // Create custom banner window
        let window = LucidBannerWindow(windowScene: scene)
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        window.isPassthrough = !blocksTouches
        window.accessibilityViewIsModal = blocksTouches

        // Build SwiftUI host view
        let content = contentView?(state) ?? AnyView(EmptyView())
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear

        // Root container view
        let root = UIView()
        root.backgroundColor = .clear
        root.translatesAutoresizingMaskIntoConstraints = false

        // Background scrim (optional overlay for blocking touches)
        let scrim = UIControl()
        scrim.translatesAutoresizingMaskIntoConstraints = false
        scrim.backgroundColor = UIColor.black.withAlphaComponent(blocksTouches ? 0.08 : 0.0)
        scrim.isUserInteractionEnabled = blocksTouches

        // Compose hierarchy
        let rootViewController = UIViewController()
        rootViewController.view = root
        window.rootViewController = rootViewController

        root.addSubview(scrim)
        root.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false

        // Safe area layout guide used for both vertical and horizontal layout
        let guide = root.safeAreaLayoutGuide
        let useSafeArea = LucidBanner.useSafeArea

        // Full-width-in-safe-area mode:
        // - If fixedWidth is provided and equals 0 → full safe-area width
        // - Else if fixedWidth is nil and maxWidth equals 0 → full safe-area width
        let isFullWidth: Bool = {
            if let fixedWidth {
                return fixedWidth == 0
            } else {
                return maxWidth == 0
            }
        }()

        // --- Constraints ---
        var constraints: [NSLayoutConstraint] = []

        // Scrim fills the entire window/root (not limited to safe area)
        constraints += [
            scrim.topAnchor.constraint(equalTo: root.topAnchor),
            scrim.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ]

        switch vPosition {
        case .top:
            constraints.append(host.view.topAnchor.constraint(equalTo: useSafeArea ? guide.topAnchor : root.topAnchor,constant: verticalMargin))
        case .center:
            constraints.append(host.view.centerYAnchor.constraint(equalTo: useSafeArea ? guide.centerYAnchor : root.centerYAnchor))
        case .bottom:
            constraints.append(host.view.bottomAnchor.constraint(equalTo: useSafeArea ? guide.bottomAnchor : root.bottomAnchor, constant: -verticalMargin))
        }

        switch hAlignment {
        case .center:
            if isFullWidth {
                constraints.append(host.view.leadingAnchor.constraint(equalTo: useSafeArea ? guide.leadingAnchor : root.leadingAnchor))
                constraints.append(host.view.trailingAnchor.constraint(equalTo: useSafeArea ? guide.trailingAnchor : root.trailingAnchor))
            } else {
                constraints.append(host.view.centerXAnchor.constraint(equalTo: useSafeArea ? guide.centerXAnchor : root.centerXAnchor))
                constraints.append(host.view.leadingAnchor.constraint(greaterThanOrEqualTo: useSafeArea ? guide.leadingAnchor : root.leadingAnchor, constant: horizontalMargin))
                constraints.append(host.view.trailingAnchor.constraint(lessThanOrEqualTo: useSafeArea ? guide.trailingAnchor : root.trailingAnchor, constant: -horizontalMargin))
            }
        case .left:
            if isFullWidth {
                constraints.append(host.view.leadingAnchor.constraint(equalTo: useSafeArea ? guide.leadingAnchor : root.leadingAnchor))
                constraints.append(host.view.trailingAnchor.constraint(equalTo: useSafeArea ? guide.trailingAnchor : root.trailingAnchor))
            } else {
                constraints.append(host.view.leadingAnchor.constraint(equalTo: useSafeArea ? guide.leadingAnchor : root.leadingAnchor, constant: horizontalMargin))
                constraints.append(host.view.trailingAnchor.constraint(lessThanOrEqualTo: useSafeArea ? guide.trailingAnchor : root.trailingAnchor, constant: -horizontalMargin))
            }
        case .right:
            if isFullWidth {
                constraints.append(host.view.leadingAnchor.constraint(equalTo: useSafeArea ? guide.leadingAnchor : root.leadingAnchor))
                constraints.append(host.view.trailingAnchor.constraint(equalTo: useSafeArea ? guide.trailingAnchor : root.trailingAnchor))
            } else {
                constraints.append(host.view.trailingAnchor.constraint(equalTo: useSafeArea ? guide.trailingAnchor : root.trailingAnchor, constant: -horizontalMargin))
                constraints.append(host.view.leadingAnchor.constraint(greaterThanOrEqualTo: useSafeArea ? guide.leadingAnchor : root.leadingAnchor, constant: horizontalMargin))
            }
        }

        // Height always at least minHeight
        constraints.append(
            host.view.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight)
        )

        // --- Width behavior ---
        if let fixedWidth {
            if fixedWidth > 0 {
                // Fixed width mode: explicit constant width (inside safe area)
                constraints.append(host.view.widthAnchor.constraint(equalToConstant: fixedWidth))
            } else {
                // fixedWidth == 0 → full safe-area width
                // Width is resolved purely by leading/trailing constraints above.
            }
        } else {
            if isFullWidth {
                // maxWidth == 0 and fixedWidth == nil → full safe-area width
                // Width is resolved by leading/trailing; no extra width constraints.
            } else {
                // Flexible width: minWidth ≤ width ≤ maxWidth, inside safe area
                constraints.append(host.view.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth))
                constraints.append(host.view.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth))
            }
        }

        NSLayoutConstraint.activate(constraints)

        // Content hugging & compression priorities
        host.view.setContentHuggingPriority(.required, for: .horizontal)
        host.view.setContentCompressionResistancePriority(.required, for: .horizontal)
        host.view.setContentHuggingPriority(.required, for: .vertical)
        host.view.setContentCompressionResistancePriority(.required, for: .vertical)

        // Gesture recognizers
        window.hitTargetView = host.view

        if swipeToDismiss {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            pan.cancelsTouchesInView = false
            pan.delegate = self
            host.view.addGestureRecognizer(pan)
            panGestureRef = pan
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBannerTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        host.view.addGestureRecognizer(tap)

        // Accessibility
        host.view.isAccessibilityElement = true
        host.view.accessibilityTraits.insert(.button)
        host.view.accessibilityLabel = "Banner"

        // Store references
        self.window = window
        self.hostController = host
        self.scrimView = scrim

        // Handle rotation: let SwiftUI recalculate intrinsic content size
        window.onLayoutChange = { [weak self] in
            self?.hostController?.view.invalidateIntrinsicContentSize()
        }

        // --- Presentation animation ---
        presentedVPosition = vPosition
        interactionUnlockTime = CACurrentMediaTime() + 0.25
        host.view.alpha = 0

        window.makeKeyAndVisible()
        window.layoutIfNeeded()

        switch presentedVPosition {
        case .top:
            host.view.transform = CGAffineTransform(translationX: 0, y: -window.bounds.height)
        case .bottom:
            host.view.transform = CGAffineTransform(translationX: 0, y: window.bounds.height)
        case .center:
            host.view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }

        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            host.view.alpha = 1
            host.view.transform = .identity
        } completion: { [weak self] _ in
            self?.isAnimatingIn = false
            self?.lockWidthUntilSettled = false
        }
    }

    @MainActor
    private func remeasureAndSetWidthConstraint(animated: Bool = false) {
        guard let window, let host = hostController else { return }

        // Ask SwiftUI to recompute its intrinsic size
        host.view.invalidateIntrinsicContentSize()

        // Let Auto Layout update the frame
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
        let seconds = autoDismissAfter
        guard seconds > 0 else { return }
        let tokenAtSchedule = activeToken

        dismissTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            self?.dismiss(for: tokenAtSchedule)
        }
    }

    // MARK: - Gestures

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let hostView = hostController?.view else { return true }
        let p = touch.location(in: hostView)
        let inside = hostView.bounds.contains(p)
        if !blocksTouches && !inside { return false }
        if blocksTouches {
            if gestureRecognizer is UITapGestureRecognizer { return inside }
            if gestureRecognizer is UIPanGestureRecognizer { return inside }
        }
        return true
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if CACurrentMediaTime() < interactionUnlockTime { return false }
        if let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view {
            let velocityY = pan.velocity(in: view).y
            switch presentedVPosition {
            case .top:    return velocityY < 0
            case .bottom: return velocityY > 0
            case .center:
                let t = pan.translation(in: view)
                return abs(t.y) > abs(t.x) && abs(velocityY) > 150
            }
        }
        return true
    }

    @objc private func handlePanGesture(_ g: UIPanGestureRecognizer) {
        guard let view = hostController?.view else { return }
        if CACurrentMediaTime() < interactionUnlockTime { return }

        let dy = g.translation(in: view).y

        func applyTransform(for y: CGFloat) {
            switch presentedVPosition {
            case .top:    view.transform = CGAffineTransform(translationX: 0, y: min(0, y))
            case .bottom: view.transform = CGAffineTransform(translationX: 0, y: max(0, y))
            case .center:
                let t = max(-80, min(80, y))
                let s = max(0.9, 1.0 - abs(t) / 800.0)
                view.transform = CGAffineTransform(translationX: 0, y: t).scaledBy(x: s, y: s)
            }
        }

        switch g.state {
        case .changed:
            applyTransform(for: dy)
            view.alpha = max(0.4, 1.0 - abs(view.transform.ty) / 120.0)
        case .ended, .cancelled:
            let vy = g.velocity(in: view).y
            let shouldDismiss: Bool = {
                switch presentedVPosition {
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
