// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

// MARK: - VLC Presenter

/// Presents one UIKit-only VLC fallback viewer outside the SwiftUI paging hierarchy.
///
/// This presenter guarantees that only one VLC viewer is presented at a time.
@MainActor
enum NCVideoVLCPresenter {

    // MARK: - State

    private static weak var currentViewController: NCVideoVLCViewController?
    private static var currentURL: URL?
    private static var isPresenting = false

    // MARK: - Public API

    /// Presents the VLC fallback viewer from the current top view controller.
    ///
    /// Repeated calls with the same URL are ignored to avoid multiple VLC instances
    /// during SwiftUI recomposition or device rotation.
    ///
    /// - Parameters:
    ///   - metadata: Video metadata used for logging.
    ///   - url: Local or remote playable URL.
    ///   - previewURL: Optional local preview image URL shown until VLC starts rendering.
    ///   - userAgent: Optional HTTP User-Agent for remote playback.
    ///   - contextMenuController: Main tab bar controller used by context menu actions.
    ///   - canGoPrevious: Whether VLC can navigate to the previous media item.
    ///   - canGoNext: Whether VLC can navigate to the next media item.
    ///   - onPrevious: Callback invoked when VLC receives a right swipe.
    ///   - onNext: Callback invoked when VLC receives a left swipe.
    ///   - onClose: Callback invoked with the current media ocId when VLC closes the fullscreen media viewer.
    static func present(
        metadata: tableMetadata,
        url: URL,
        previewURL: URL?,
        userAgent: String?,
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
                previewURL: previewURL,
                userAgent: userAgent,
                contextMenuController: contextMenuController
            )
            currentViewController.onPrevious = onPrevious
            currentViewController.onNext = onNext
            currentViewController.onClose = onClose
            currentViewController.canGoPrevious = canGoPrevious
            currentViewController.canGoNext = canGoNext
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO VLC presenter ignored duplicate URL \(url.absoluteString)",
                consoleOnly: true
            )
            return
        }

        if isPresenting {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO VLC presenter ignored while presentation is in progress",
                consoleOnly: true
            )
            return
        }

        if let currentViewController {
            currentViewController.update(
                metadata: metadata,
                url: url,
                previewURL: previewURL,
                userAgent: userAgent,
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
            previewURL: previewURL,
            userAgent: userAgent,
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
        navigationController.modalTransitionStyle = .crossDissolve
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

    /// Clears the current VLC presentation state.
    ///
    /// Call this from `NCVideoVLCViewController` when it closes.
    ///
    /// - Parameter viewController: VLC view controller being closed.
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

    /// Dismisses the current VLC viewer if one is currently presented.
    static func dismissCurrent() {
        guard let currentViewController else {
            return
        }

        currentViewController.dismiss(animated: false) {
            clearCurrent(currentViewController)
        }
    }

    /// Dismisses the current VLC viewer if one is currently presented.
    ///
    /// This short alias is used by video-page navigation callbacks before moving
    /// the SwiftUI media viewer to the previous or next page.
    static func dismiss() {
        dismissCurrent()
    }

    // MARK: - Private

    /// Resolves the top-most visible view controller.
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

    /// Recursively resolves the visible view controller.
    ///
    /// - Parameter viewController: Root or intermediate view controller.
    /// - Returns: Top-most visible view controller.
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
