// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import MessageUI
import SVGKit
import NextcloudKit

/// A context menu for user profile actions (email, talk, etc.)
/// See ``NCShare``, ``NCActivity``, ``NCActivityTableViewCell`` for usage details.
class NCContextMenuProfile: NSObject {
    let userId: String
    let session: NCSession.Session
    let viewController: UIViewController
    let utility = NCUtility()

    init(userId: String, session: NCSession.Session, viewController: UIViewController) {
        self.userId = userId
        self.session = session
        self.viewController = viewController
    }

    // MARK: - Public Menu Builder

    /// Returns a UIMenu that loads the hovercard data asynchronously using UIDeferredMenuElement
    func viewMenu() -> UIMenu {
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()

        guard capabilities.serverVersionMajor >= NCGlobal.shared.nextcloudVersion23 else {
            return UIMenu()
        }

        let deferredElement = UIDeferredMenuElement.uncached { completion in
            Task {
                let menuElements = await self.loadProfileMenu()
                await MainActor.run {
                    completion(menuElements)
                }
            }
        }

        return UIMenu(title: "", children: [deferredElement])
    }

    // MARK: - Private Async Loading

    private func loadProfileMenu() async -> [UIMenuElement] {
        let results = await NextcloudKit.shared.getHovercardAsync(
            for: userId,
            account: session.account
        ) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                    account: self.session.account,
                    path: self.userId,
                    name: "getHovercard"
                )
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        guard let card = results.result, results.account == session.account else {
            return []
        }

        return buildProfileMenu(from: card)
    }

    // MARK: - Builder Methods

    private func buildProfileMenu(from card: NKHovercard) -> [UIMenuElement] {
        var menuElements: [UIMenuElement] = []

        // Header action (display name with avatar)
        let headerAction = makeHeaderAction(card: card)
        menuElements.append(headerAction)

        // Action items from hovercard
        let actionsMenu = buildActionsMenu(from: card.actions)
        if !actionsMenu.isEmpty {
            let actionsSection = UIMenu(title: "", options: .displayInline, children: actionsMenu)
            menuElements.append(actionsSection)
        }

        return menuElements
    }

    private func buildActionsMenu(from actions: [NKHovercard.Action]) -> [UIMenuElement] {
        return actions.map { makeActionItem(from: $0) }
    }

    // MARK: - Action Makers

    private func makeHeaderAction(card: NKHovercard) -> UIAction {
        let avatarImage = utility.loadUserImage(
            for: userId,
            displayName: card.displayName,
            urlBase: session.urlBase
        )

        return UIAction(
            title: card.displayName,
            image: avatarImage,
            attributes: .disabled
        ) { _ in }
    }

    private func makeActionItem(from action: NKHovercard.Action) -> UIAction {
        var image = utility.loadImage(named: "person", colors: [NCBrandColor.shared.iconImageColor])

        if let url = URL(string: action.icon),
           let svgSource = SVGKSourceURL.source(from: url),
           let svg = SVGKImage(source: svgSource) {
            image = svg.uiImage.withTintColor(
                NCBrandColor.shared.iconImageColor,
                renderingMode: .alwaysOriginal
            )
        }

        return UIAction(
            title: action.title,
            image: image
        ) { _ in
            self.handleProfileAction(action)
        }
    }

    // MARK: - Action Handlers

    private func handleProfileAction(_ action: NKHovercard.Action) {
        switch action.appId {
        case "email":
            handleEmailAction(action)

        case "spreed":
            handleSpreedAction(action)

        default:
            handleDefaultAction(action)
        }
    }

    private func handleEmailAction(_ action: NKHovercard.Action) {
        guard let url = action.hyperlinkUrl,
              url.scheme == "mailto",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            showError("_cannot_send_mail_error_")
            return
        }

        viewController.sendEmail(to: components.path)
    }

    private func handleSpreedAction(_ action: NKHovercard.Action) {
        guard let talkUrl = URL(string: "nextcloudtalk://open-conversation?server=\(session.urlBase)&user=\(session.userId)&withUser=\(userId)"),
              UIApplication.shared.canOpenURL(talkUrl) else {
            handleDefaultAction(action)
            return
        }

        UIApplication.shared.open(talkUrl)
    }

    private func handleDefaultAction(_ action: NKHovercard.Action) {
        guard let url = action.hyperlinkUrl,
              UIApplication.shared.canOpenURL(url) else {
            showError("_open_url_error_")
            return
        }

        UIApplication.shared.open(url, options: [:])
    }

    private func showError(_ errorKey: String) {
        let error = NKError(
            errorCode: NCGlobal.shared.errorInternalError,
            errorDescription: errorKey
        )
        NCContentPresenter().showError(error: error)
    }
}
