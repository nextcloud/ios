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
        isChromeHidden: Bool = false,
        contextMenuController: NCMainTabBarController?,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        onClose: ((_ ocId: String?) -> Void)? = nil
    ) {
        let url = preparedPlayback.url
        if currentURL == url,
           let currentViewController {
            currentViewController.update(
                metadata: metadata,
                preparedPlayback: preparedPlayback,
                userAgent: userAgent,
                shouldAutoPlayOnStart: shouldAutoPlayOnStart,
                isChromeHidden: isChromeHidden,
                contextMenuController: contextMenuController
            )
            currentViewController.canGoPrevious = canGoPrevious
            currentViewController.canGoNext = canGoNext
            currentViewController.onPrevious = onPrevious
            currentViewController.onNext = onNext
            currentViewController.onClose = onClose

            return
        }

        if isPresenting {
            return
        }

        if let currentViewController {
            currentViewController.update(
                metadata: metadata,
                preparedPlayback: preparedPlayback,
                userAgent: userAgent,
                shouldAutoPlayOnStart: shouldAutoPlayOnStart,
                isChromeHidden: isChromeHidden,
                contextMenuController: contextMenuController
            )
            currentViewController.canGoPrevious = canGoPrevious
            currentViewController.canGoNext = canGoNext
            currentViewController.onPrevious = onPrevious
            currentViewController.onNext = onNext
            currentViewController.onClose = onClose

            currentURL = url
            return
        }

        guard let presenter = topViewController() else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "VIDEO AVPlayer presenter failed: no top view controller",
                consoleOnly: true
            )
            return
        }

        if presenter is NCVideoAVPlayerViewController {
            return
        }

        if let navigationController = presenter as? UINavigationController,
           navigationController.topViewController is NCVideoAVPlayerViewController {
            return
        }

        isPresenting = true

        let viewController = NCVideoAVPlayerViewController(
            metadata: metadata,
            preparedPlayback: preparedPlayback,
            userAgent: userAgent,
            shouldAutoPlayOnStart: shouldAutoPlayOnStart,
            isChromeHidden: isChromeHidden,
            contextMenuController: contextMenuController
        )
        viewController.canGoPrevious = canGoPrevious
        viewController.canGoNext = canGoNext
        viewController.onPrevious = onPrevious
        viewController.onNext = onNext
        viewController.onClose = onClose

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

        presenter.present(
            navigationController,
            animated: false
        ) {
            isPresenting = false
        }
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

    static func dismissCurrent() {
        guard let currentViewController else {
            return
        }

        currentViewController.dismiss(animated: false) {
            clearCurrent(currentViewController)
        }
    }

    static func dismiss() {
        dismissCurrent()
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
