// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit
import UIKit

/// Media viewer flow legend.
///
/// This file is the UIKit entry point for the media viewer flow.
///
/// Source order and responsibilities:
///
/// 1. `NCMediaViewerPresenter`
///    UIKit entry point. Creates the initial model, builds the hosting controller,
///    presents the SwiftUI viewer, and manages opening/closing transitions.
///
/// 2. `NCMediaViewerHostingController`
///    UIKit container for the SwiftUI viewer. Owns the navigation bar, toolbar
///    actions, detail presentation, and close/info buttons.
///
/// 3. `NCMediaViewerView`
///    SwiftUI root view. Hosts the paging view and observes the viewer model.
///
/// 4. `NCMediaViewerModel`
///    Central state coordinator. Owns the selected index, visible page window,
///    page states, metadata cache, prefetching, autoplay requests, and routes
///    media into image, audio, video, or generic states.
///
/// 5. `NCNextcloudMediaViewerLoader`
///    Loader layer. Resolves metadata, preview URLs, local media URLs, full media
///    downloads, and Live Photo companion media.
///
/// 6. `NCMediaViewerPagingView`
///    UIKit-backed horizontal pager hosted from SwiftUI. Owns the collection view,
///    paging coordinator, visible cells, selected index updates, page navigation,
///    and chrome-aware page background updates.
///
/// 7. `NCMediaViewerPageView`
///    Per-page SwiftUI renderer. Switches on `NCMediaViewerPageState`, applies
///    the chrome-aware background style, and routes each page to the correct
///    content view.
///
/// 8. Appearance flow:
///    `NCMediaViewerAppearance` centralizes viewer background resolution.
///    The normal viewer background follows the system appearance. When chrome is
///    hidden, the viewer enters cinema mode and uses a black background.
///
/// 9. Image flow:
///    `NCMediaViewerPageView`
///    -> `NCImageViewerContentView`
///    -> `NCImageZoomView`
///    -> `NCLivePhotoViewerContentView` when Live Photo data is available.
///
/// 10. Audio flow:
///     `NCMediaViewerPageView`
///     -> `NCAudioViewerContentView`.
///     Audio playback stays inside SwiftUI and uses a local media URL plus an
///     optional preview image as artwork.
///
/// 11. Video SwiftUI flow:
///     `NCMediaViewerPageView`
///     -> `NCVideoViewerContentView`
///     -> `NCVideoPlaybackCoverView`
///     -> `NCVideoURLResolver`
///     -> `NCVideoPlaybackController`.
///     The video content view is the SwiftUI trigger/bridge for fullscreen
///     playback. It displays the preview cover, resolves the playback URL, and
///     asks the playback controller to choose the engine.
///
/// 12. `NCVideoPlaybackController`
///     Chooses the playback engine. It tries AVFoundation when possible and falls
///     back to VLC for unsupported or legacy formats.
///
/// 13. AVPlayer flow:
///     `NCVideoPlaybackController`
///     -> `NCVideoViewerContentView+AVPlayer`
///     -> `NCVideoAVPlayerPresenter`
///     -> `NCVideoAVPlayerViewController`
///     -> `NCVideoControlsView` / `NCVideoAVPlayerViewControls`.
///     AVPlayer uses the shared controls view and updates its background according
///     to chrome visibility: system appearance when controls are visible, black
///     cinema mode when controls are hidden.
///
/// 14. VLC flow:
///     `NCVideoPlaybackController`
///     -> `NCVideoViewerContentView+VLC`
///     -> `NCVideoVLCPresenter`
///     -> `NCVideoVLCViewController`
///     -> `NCVideoControlsView` / `NCVideoVLCViewControls`.
///     VLC uses the same presentation structure as AVPlayer, while the VLC renderer
///     may still draw its own black surface during playback initialization.
///
/// 15. Detail flow:
///     `NCMediaViewerHostingController`
///     -> `NCMediaViewerDetailView`.
///     Displays file information, camera/lens metadata, EXIF values, and location.
///
/// High-level rule:
/// `NCMediaViewerPresenter` starts and closes the viewer, but it does not resolve,
/// download, classify, or play media. Those responsibilities belong to the model,
/// loader, page view, and dedicated media content flows.

@MainActor
final class NCMediaViewerPresenter: NSObject {
    static let shared = NCMediaViewerPresenter()

    private var navigationController: UINavigationController?
    private weak var viewerContainerView: UIView?
    private var currentViewerTransitionSource: NCMediaViewerTransitionSource?
    private weak var currentModel: NCMediaViewerModel?

    private var closingTransitionSourceProvider: ((_ ocId: String) -> NCMediaViewerTransitionSource?)?
    private var forcedClosingOcId: String?

    private let openingAnimationDuration: TimeInterval = 0.28
    private let closingAnimationDuration: TimeInterval = 0.24

    private var dismissPanGesture: UIPanGestureRecognizer?
    private weak var dismissPanGestureView: UIView?
    private var isTrackingDismissPan = false
    private var isDismissing = false
    private var isCurrentImageZoomed = false

    private override init() {
        super.init()
    }

    // MARK: - Presentation

    /// Shows the media viewer above the current window.
    func show(
        model: NCMediaViewerModel,
        viewerTransitionSource: NCMediaViewerTransitionSource?,
        from sourceView: UIView? = nil,
        contextMenuController: NCMainTabBarController? = nil,
        closingTransitionSourceProvider: ((_ ocId: String) -> NCMediaViewerTransitionSource?)? = nil
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
        isCurrentImageZoomed = false

        let hostingController = NCMediaViewerHostingController(
            model: model,
            contextMenuController: contextMenuController,
            onZoomChanged: { [weak self] isZoomed in
                self?.isCurrentImageZoomed = isZoomed
            },
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
    func dismiss(animated: Bool = true) {
        guard !isDismissing else {
            return
        }

        guard let viewerContainerView else {
            cleanup()
            return
        }

        isDismissing = true
        currentModel?.cancelAllDownloads()
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

    /// Configures the transparent navigation bar used by the viewer.
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

    /// Installs the swipe-down gesture used to close the viewer.
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

    /// Handles swipe-down dismissal when vertical movement wins over paging.
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
    private func animateOpening(
        viewerTransitionSource: NCMediaViewerTransitionSource,
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
    private func animateClosing(
        viewerTransitionSource: NCMediaViewerTransitionSource,
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

    /// Returns the transition source for the currently selected item.
    private func currentClosingTransitionSource() -> NCMediaViewerTransitionSource? {
        let ocId = forcedClosingOcId ?? currentModel?.selectedOcId

        guard let ocId else {
            return nil
        }

        return closingTransitionSourceProvider?(ocId)
    }

    /// Returns the best available image for the closing transition.
    private func currentClosingImage() -> UIImage? {
        guard let page = currentModel?.selectedPageModel() else {
            return nil
        }

        switch page.state {
        case .image(let previewURL, let localURL, _, _):
            return imageFromURL(localURL) ?? imageFromURL(previewURL)

        case .audio(_, let previewURL):
            return imageFromURL(previewURL)

        case .video:
            return nil

        case .ready(let localURL, let previewURL):
            return imageFromURL(localURL) ?? imageFromURL(previewURL)

        case .downloading(let previewURL, _),
             .failed(let previewURL, _):
            guard page.metadata?.classFile != NKTypeClassFile.audio.rawValue,
                  page.metadata?.classFile != NKTypeClassFile.video.rawValue else {
                return nil
            }

            return imageFromURL(previewURL)

        case .deleted,
             .idle,
             .loadingMetadata,
             .metadataMissing,
             .checkingLocalFile:
            return nil
        }
    }

    private func imageFromURL(_ url: URL?) -> UIImage? {
        guard let url else {
            return nil
        }

        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - Cleanup

    /// Clears retained presenter state after the viewer has been removed.
    private func cleanup() {
        // Stop any remaining media playback before releasing the viewer hierarchy.
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
        isCurrentImageZoomed = false
    }

    // MARK: - Helpers

    /// Returns the active foreground key window.
    private func activeWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    /// Computes the aspect-fit frame for an image inside the container.
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
        guard !isCurrentImageZoomed else {
            return false
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
