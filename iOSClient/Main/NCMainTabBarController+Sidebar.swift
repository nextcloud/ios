// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

extension NCMainTabBarController {
    func presentSidebar() {
        guard presentedViewController == nil else { return }
        if sidebarHostingController != nil {
            NotificationCenter.default.post(name: NCSidebarView.closeRequested, object: self)
            return
        }

        let sidebarView = makeSidebarView()
        let hostingController = UIHostingController(rootView: sidebarView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.accessibilityViewIsModal = true
        sidebarHostingController = hostingController
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        // Cover the full screen with glass. NCSidebarView positions its controls
        // within the safe area and aligns them with the measured navigation buttons.
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        view.layoutIfNeeded()
    }

    /// Builds the overlay sidebar shared by all devices.
    func makeSidebarView() -> NCSidebarView {
        NCSidebarView(account: account, controllerIdentifier: ObjectIdentifier(self), onClose: { [weak self] in
            self?.removeSidebar()
        }, openSettings: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarSettings()
        }, openAssistant: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarAssistant()
        }, openNotifications: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarNotifications()
        }, openFiles: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarFiles(personalFilesOnly: false)
        }, openPersonalFiles: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarFiles(personalFilesOnly: true)
        }, openRecent: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarCollection(storyboard: "NCRecent")
        }, openShares: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarCollection(storyboard: "NCShares")
        }, openGroupfolders: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarCollection(storyboard: "NCGroupfolders")
        }, openTransfers: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarTransfers()
        }, openOffline: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarCollection(storyboard: "NCOffline")
        }, openTrash: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarCollection(storyboard: "NCTrash")
        }, openAutoUpload: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarAutoUpload()
        }, openScannedImages: { [weak self] in
            self?.removeSidebar()
            self?.openSidebarScannedImages()
        }, openExternalSite: { [weak self] url, title, identifier in
            self?.removeSidebar()
            self?.openSidebarExternalSite(url: url, title: title, identifier: identifier)
        }, openApp: { [weak self] url, fallbackUrl in
            self?.removeSidebar()
            self?.openSidebarApp(url: url, fallbackUrl: fallbackUrl)
        }, hasVisibleSidebarButton: { [weak self] in
            self?.hasUncoveredSidebarButton() ?? false
        }, navigationBarCenterY: { [weak self] in
            self?.sidebarNavigationBarCenterY()
        }, windowSafeAreaLeadingInset: { [weak self] in
            self?.view.window?.safeAreaInsets.left ?? 0
        }, currentSelection: { [weak self] in
            self?.sidebarSelectionIdentifier()
        })
    }

    /// Identify the visible section, including Files' current personal filter.
    private func sidebarSelectionIdentifier() -> String? {
        guard selectedIndex == 0,
              let root = currentNavigationController()?.viewControllers.first else { return nil }
        if let identifier = root.restorationIdentifier, identifier.hasPrefix("sidebarExternalSite-") { return identifier }
        switch root {
        case let files as NCFiles:
            return files.personalFilesOnly ? "sidebarPersonalFiles" : "sidebarFiles"
        case is NCRecent:
            return "sidebarRecent"
        case is NCShares:
            return "sidebarShares"
        case is NCGroupfolders:
            return "sidebarGroupfolders"
        case is NCOffline:
            return "sidebarOffline"
        case is NCTrash:
            return "sidebarTrash"
        case is UIHostingController<TransfersView>:
            return "sidebarTransfers"
        default:
            return nil
        }
    }

    /// Measure the visible button row in the panel's safe content coordinates.
    /// Bar-item identifiers are not necessarily forwarded to their rendered views.
    /// Use public control types and accessibility traits, with the bar as fallback.
    private func sidebarNavigationBarCenterY() -> CGFloat? {
        guard let navigationController = currentNavigationController(),
              !navigationController.isNavigationBarHidden else { return nil }
        let hostingView = sidebarHostingController?.viewIfLoaded
        let bar = navigationController.navigationBar
        guard let hostingView, let window = hostingView.window,
              bar.window === window, !bar.isHidden, !bar.bounds.isEmpty else { return nil }
        let buttonFrames = sidebarNavigationButtonFrames(in: bar, navigationBar: bar)
        let centers = buttonFrames.map(\.midY).sorted()
        // The median avoids favoring either the leading or trailing button group.
        let barCenterY = centers.isEmpty ? bar.bounds.midY : centers[centers.count / 2]
        let centerY = bar.convert(CGPoint(x: bar.bounds.midX, y: barCenterY), to: hostingView).y - hostingView.safeAreaInsets.top

        return centerY
    }

    private func sidebarNavigationButtonFrames(in view: UIView, navigationBar: UINavigationBar) -> [CGRect] {
        guard !view.isHidden, view.alpha > 0 else { return [] }
        if view is UIControl, view is UIButton || view.accessibilityTraits.contains(.button) {
            let frame = view.convert(view.bounds, to: navigationBar)
            if !frame.isEmpty, navigationBar.bounds.contains(frame) {
                return [frame]
            }
        }
        return view.subviews.flatMap { subview in
            sidebarNavigationButtonFrames(in: subview, navigationBar: navigationBar)
        }
    }

    /// Only omit the panel's close button when the navigation opener is available
    /// and its entire bar is outside the overlay. Partial overlap keeps the fallback.
    private func hasUncoveredSidebarButton() -> Bool {
        guard let navigationController = currentNavigationController() as? NCMainNavigationController,
              !navigationController.isNavigationBarHidden,
              let overlay = sidebarHostingController?.view,
              let window = overlay.window else { return false }
        let bar = navigationController.navigationBar
        let button = navigationController.sidebarButtonItem
        guard bar.window === window, !bar.isHidden, bar.alpha > 0,
              button.isEnabled,
              navigationController.topViewController?.navigationItem.leadingItemGroups
                .flatMap({ $0.barButtonItems }).contains(where: { $0 === button }) == true else { return false }
        let barFrame = bar.convert(bar.bounds, to: window)
        let overlayFrame = overlay.convert(overlay.bounds, to: window)
        return !barFrame.isEmpty && window.bounds.contains(barFrame) && !barFrame.intersects(overlayFrame)
    }

    private func removeSidebar() {
        guard let hostingController = sidebarHostingController else { return }
        hostingController.willMove(toParent: nil)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
        sidebarHostingController = nil
    }

    func openSidebarSettings() {
        let settingsView = NCSettingsView(model: NCSettingsModel(controller: self))
        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.title = NSLocalizedString("_settings_", comment: "")
        hostingController.navigationItem.largeTitleDisplayMode = .never
        let navigationController = UINavigationController(rootViewController: hostingController)
        navigationController.setNavigationBarAppearance()
        hostingController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: UIAction { [weak navigationController] _ in
                navigationController?.dismiss(animated: true)
            }
        )
        hostingController.navigationItem.rightBarButtonItem?.accessibilityLabel = NSLocalizedString("_close_", comment: "")
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }

    private func openSidebarAssistant() {
        guard let navigationController = currentNavigationController() else { return }
        let inputModel = NCAssistantInputModel()
        let assistant = NCAssistant(
            assistantModel: NCAssistantModel(controller: self, inputModel: inputModel),
            chatModel: NCAssistantChatModel(controller: self, inputModel: inputModel),
            conversationsModel: NCAssistantChatConversationsModel(controller: self)
        )
        navigationController.present(UIHostingController(rootView: assistant), animated: true)
    }

    private func openSidebarNotifications() {
        guard let presenter = currentNavigationController(),
              let navigationController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? UINavigationController,
              let notificationsController = navigationController.topViewController as? NCNotification else { return }
        notificationsController.modalPresentationStyle = .pageSheet
        notificationsController.session = NCSession.shared.getSession(controller: self)
        presenter.present(navigationController, animated: true)
    }

    /// Opens installed companion apps, falling back to their App Store page.
    private func openSidebarApp(url: String, fallbackUrl: String?) {
        guard let appUrl = URL(string: url) else { return }
        if let fallbackUrl, !UIApplication.shared.canOpenURL(appUrl) {
            guard let storeUrl = URL(string: fallbackUrl) else { return }
            UIApplication.shared.open(storeUrl)
        } else {
            UIApplication.shared.open(appUrl)
        }
    }

    private func openSidebarExternalSite(url: String, title: String, identifier: Int) {
        guard url.contains("//"),
              let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let browserController = UIStoryboard(name: "NCBrowserWeb", bundle: nil).instantiateInitialViewController() as? NCBrowserWeb else { return }
        browserController.urlBase = encodedUrl
        browserController.titleBrowser = title
        browserController.isHiddenButtonExit = true
        browserController.restorationIdentifier = "sidebarExternalSite-\(identifier)"
        selectSidebarDestination(NCMainNavigationController(rootViewController: browserController))
    }

    func openSidebarAutoUpload() {
        let autoUploadView = NCAutoUploadView(model: NCAutoUploadModel(controller: self),
                                              albumModel: AlbumModel(controller: self))
            .environment(NCAutoUploadCounter())
        let hostingController = UIHostingController(rootView: autoUploadView)
        hostingController.title = NSLocalizedString("_auto_upload_folder_", comment: "")
        hostingController.navigationItem.largeTitleDisplayMode = .never
        let navigationController = UINavigationController(rootViewController: hostingController)
        navigationController.setNavigationBarAppearance()
        hostingController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: UIAction { [weak navigationController] _ in
                navigationController?.dismiss(animated: true)
            }
        )
        hostingController.navigationItem.rightBarButtonItem?.accessibilityLabel = NSLocalizedString("_close_", comment: "")
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }

    private func openSidebarScannedImages() {
        guard let navigationController = UIStoryboard(name: "NCScan", bundle: nil).instantiateInitialViewController(),
              let scanController = navigationController.topMostViewController() as? NCScan else { return }
        scanController.controller = self
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }

    func openSidebarCollection(storyboard: String) {
        guard let viewController = UIStoryboard(name: storyboard, bundle: nil).instantiateInitialViewController() else { return }
        let navigationController: NCMainNavigationController
        switch viewController {
        case is NCRecent:
            navigationController = NCRecentNavigationController(rootViewController: viewController)
        case is NCShares:
            navigationController = NCSharesNavigationController(rootViewController: viewController)
        case is NCGroupfolders:
            navigationController = NCGroupfoldersNavigationController(rootViewController: viewController)
        case is NCOffline:
            navigationController = NCOfflineNavigationController(rootViewController: viewController)
        case is NCTrash:
            navigationController = NCTrashNavigationController(rootViewController: viewController)
        default:
            return
        }
        selectSidebarDestination(navigationController)
    }

    private func openSidebarTransfers() {
        let transfersView = TransfersView(session: NCSession.shared.getSession(controller: self))
        let hostingController = UIHostingController(rootView: transfersView)
        hostingController.title = NSLocalizedString("_transfers_", comment: "")
        hostingController.navigationItem.largeTitleDisplayMode = .never
        let navigationController = NCMainNavigationController(rootViewController: hostingController)
        selectSidebarDestination(navigationController)
    }
}
