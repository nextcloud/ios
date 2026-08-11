// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

// MARK: - AVPlayer Presenter
@MainActor
enum NCVideoAVPlayerPresenter {
    // MARK: - State
    private static weak var currentViewController: NCVideoAVPlayerViewController?
    private static var currentURL: URL?
    private static var isPresenting = false

    // MARK: - Public API
    // Presents or updates the single AVPlayer fullscreen controller.
    static func present(
        metadata: tableMetadata,
        preparedPlayback: NCVideoAVPreparedPlayback,
        userAgent: String?,
        shouldAutoPlayOnStart: Bool = true,
        playbackStartReason: NCVideoPlaybackPresentationContext.StartReason = .userInitiated,
        isChromeHidden: Bool = false,
        contextMenuController: NCMainTabBarController?,
        playbackOptions: NCMediaPlaybackOptions,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        onPlaybackEnded: (() -> Void)? = nil,
        onClose: ((_ ocId: String?) -> Void)? = nil,
        onPlaybackError: (() -> Void)? = nil
    ) -> Bool {
        let url = preparedPlayback.url
        if currentURL == url,
           let currentViewController {
            currentViewController.update(
                metadata: metadata,
                preparedPlayback: preparedPlayback,
                userAgent: userAgent,
                shouldAutoPlayOnStart: shouldAutoPlayOnStart,
                playbackStartReason: playbackStartReason,
                isChromeHidden: isChromeHidden,
                contextMenuController: contextMenuController,
                playbackOptions: playbackOptions
            )
            currentViewController.canGoPrevious = canGoPrevious
            currentViewController.canGoNext = canGoNext
            currentViewController.onPrevious = onPrevious
            currentViewController.onNext = onNext
            currentViewController.onPlaybackEnded = onPlaybackEnded
            currentViewController.onClose = onClose
            currentViewController.onPlaybackError = onPlaybackError

            return true
        }

        if isPresenting {
            return false
        }

        if let currentViewController {
            currentViewController.update(
                metadata: metadata,
                preparedPlayback: preparedPlayback,
                userAgent: userAgent,
                shouldAutoPlayOnStart: shouldAutoPlayOnStart,
                playbackStartReason: playbackStartReason,
                isChromeHidden: isChromeHidden,
                contextMenuController: contextMenuController,
                playbackOptions: playbackOptions
            )
            currentViewController.canGoPrevious = canGoPrevious
            currentViewController.canGoNext = canGoNext
            currentViewController.onPrevious = onPrevious
            currentViewController.onNext = onNext
            currentViewController.onPlaybackEnded = onPlaybackEnded
            currentViewController.onClose = onClose
            currentViewController.onPlaybackError = onPlaybackError

            currentURL = url
            return true
        }

        guard let presenter = topViewController() else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "VIDEO AVPlayer presenter failed: no top view controller",
                consoleOnly: true
            )
            return false
        }

        if presenter is NCVideoAVPlayerViewController {
            return false
        }

        if let navigationController = presenter as? UINavigationController,
           navigationController.topViewController is NCVideoAVPlayerViewController {
            return false
        }

        isPresenting = true

        let viewController = NCVideoAVPlayerViewController(
            metadata: metadata,
            preparedPlayback: preparedPlayback,
            userAgent: userAgent,
            shouldAutoPlayOnStart: shouldAutoPlayOnStart,
            playbackStartReason: playbackStartReason,
            isChromeHidden: isChromeHidden,
            contextMenuController: contextMenuController,
            playbackOptions: playbackOptions
        )
        viewController.canGoPrevious = canGoPrevious
        viewController.canGoNext = canGoNext
        viewController.onPrevious = onPrevious
        viewController.onNext = onNext
        viewController.onPlaybackEnded = onPlaybackEnded
        viewController.onClose = onClose
        viewController.onPlaybackError = onPlaybackError

        currentViewController = viewController
        currentURL = url

        let navigationController = UINavigationController(
            rootViewController: viewController
        )

        navigationController.modalPresentationStyle = .fullScreen
        navigationController.navigationBar.prefersLargeTitles = false
        navigationController.navigationBar.barStyle = .black
        navigationController.navigationBar.tintColor = .white
        navigationController.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]

        if !playbackStartReason.shouldShowControlsOnStart {
            navigationController.setNavigationBarHidden(
                true,
                animated: false
            )
        }

        presenter.present(
            navigationController,
            animated: false
        ) {
            isPresenting = false
        }

        return true
    }

    static func clearCurrent(
        _ viewController: NCVideoAVPlayerViewController
    ) {
        guard currentViewController === viewController else {
            return
        }

        currentViewController = nil
        currentURL = nil
        isPresenting = false
    }

    static func dismissCurrent(completion: (() -> Void)? = nil) {
        guard let currentViewController else {
            completion?()
            return
        }

        let controllerToDismiss =
            currentViewController.navigationController ?? currentViewController

        controllerToDismiss.dismiss(animated: false) {
            clearCurrent(currentViewController)
            completion?()
        }
    }

    static func dismiss(completion: (() -> Void)? = nil) {
        dismissCurrent(completion: completion)
    }

    // MARK: - Private
    private static func topViewController() -> UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        let rootViewController = windowScene?
            .windows
            .first { $0.isKeyWindow }?
            .rootViewController

        return visibleViewController(from: rootViewController)
    }

    private static func visibleViewController(
        from viewController: UIViewController?
    ) -> UIViewController? {
        if let navigationController = viewController as? UINavigationController {
            return visibleViewController(
                from: navigationController.visibleViewController
            )
        }

        if let tabBarController = viewController as? UITabBarController {
            return visibleViewController(
                from: tabBarController.selectedViewController
            )
        }

        if let presentedViewController = viewController?.presentedViewController {
            return visibleViewController(
                from: presentedViewController
            )
        }

        return viewController
    }
}
