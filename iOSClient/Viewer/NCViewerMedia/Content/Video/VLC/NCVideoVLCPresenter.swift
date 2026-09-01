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
    private static var pendingDismissCompletions: [() -> Void]?

    // MARK: - Public API
    // Presents or updates the single VLC fullscreen controller.
    static func present(
        metadata: tableMetadata,
        preparedPlayback: NCVideoVLCPreparedPlayback,
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
        onPlaybackEnded: NCMediaPlaybackAdvanceRequest? = nil,
        onClose: ((_ ocId: String?) -> Void)? = nil,
        onPlaybackError: (() -> Void)? = nil
    ) -> Bool {
        let url = preparedPlayback.url

        guard pendingDismissCompletions == nil else {
            logPresentationRejected("dismissal in progress")
            return false
        }

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
            currentViewController.onPrevious = onPrevious
            currentViewController.onNext = onNext
            currentViewController.onPlaybackEnded = onPlaybackEnded
            currentViewController.onClose = onClose
            currentViewController.onPlaybackError = onPlaybackError
            currentViewController.canGoPrevious = canGoPrevious
            currentViewController.canGoNext = canGoNext
            return true
        }

        if isPresenting {
            logPresentationRejected("presentation in progress")
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
            currentViewController.onPrevious = onPrevious
            currentViewController.onNext = onNext
            currentViewController.onPlaybackEnded = onPlaybackEnded
            currentViewController.onClose = onClose
            currentViewController.onPlaybackError = onPlaybackError
            currentViewController.canGoPrevious = canGoPrevious
            currentViewController.canGoNext = canGoNext

            currentURL = url
            return true
        }

        guard let presenter = topViewController() else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "VIDEO VLC presenter failed: no top view controller",
                consoleOnly: true
            )
            return false
        }

        if presenter is NCVideoVLCViewController {
            logPresentationRejected("VLC view controller already visible")
            return false
        }

        if presenter is UINavigationController,
           (presenter as? UINavigationController)?.topViewController is NCVideoVLCViewController {
            logPresentationRejected("VLC navigation controller already visible")
            return false
        }

        isPresenting = true

        let viewController = NCVideoVLCViewController(
            metadata: metadata,
            preparedPlayback: preparedPlayback,
            userAgent: userAgent,
            shouldAutoPlayOnStart: shouldAutoPlayOnStart,
            playbackStartReason: playbackStartReason,
            isChromeHidden: isChromeHidden,
            contextMenuController: contextMenuController,
            playbackOptions: playbackOptions
        )
        viewController.onPrevious = onPrevious
        viewController.onNext = onNext
        viewController.onPlaybackEnded = onPlaybackEnded
        viewController.onClose = onClose
        viewController.onPlaybackError = onPlaybackError
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

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .start,
            message: "VIDEO VLC presentation accepted",
            consoleOnly: false
        )

        return true
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

    static func dismissCurrent(completion: (() -> Void)? = nil) {
        if pendingDismissCompletions != nil {
            if let completion {
                pendingDismissCompletions?.append(completion)
            }
            return
        }

        pendingDismissCompletions = completion.map { [$0] } ?? []

        guard let viewController = currentViewController else {
            finishDismissal(for: nil)
            return
        }

        viewController.stopForDismissal()

        let controllerToDismiss =
            viewController.navigationController ?? viewController

        // Page navigation must not depend on MobileVLCKit's asynchronous
        // `.stopped` callback. Dismissal owns the UI transition while the
        // controller continues its internal player cleanup independently.
        controllerToDismiss.dismiss(animated: false) {
            finishDismissal(for: viewController)
        }
    }

    static func dismiss(completion: (() -> Void)? = nil) {
        dismissCurrent(completion: completion)
    }

    private static func finishDismissal(
        for viewController: NCVideoVLCViewController?
    ) {
        if let viewController {
            clearCurrent(viewController)
        } else {
            currentViewController = nil
            currentURL = nil
            isPresenting = false
        }

        let completions = pendingDismissCompletions ?? []
        pendingDismissCompletions = nil
        completions.forEach { $0() }
    }

    // MARK: - Private
    private static func logPresentationRejected(_ reason: String) {
        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .info,
            message: "VIDEO VLC presentation rejected: \(reason)",
            consoleOnly: false
        )
    }

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
