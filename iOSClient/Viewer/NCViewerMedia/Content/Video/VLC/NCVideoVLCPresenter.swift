// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

// MARK: - VLC Presenter
@MainActor
enum NCVideoVLCPresenter {

    // MARK: - State
    private static weak var currentViewController: NCVideoVLCViewController?
    private static var currentURL: URL?
    private static var isPresenting = false

    // MARK: - Public API
    // Presents or updates the single VLC fullscreen controller.
    static func present(
        metadata: tableMetadata,
        url: URL,
        userAgent: String?,
        shouldAutoPlay: Bool = true,
        contextMenuController: NCMainTabBarController?,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        onClose: ((_ ocId: String?) -> Void)? = nil
    ) {
        if currentURL == url,
           let currentViewController {
            currentViewController.update(
                metadata: metadata,
                url: url,
                userAgent: userAgent,
                shouldAutoPlay: shouldAutoPlay,
                contextMenuController: contextMenuController
            )
            currentViewController.onPrevious = onPrevious
            currentViewController.onNext = onNext
            currentViewController.onClose = onClose
            currentViewController.canGoPrevious = canGoPrevious
            currentViewController.canGoNext = canGoNext
            return
        }

        if isPresenting {
            return
        }

        if let currentViewController {
            currentViewController.update(
                metadata: metadata,
                url: url,
                userAgent: userAgent,
                shouldAutoPlay: shouldAutoPlay,
                contextMenuController: contextMenuController
            )
            currentViewController.onPrevious = onPrevious
            currentViewController.onNext = onNext
            currentViewController.onClose = onClose
            currentViewController.canGoPrevious = canGoPrevious
            currentViewController.canGoNext = canGoNext

            currentURL = url
            return
        }

        guard let presenter = topViewController() else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "VIDEO VLC presenter failed: no top view controller",
                consoleOnly: true
            )
            return
        }

        if presenter is NCVideoVLCViewController {
            return
        }

        if presenter is UINavigationController,
           (presenter as? UINavigationController)?.topViewController is NCVideoVLCViewController {
            return
        }

        isPresenting = true

        let viewController = NCVideoVLCViewController(
            metadata: metadata,
            url: url,
            userAgent: userAgent,
            shouldAutoPlay: shouldAutoPlay,
            contextMenuController: contextMenuController
        )
        viewController.onPrevious = onPrevious
        viewController.onNext = onNext
        viewController.onClose = onClose
        viewController.canGoPrevious = canGoPrevious
        viewController.canGoNext = canGoNext

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
        _ viewController: NCVideoVLCViewController
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
