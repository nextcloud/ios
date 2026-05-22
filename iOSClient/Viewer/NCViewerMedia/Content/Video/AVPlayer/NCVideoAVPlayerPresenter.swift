// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

// MARK: - AVPlayer Presenter

/// Presents one UIKit-only AVPlayer viewer outside the SwiftUI paging hierarchy.
///
/// This presenter guarantees that only one AVPlayer viewer is presented at a time.
@MainActor
enum NCVideoAVPlayerPresenter {

    // MARK: - State

    private static weak var currentViewController: NCVideoAVPlayerViewController?
    private static var currentURL: URL?
    private static var isPresenting = false

    // MARK: - Public API

    /// Presents the AVPlayer viewer from the current top view controller.
    ///
    /// Repeated calls with the same URL are ignored to avoid multiple AVPlayer instances
    /// during SwiftUI recomposition or device rotation.
    ///
    /// - Parameters:
    ///   - metadata: Video metadata used for logging and player title.
    ///   - url: Local or remote playable URL.
    ///   - previewURL: Optional local preview image URL shown until the first video frame is ready.
    ///   - userAgent: Optional HTTP User-Agent for remote playback.
    ///   - contextMenuController: Main tab bar controller used by context menu actions.
    ///   - canGoPrevious: Whether the previous-page gesture/action is currently available.
    ///   - canGoNext: Whether the next-page gesture/action is currently available.
    ///   - onPrevious: Callback invoked when AVPlayer receives a previous-page action.
    ///   - onNext: Callback invoked when AVPlayer receives a next-page action.
    ///   - onClose: Callback invoked with the current media ocId when AVPlayer closes the fullscreen media viewer.
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
            currentViewController.canGoPrevious = canGoPrevious
            currentViewController.canGoNext = canGoNext
            currentViewController.onPrevious = onPrevious
            currentViewController.onNext = onNext
            currentViewController.onClose = onClose

            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO AVPlayer presenter ignored duplicate URL \(url.absoluteString)",
                consoleOnly: true
            )
            return
        }

        if isPresenting {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO AVPlayer presenter ignored while presentation is in progress",
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
            url: url,
            previewURL: previewURL,
            userAgent: userAgent,
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

    /// Clears the current AVPlayer presentation state.
    ///
    /// Call this from `NCVideoAVPlayerViewController` when it closes.
    ///
    /// - Parameter viewController: AVPlayer view controller being closed.
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

    /// Dismisses the current AVPlayer viewer if one is currently presented.
    static func dismissCurrent() {
        guard let currentViewController else {
            return
        }

        currentViewController.dismiss(animated: false) {
            clearCurrent(currentViewController)
        }
    }

    /// Dismisses the current AVPlayer viewer if one is currently presented.
    ///
    /// This short alias is used by video-page navigation callbacks before moving
    /// the SwiftUI media viewer to the previous or next page.
    static func dismiss() {
        dismissCurrent()
    }

    // MARK: - Private

    /// Resolves the top-most visible view controller.
    ///
    /// - Returns: Top-most visible view controller, if available.
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
