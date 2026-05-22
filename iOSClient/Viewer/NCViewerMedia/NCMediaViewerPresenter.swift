// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

// MARK: - Media Viewer Presenter

/// Presents the media viewer as a fullscreen overlay above the current window.
///
/// The presenter installs a dedicated `UINavigationController` directly on the
/// active window instead of pushing into the app navigation stack. This keeps the
/// viewer independent from the current screen while still allowing the viewer to
/// use a real navigation bar for title, close, and menu actions.
///
/// When a transition source is provided, the presenter animates the visible
/// thumbnail into the fullscreen viewer and animates the currently selected media
/// item back into its matching thumbnail frame on dismissal.
@MainActor
final class NCMediaViewerPresenter: NSObject {
    static let shared = NCMediaViewerPresenter()

    private var navigationController: UINavigationController?
    private weak var viewerContainerView: UIView?
    private var currentViewerTransitionSource: NCViewerTransitionSource?
    private weak var currentModel: NCMediaViewerModel?

    private var closingTransitionSourceProvider: ((_ ocId: String) -> NCViewerTransitionSource?)?
    private var forcedClosingOcId: String?

    private let openingAnimationDuration: TimeInterval = 0.28
    private let closingAnimationDuration: TimeInterval = 0.24

    private var dismissPanGesture: UIPanGestureRecognizer?
    private weak var dismissPanGestureView: UIView?
    private var isTrackingDismissPan = false
    private var isDismissing = false

    private override init() {
        super.init()
    }

    // MARK: - Presentation

    /// Shows the media viewer above the current window.
    ///
    /// - Parameters:
    ///   - model: Media viewer model used to render and page through media items.
    ///   - viewerTransitionSource: Optional thumbnail source used for the opening animation.
    ///   - sourceView: Optional view used to resolve the current window. When nil, the active foreground key window is used.
    ///   - contextMenuController: Controller used by the viewer context menu.
    ///   - closingTransitionSourceProvider: Optional provider used to resolve the current thumbnail source on dismissal.
    func show(
        model: NCMediaViewerModel,
        viewerTransitionSource: NCViewerTransitionSource?,
        from sourceView: UIView? = nil,
        contextMenuController: NCMainTabBarController? = nil,
        closingTransitionSourceProvider: ((_ ocId: String) -> NCViewerTransitionSource?)? = nil
    ) {
        guard let window = sourceView?.window ?? activeWindow() else {
            return
        }

        dismiss(animated: false)

        currentViewerTransitionSource = viewerTransitionSource
        currentModel = model
        self.closingTransitionSourceProvider = closingTransitionSourceProvider
        forcedClosingOcId = nil
        isDismissing = false

        let hostingController = NCMediaViewerHostingController(
            model: model,
            contextMenuController: contextMenuController,
            onClose: { [weak self] ocId in
                guard let self else {
                    return
                }

                guard let ocId else {
                    forcedClosingOcId = nil
                    dismiss(animated: false)
                    return
                }

                forcedClosingOcId = ocId
                dismiss(animated: true)
            }
        )

        let navigationController = UINavigationController(
            rootViewController: hostingController
        )

        configureNavigationController(navigationController)

        navigationController.view.backgroundColor = .ncViewerBackground(.system)
        navigationController.view.frame = window.bounds
        navigationController.view.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]

        self.navigationController = navigationController
        self.viewerContainerView = navigationController.view

        installDismissPanGesture(on: navigationController.view)

        if let viewerTransitionSource {
            navigationController.view.alpha = 0
            window.addSubview(navigationController.view)

            animateOpening(
                viewerTransitionSource: viewerTransitionSource,
                in: window,
                viewerView: navigationController.view
            )
        } else {
            navigationController.view.alpha = 1
            window.addSubview(navigationController.view)
        }
    }

    /// Dismisses the current media viewer overlay.
    ///
    /// - Parameter animated: Whether dismissal should be animated.
    func dismiss(animated: Bool = true) {
        guard !isDismissing else {
            return
        }

        guard let viewerContainerView else {
            cleanup()
            return
        }

        isDismissing = true
        removeDismissPanGesture()

        guard animated else {
            viewerContainerView.removeFromSuperview()
            cleanup()
            return
        }

        if let closingTransitionSource = currentClosingTransitionSource(),
           let window = viewerContainerView.window {
            let closingImage = currentClosingImage()
                ?? closingTransitionSource.image

            animateClosing(
                viewerTransitionSource: closingTransitionSource,
                closingImage: closingImage,
                in: window,
                viewerView: viewerContainerView
            )
            return
        }

        UIView.animate(
            withDuration: closingAnimationDuration,
            delay: 0,
            options: [.curveEaseInOut]
        ) {
            viewerContainerView.alpha = 0
        } completion: { [weak self] _ in
            viewerContainerView.removeFromSuperview()
            self?.cleanup()
        }
    }

    // MARK: - Navigation Appearance

    /// Configures the dedicated navigation controller used by the viewer.
    ///
    /// The navigation bar is transparent and overlays the SwiftUI content, allowing
    /// media pages to remain fullscreen while still using standard UIKit navigation
    /// items.
    ///
    /// - Parameter navigationController: Viewer navigation controller.
    private func configureNavigationController(_ navigationController: UINavigationController) {
        navigationController.setNavigationBarHidden(false, animated: false)
        navigationController.navigationBar.isTranslucent = true
        navigationController.navigationBar.tintColor = .label
        navigationController.navigationBar.prefersLargeTitles = false

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]

        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.compactAppearance = appearance
        navigationController.navigationBar.compactScrollEdgeAppearance = appearance
    }

    // MARK: - Dismiss Pan Gesture

    /// Installs the swipe-down dismiss gesture on the fullscreen viewer container.
    ///
    /// The gesture is attached at presenter level, above the paging implementation,
    /// so it does not require custom logic inside collection view cells or SwiftUI pages.
    ///
    /// - Parameter view: Viewer container view.
    private func installDismissPanGesture(on view: UIView) {
        removeDismissPanGesture()

        let gesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handleDismissPanGesture(_:))
        )

        gesture.cancelsTouchesInView = false
        gesture.delegate = self

        view.addGestureRecognizer(gesture)

        dismissPanGesture = gesture
        dismissPanGestureView = view
    }

    /// Removes the swipe-down dismiss gesture from the viewer container.
    private func removeDismissPanGesture() {
        if let dismissPanGesture,
           let dismissPanGestureView {
            dismissPanGestureView.removeGestureRecognizer(dismissPanGesture)
        }

        dismissPanGesture = nil
        dismissPanGestureView = nil
        isTrackingDismissPan = false
    }

    /// Handles swipe-down dismissal from the fullscreen viewer container.
    ///
    /// The gesture dismisses when downward movement clearly wins over horizontal paging,
    /// using permissive thresholds similar to a photo viewer drag-to-close interaction.
    @objc
    private func handleDismissPanGesture(_ gesture: UIPanGestureRecognizer) {
        guard !isDismissing,
              let view = gesture.view else {
            return
        }

        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        let verticalDistance = translation.y
        let horizontalDistance = abs(translation.x)
        let downwardVelocity = velocity.y

        switch gesture.state {
        case .began:
            isTrackingDismissPan = false

        case .changed:
            guard verticalDistance > 0 else {
                return
            }

            let isMostlyVertical = verticalDistance > horizontalDistance * 1.10

            guard isMostlyVertical else {
                return
            }

            isTrackingDismissPan = true

        case .ended:
            defer {
                isTrackingDismissPan = false
            }

            guard isTrackingDismissPan else {
                return
            }

            let shouldDismiss = verticalDistance > 70 || downwardVelocity > 550

            guard shouldDismiss else {
                return
            }

            dismiss(animated: true)

        case .cancelled,
             .failed:
            isTrackingDismissPan = false

        default:
            break
        }
    }

    // MARK: - Opening Animation

    /// Animates the source thumbnail into the fullscreen viewer.
    ///
    /// The real viewer is kept hidden until the temporary transition image reaches
    /// its destination frame. This prevents seeing both the viewer image and the
    /// transition image at the same time.
    ///
    /// - Parameters:
    ///   - viewerTransitionSource: Source thumbnail data.
    ///   - window: Window that contains the overlay transition views.
    ///   - viewerView: Real viewer container view to reveal at the end.
    private func animateOpening(
        viewerTransitionSource: NCViewerTransitionSource,
        in window: UIWindow,
        viewerView: UIView
    ) {
        let dimView = UIView(frame: window.bounds)
        dimView.backgroundColor = .ncViewerBackground(.system)
        dimView.alpha = 0
        dimView.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]

        let imageView = UIImageView(image: viewerTransitionSource.image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.frame = viewerTransitionSource.sourceFrame
        imageView.layer.cornerRadius = viewerTransitionSource.cornerRadius

        window.addSubview(dimView)
        window.addSubview(imageView)

        let destinationFrame = aspectFitFrame(
            imageSize: viewerTransitionSource.image.size,
            containerSize: window.bounds.size
        )

        viewerView.alpha = 0

        UIView.animate(
            withDuration: openingAnimationDuration,
            delay: 0,
            options: [.curveEaseInOut]
        ) {
            dimView.alpha = 1
            imageView.frame = destinationFrame
            imageView.layer.cornerRadius = 0
        } completion: { _ in
            viewerView.alpha = 1
            imageView.removeFromSuperview()
            dimView.removeFromSuperview()
        }
    }

    // MARK: - Closing Animation

    /// Animates the fullscreen viewer back into the current thumbnail frame.
    ///
    /// The real viewer is hidden immediately and replaced by a temporary transition
    /// image, avoiding double-image artifacts during the zoom-out animation.
    ///
    /// - Parameters:
    ///   - viewerTransitionSource: Current thumbnail data used as closing destination.
    ///   - closingImage: Image currently displayed by the viewer, used during the closing transition.
    ///   - window: Window that contains the overlay transition views.
    ///   - viewerView: Real viewer container view to dismiss.
    private func animateClosing(
        viewerTransitionSource: NCViewerTransitionSource,
        closingImage: UIImage,
        in window: UIWindow,
        viewerView: UIView
    ) {
        let startFrame = aspectFitFrame(
            imageSize: closingImage.size,
            containerSize: window.bounds.size
        )

        let imageView = UIImageView(image: closingImage)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.frame = startFrame
        imageView.layer.cornerRadius = 0

        window.addSubview(imageView)

        viewerView.alpha = 0

        UIView.animate(
            withDuration: closingAnimationDuration,
            delay: 0,
            options: [.curveEaseInOut]
        ) {
            imageView.frame = viewerTransitionSource.sourceFrame
            imageView.layer.cornerRadius = viewerTransitionSource.cornerRadius
        } completion: { [weak self] _ in
            imageView.removeFromSuperview()
            viewerView.removeFromSuperview()
            self?.cleanup()
        }
    }

    // MARK: - Closing Source

    /// Returns the transition source for the currently selected media item.
    ///
    /// The source controller knows how to map the current `ocId` to the visible
    /// thumbnail frame. If no current source can be resolved, the presenter closes
    /// without a thumbnail transition.
    ///
    /// - Returns: Current transition source if available.
    private func currentClosingTransitionSource() -> NCViewerTransitionSource? {
        let ocId = forcedClosingOcId ?? currentModel?.selectedOcId

        guard let ocId else {
            return nil
        }

        return closingTransitionSourceProvider?(ocId)
    }

    /// Returns the best currently displayed image for the closing transition.
    ///
    /// The full local image is preferred when available.
    /// If the full image is not available yet, the preview image is used.
    /// If no current image can be resolved, the caller should fall back to the
    /// transition source image.
    ///
    /// - Returns: Current image suitable for the closing transition.
    private func currentClosingImage() -> UIImage? {
        guard let page = currentModel?.selectedPageModel() else {
            return nil
        }

        switch page.state {
        case .image(let previewURL, let localURL, _, _):
            if let localURL,
               let image = UIImage(contentsOfFile: localURL.path) {
                return image
            }

            if let previewURL {
                return UIImage(contentsOfFile: previewURL.path)
            }

            return nil

        case .video(let previewURL):
            guard let previewURL else {
                return nil
            }

            return UIImage(contentsOfFile: previewURL.path)

        case .ready(let localURL, let previewURL):
            if let image = UIImage(contentsOfFile: localURL.path) {
                return image
            }

            if let previewURL {
                return UIImage(contentsOfFile: previewURL.path)
            }

            return nil

        case .downloading(let previewURL, _),
             .failed(let previewURL, _):
            guard let previewURL else {
                return nil
            }

            return UIImage(contentsOfFile: previewURL.path)

        case .deleted,
             .idle,
             .loadingMetadata,
             .metadataMissing,
             .checkingLocalFile:
            return nil
        }
    }

    // MARK: - Cleanup

    /// Clears retained presenter state after the viewer has been removed.
    private func cleanup() {
        NotificationCenter.default.post(
            name: .ncMediaViewerStopPlayback,
            object: nil
        )

        navigationController = nil
        viewerContainerView = nil
        currentViewerTransitionSource = nil
        currentModel = nil
        closingTransitionSourceProvider = nil
        forcedClosingOcId = nil
    }

    // MARK: - Helpers

    /// Returns the current active foreground key window.
    ///
    /// - Returns: Active foreground key window if available.
    private func activeWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    /// Computes the aspect-fit frame for an image inside the fullscreen container.
    ///
    /// - Parameters:
    ///   - imageSize: Source image size.
    ///   - containerSize: Window size.
    /// - Returns: Aspect-fit destination frame.
    private func aspectFitFrame(
        imageSize: CGSize,
        containerSize: CGSize
    ) -> CGRect {
        guard imageSize.width > 0,
              imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let ratio = min(widthRatio, heightRatio)

        let fittedSize = CGSize(
            width: imageSize.width * ratio,
            height: imageSize.height * ratio
        )

        return CGRect(
            x: (containerSize.width - fittedSize.width) * 0.5,
            y: (containerSize.height - fittedSize.height) * 0.5,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}

// MARK: - UIGestureRecognizerDelegate

extension NCMediaViewerPresenter: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissPanGesture,
              let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
              let view = panGesture.view else {
            return true
        }

        let velocity = panGesture.velocity(in: view)

        guard velocity.y > 0 else {
            return false
        }

        return abs(velocity.y) > abs(velocity.x) * 1.10
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === dismissPanGesture
    }
}
