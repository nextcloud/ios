// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

struct UploadBannerView: View {
    @ObservedObject var state: LucidBannerState
    @State var trigger = true
    let onButtonTap: (() -> Void)?
    let allowMinimizeOnTap: Bool

    init(state: LucidBannerState,
         allowMinimizeOnTap: Bool = false,
         onButtonTap: (() -> Void)? = nil) {
        self.state = state
        self.allowMinimizeOnTap = allowMinimizeOnTap
        self.onButtonTap = onButtonTap
    }

    var body: some View {
        let showTitle = !(state.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showSubtitle = !(state.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showFootnote = !(state.footnote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        let isSuccess = (state.typedStage == .success)
        let isError = (state.typedStage == .error)
        let isButton = (state.typedStage == .init(rawValue: "button"))

        containerView(state: state) {
            if state.isMinimized {
                HStack(spacing: 5) {
                    Image(systemName: state.systemImage ?? "arrow.up.circle")
                        .font(.body.weight(.medium))
                        .frame(width: 20, height: 20)

                    if let p = state.progress {
                        Text("\(Int(p * 100))%")
                            .font(.caption2.monospacedDigit())
                            .frame(height: 20)
                    }

                }
                .padding(.horizontal, 3)
                .padding(.vertical, 3)
                .clipShape(Capsule())
            } else if isSuccess {
                 HStack(alignment: .center, spacing: 10) {
                     if #available(iOS 26, *) {
                         Image(systemName: "checkmark")
                             .font(.system(size: 60, weight: .regular))
                             .foregroundStyle(.green)
                             .symbolEffect(.drawOn, isActive: trigger)
                             .task {
                                 try? await Task.sleep(for: .seconds(0.1))
                                 trigger = false
                             }
                     } else {
                         Image(systemName: "checkmark")
                             .font(.system(size: 80, weight: .regular))
                             .foregroundStyle(.green)
                     }
                 }
                 .padding(.horizontal, 20)
                 .padding(.vertical, 20)
            } else if isError {
                VStack(spacing: 15) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 7) {
                            Text("_error_")
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.leading)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.9)
                                .foregroundStyle(.primary)
                            if showSubtitle, let subtitle = state.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 15) {
                    HStack(alignment: .center, spacing: 10) {
                        if let systemImage = state.systemImage {
                            Image(systemName: systemImage)
                                .applyBannerAnimation(state.imageAnimation)
                                .font(.system(size: 30, weight: .regular))
                                .foregroundStyle(Color(uiColor: NCBrandColor.shared.customer))
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            if showTitle, let title = state.title {
                                Text(title)
                                    .font(.subheadline.weight(.bold))
                                    .multilineTextAlignment(.leading)
                                    .truncationMode(.tail)
                                    .minimumScaleFactor(0.9)
                                    .foregroundStyle(.primary)
                            }
                            if showSubtitle, let subtitle = state.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.primary)
                            }
                            if showFootnote, let footnote = state.footnote {
                                Text(footnote)
                                    .font(.caption)
                                    .multilineTextAlignment(.leading)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    ProgressView(value: state.progress ?? 0)
                        .tint(.accentColor)
                        .opacity(state.progress == nil ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: state.progress == nil)

                    if isButton {
                        VStack {
                            Button("_cancel_") {
                                onButtonTap?()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .stroke(.primary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(15)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Container

    @ViewBuilder
    func containerView<Content: View>(state: LucidBannerState, @ViewBuilder _ content: () -> Content) -> some View {
        let isError = (state.typedStage == .error)
        let cornerRadius: CGFloat = 22
        let isMinimized = state.isMinimized

        let base = content()
            .contentShape(Rectangle())
            .onTapGesture {
                guard allowMinimizeOnTap else { return }
                LucidBannerMinimizeCoordinator.shared.handleTap(state)
            }

        if isMinimized {
            if #available(iOS 26, *) {
                if isError {
                    base
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(Color.red.opacity(1))
                        )
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
                } else {
                    base
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
                }
            } else {
                let colorBg = isError ? Color.red.opacity(0.9) : Color.white.opacity(0.9)

                base
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(colorBg, lineWidth: 0.6)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
            }
        } else {
            let contentBase = base
                .frame(maxWidth: 500)

            if #available(iOS 26, *) {
                if isError {
                    contentBase
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(Color.red.opacity(1))
                        )
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    contentBase
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                let colorBg = isError ? Color.red.opacity(0.9) : Color.white.opacity(0.9)

                contentBase
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(colorBg, lineWidth: 0.6)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

public extension View {
    @ViewBuilder
    func applyBannerAnimation(_ style: LucidBanner.LucidBannerAnimationStyle) -> some View {
        switch style {

        // ---- iOS 18+ effects ----
        case .rotate, .pulse, .pulsebyLayer, .breathe, .bounce, .wiggle, .scale, .scaleUpbyLayer:
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
                default:
                    self
                }
            } else {
                self
            }

        // ---- iOS 26+ effect: drawOn ----
        case .drawOn:
            if #available(iOS 26, *) {
                self
            } else {
                self
            }

        // ---- no animation ----
        case .none:
            self
        }
    }
}

@MainActor
func showUploadBanner(scene: UIWindowScene?,
                      vPosition: LucidBanner.VerticalPosition = .center,
                      hAlignment: LucidBanner.HorizontalAlignment = .center,
                      verticalMargin: CGFloat = 0,
                      blocksTouches: Bool = false,
                      draggable: Bool = false,
                      stage: LucidBanner.Stage? = nil,
                      policy: LucidBanner.ShowPolicy = .drop,
                      allowMinimizeOnTap: Bool = false,
                      onButtonTap: (() -> Void)? = nil) -> Int? {
    let token = LucidBanner.shared.show(
        scene: scene,
        vPosition: vPosition,
        hAlignment: hAlignment,
        verticalMargin: verticalMargin,
        blocksTouches: blocksTouches,
        draggable: draggable,
        stage: stage,
        policy: policy
    ) { state in
        UploadBannerView(state: state,
                         allowMinimizeOnTap: allowMinimizeOnTap,
                         onButtonTap: onButtonTap)
    }

#if !EXTENSION
    if allowMinimizeOnTap {
        LucidBannerMinimizeCoordinator.shared.register(token: token) { context in
            let bounds = context.bounds
            let controller = SceneManager.shared.getController(scene: scene)
            var height: CGFloat = 55
            let over: CGFloat = 20
            if let scene,
               let controller,
               let window = scene.windows.first {
                let isPadLayout = (window.rootViewController?.traitCollection.horizontalSizeClass == .regular)
                if !isPadLayout {
                    height = controller.barHeightBottom + context.safeAreaInsets.bottom + over
                }
            }

            return CGPoint(
                x: bounds.midX,
                y: bounds.maxY - height
            )
        }
    }
#endif
    return token
}

@MainActor
final class LucidBannerMinimizeCoordinator {
    static let shared = LucidBannerMinimizeCoordinator()

    // MARK: - Types

    /// Context passed to the mandatory minimize-point resolver.
    struct ResolveContext {
        /// The active banner token.
        let token: Int

        /// The shared banner state instance (SwiftUI observes this).
        let state: LucidBannerState

        /// The banner host view (UIKit container for the SwiftUI content).
        let hostView: UIView

        /// The window hosting the banner.
        let window: UIWindow

        /// Convenience: window bounds.
        let bounds: CGRect

        /// Convenience: window safe-area insets.
        let safeAreaInsets: UIEdgeInsets
    }

    /// Mandatory resolver used to compute the minimized target point.
    ///
    /// Return a CGPoint in window coordinates where the banner should move
    /// when minimized.
    typealias ResolveMinimizePointHandler = @MainActor (_ context: ResolveContext) -> CGPoint

    // MARK: - Stored properties

    private var currentToken: Int?
    private var resolveHandler: ResolveMinimizePointHandler?
    private var orientationObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            Task { @MainActor in
                // Small delay to let the window/layout settle after rotation.
                try? await Task.sleep(for: .milliseconds(250))
                self.refreshPosition(animated: true)
            }
        }
    }

    deinit {
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
        }
    }

    // MARK: - Registration

    /// Registers the active banner token and the mandatory resolver.
    ///
    /// - Parameters:
    ///   - token: Banner token returned by `LucidBanner.shared.show(...)`.
    ///   - resolveMinimizePoint: Mandatory handler that returns the minimized target point.
    func register(token: Int?, resolveMinimizePoint: @escaping ResolveMinimizePointHandler) {
        guard let token else {
            clear()
            return
        }

        currentToken = token
        resolveHandler = resolveMinimizePoint
    }

    /// Clears the coordinator state.
    func clear() {
        currentToken = nil
        resolveHandler = nil
    }

    // MARK: - Public API

    /// Handles a tap gesture coming from the SwiftUI banner content.
    ///
    /// The coordinator uses the registered token and resolver.
    func handleTap(_ state: LucidBannerState) {
        guard let token = currentToken else { return }

        guard LucidBanner.shared.isAlive(token) else {
            clear()
            return
        }

        if state.isMinimized {
            maximize(state)
        } else {
            minimize(state)
        }
    }

    /// Refreshes banner position after rotation/layout changes.
    ///
    /// If minimized, recomputes the target via the resolver and moves there.
    /// If not minimized, resets to the standard LucidBanner position.
    func refreshPosition(animated: Bool = true) {
        guard let token = currentToken else { return }

        guard LucidBanner.shared.isAlive(token) else {
            clear()
            return
        }

        guard let state = LucidBanner.shared.currentState(for: token) else {
            return
        }

        if state.isMinimized {
            guard let target = resolvedMinimizePoint(for: token, state: state) else {
                return
            }

            LucidBanner.shared.move(
                toX: target.x,
                y: target.y,
                for: token,
                animated: animated
            )
        } else {
            LucidBanner.shared.resetPosition(for: token, animated: true)
        }
    }

    /// Moves the banner only if it is currently minimized.
    func moveIfMinimized(to point: CGPoint, animated: Bool = true) {
        guard let token = currentToken else { return }

        guard LucidBanner.shared.isAlive(token) else {
            clear()
            return
        }

        guard let state = LucidBanner.shared.currentState(for: token),
              state.isMinimized else {
            return
        }

        LucidBanner.shared.move(
            toX: point.x,
            y: point.y,
            for: token,
            animated: animated
        )
    }

    // MARK: - Private helpers

    private func minimize(_ state: LucidBannerState) {
        guard let token = currentToken else { return }

        state.isMinimized = true

        // Disable dragging while minimized.
        LucidBanner.shared.setDraggingEnabled(false, for: token)

        // Re-measure for the compact (minimized) SwiftUI layout.
        LucidBanner.shared.requestRelayout(animated: false)

        if let target = resolvedMinimizePoint(for: token, state: state) {
            LucidBanner.shared.move(
                toX: target.x,
                y: target.y,
                for: token,
                animated: true
            )
        }
    }

    private func maximize(_ state: LucidBannerState) {
        guard let token = currentToken else { return }

        state.isMinimized = false

        if state.draggable {
            LucidBanner.shared.setDraggingEnabled(true, for: token)
        }

        // Re-measure for the full SwiftUI layout.
        LucidBanner.shared.requestRelayout(animated: false)

        // Let LucidBanner restore the canonical position.
        LucidBanner.shared.resetPosition(for: token, animated: true)
    }

    private func resolvedMinimizePoint(for token: Int, state: LucidBannerState) -> CGPoint? {
        guard let resolveHandler else { return nil }

        guard let hostView = LucidBanner.shared.currentHostView(for: token),
              let window = hostView.window else {
            return nil
        }

        let ctx = ResolveContext(
            token: token,
            state: state,
            hostView: hostView,
            window: window,
            bounds: window.bounds,
            safeAreaInsets: window.safeAreaInsets
        )

        return resolveHandler(ctx)
    }
}

// MARK: - Preview

#Preview {
    // Create a mutable preview state
    let state = LucidBannerState(
        title: "Uploading…",
        subtitle: "Minimized style preview",
        systemImage: "arrow.up.circle",
        imageAnimation: .none,
        progress: 0.71,
        stage: "button"
    )

    state.isMinimized = true

    return ZStack {
        LinearGradient(
            colors: [.white, .gray.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )

        UploadBannerView(
            state: state,
            allowMinimizeOnTap: true
        )
        .padding()
    }
}
