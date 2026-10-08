// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

extension NCMainTabBarController {
    private var activeSidebarSplit: NCMainSplitViewController? {
        guard let split = splitViewController as? NCMainSplitViewController,
              !split.isCollapsed else { return nil }
        return split
    }

    func presentSidebar() {
        guard presentedViewController == nil else { return }
        if let split = activeSidebarSplit {
            if split.displayMode == .secondaryOnly {
                split.showSidebar()
            } else {
                split.hideSidebar()
            }
            return
        }
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

    /// Builds the same sidebar for a native split column or our compact overlay.
    func makeSidebarView(isDocked: Bool = false) -> NCSidebarView {
        NCSidebarView(account: account, controllerIdentifier: ObjectIdentifier(self), onClose: { [weak self] in
            self?.removeSidebar()
        }, openSettings: { [weak self] in
            self?.closeSidebarForAction()
            self?.openSidebarSettings()
        }, openAssistant: { [weak self] in
            self?.closeSidebarForAction()
            self?.openSidebarAssistant()
        }, openNotifications: { [weak self] in
            self?.closeSidebarForAction()
            self?.openSidebarNotifications()
        }, openTransfers: { [weak self] in
            self?.closeSidebarForAction()
            self?.openSidebarTransfers()
        }, hasVisibleSidebarButton: { [weak self] in
            self?.hasUncoveredSidebarButton() ?? false
        }, navigationBarCenterY: { [weak self] in
            self?.sidebarNavigationBarCenterY(isDocked: isDocked)
        }, isDocked: isDocked)
    }

    /// Measure the visible button row in the panel's safe content coordinates.
    /// Bar-item identifiers are not necessarily forwarded to their rendered views.
    /// Use public control types and accessibility traits, with the bar as fallback.
    private func sidebarNavigationBarCenterY(isDocked: Bool) -> CGFloat? {
        guard let navigationController = currentNavigationController(),
              !navigationController.isNavigationBarHidden else { return nil }
        let hostingView: UIView?
        if isDocked {
            let primary = splitViewController?.viewController(for: .primary) as? UINavigationController
            hostingView = primary?.topViewController?.viewIfLoaded
        } else {
            hostingView = sidebarHostingController?.viewIfLoaded
        }
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
              navigationController.topViewController?.navigationItem.leftBarButtonItems?.contains(where: { $0 === button }) == true else { return false }
        let barFrame = bar.convert(bar.bounds, to: window)
        let overlayFrame = overlay.convert(overlay.bounds, to: window)
        return !barFrame.isEmpty && window.bounds.contains(barFrame) && !barFrame.intersects(overlayFrame)
    }

    private func closeSidebarForAction() {
        // Keep the adjacent sidebar available while opening a destination.
        // An overlaid sidebar closes so it does not cover that destination.
        if let split = activeSidebarSplit {
            if split.displayMode != .oneBesideSecondary {
                split.hideSidebar()
            }
        } else {
            removeSidebarOverlay()
        }
    }

    private func removeSidebar() {
        // Explicit dismissal hides the sidebar even when it is beside the content.
        if let split = activeSidebarSplit {
            split.hideSidebar()
        } else {
            removeSidebarOverlay()
        }
    }

    func removeSidebarOverlay() {
        guard let hostingController = sidebarHostingController else { return }
        hostingController.willMove(toParent: nil)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
        sidebarHostingController = nil
    }

    func openSidebarSettings() {
        guard let navigationController = currentNavigationController() else { return }

        let settingsView = NCSettingsView(model: NCSettingsModel(controller: self))
        let settingsController = UIHostingController(rootView: settingsView)
        settingsController.title = NSLocalizedString("_settings_", comment: "")
        navigationController.pushViewController(settingsController, animated: true)
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

    private func openSidebarTransfers() {
        guard let navigationController = currentNavigationController() else { return }
        let transfersView = TransfersView(session: NCSession.shared.getSession(controller: self), onClose: { [weak navigationController] in
            navigationController?.dismiss(animated: true)
        })
        let hostingController = UIHostingController(rootView: transfersView)
        hostingController.modalPresentationStyle = .pageSheet
        navigationController.present(hostingController, animated: true)
    }
}
