// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import NextcloudKit

class NCMainNavigationController: UINavigationController, UINavigationControllerDelegate {
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    let utility = NCUtility()
    let utilityFileSystem = NCUtilityFileSystem()
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let menuPlusButton: UIButton = NCMenuPlusButton(type: .system)

    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    var collectionViewCommon: NCCollectionViewCommon? {
        topViewController as? NCCollectionViewCommon
    }

    var trashViewController: NCTrash? {
        topViewController as? NCTrash
    }

    var mediaViewController: NCMedia? {
        topViewController as? NCMedia
    }

    @MainActor
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    let menuNavigation = NCContextMenuNavigation()
    var menuPlus: NCContextMenuPlus?

    lazy var sidebarButtonItem: UIBarButtonItem = {
        let action = UIAction(title: NSLocalizedString("_sidebar_navigation_", comment: ""), image: UIImage(systemName: "sidebar.left")) { [weak self] _ in
            self?.controller?.presentSidebar()
        }
        let item = UIBarButtonItem(image: UIImage(systemName: "sidebar.left"), primaryAction: action)
        item.menuRepresentation = action
        if #available(iOS 27.0, *) {
            item.visibilityPriority = .high
        }
        if #available(iOS 27.1, *) {
            item.axisBehavior = .horizontalOnly
        }
        item.accessibilityLabel = NSLocalizedString("_sidebar_navigation_", comment: "")
        item.accessibilityIdentifier = "openSidebar"
        return item
    }()

    private var isEditingContent: Bool {
        (collectionViewCommon?.isEditMode ?? false) || (trashViewController?.isEditMode ?? false) || (mediaViewController?.isEditMode ?? false)
    }

    private var leadingItems: [UIBarButtonItem] {
        guard let navigationItem = topViewController?.navigationItem else { return [] }
        let items = navigationItem.leadingItemGroups.flatMap { $0.barButtonItems }
        return items.isEmpty ? navigationItem.leftBarButtonItems ?? [] : items
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self

        setNavigationBarAppearance()
        setNavigationBarHidden(false, animated: true)

        configurePlusButton()
        observeNotifications()
    }

    // MARK: - Plus Button

    private func configurePlusButton() {
        let buttonSize: CGFloat = 44
        let plusConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        let plusImage = UIImage(systemName: "plus", withConfiguration: plusConfiguration)?.withRenderingMode(.alwaysTemplate)

        if #available(iOS 26.0, *) {
            var glassConfiguration = UIButton.Configuration.prominentGlass()
            glassConfiguration.image = plusImage
            menuPlusButton.configuration = glassConfiguration
        } else {
            menuPlusButton.setImage(plusImage, for: .normal)
            menuPlusButton.contentHorizontalAlignment = .center
            menuPlusButton.contentVerticalAlignment = .center
            menuPlusButton.layer.cornerRadius = buttonSize / 2
            menuPlusButton.layer.masksToBounds = false
            menuPlusButton.layer.shadowColor = UIColor.black.cgColor
            menuPlusButton.layer.shadowOpacity = 0.18
            menuPlusButton.layer.shadowRadius = 8
            menuPlusButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        }

        menuPlusButton.setPlusButtonColor(NCBrandColor.shared.getElement(account: session.account))
        menuPlusButton.showsMenuAsPrimaryAction = true
        menuPlusButton.translatesAutoresizingMaskIntoConstraints = false
        menuPlusButton.accessibilityLabel = NSLocalizedString("_add_", comment: "")

        view.addSubview(menuPlusButton)

        NSLayoutConstraint.activate([
            menuPlusButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            menuPlusButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            menuPlusButton.widthAnchor.constraint(equalToConstant: buttonSize),
            menuPlusButton.heightAnchor.constraint(equalToConstant: buttonSize)
        ])

        menuPlus = NCContextMenuPlus(menuPlusButton: menuPlusButton, controller: controller)
    }

    // MARK: - Notifications

    private func observeNotifications() {
        // CAPABILITIES UPDATE
        let serverUpdate = Notification.Name(global.notificationCenterServerDidUpdate)
        NotificationCenter.default.addObserver(forName: serverUpdate, object: nil, queue: nil) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let account = userInfo["account"] as? String else {
                return
            }

            Task { @MainActor [weak self] in
                guard let self,
                      let controller = self.controller,
                      controller.account == account else {
                    return
                }

                let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
                guard controller.account == account else { return }
                let session = NCSession.shared.getSession(account: account)

                if capabilities.notification.isEmpty {
                    controller.availableNotifications = false
                } else {
                    _ = await NextcloudKit.shared.getNotificationsAsync(account: account)
                    guard controller.account == account else { return }
                    controller.availableNotifications = true
                }
                guard controller.account == account else { return }
                await self.updateNavigationMenu()
                await self.menuPlus?.create(session: session)
            }
        }

        // REACHABILITY
        let reachability = Notification.Name(global.notificationCenterNetworkReachability)
        NotificationCenter.default.addObserver(forName: reachability, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }

                await self.menuPlus?.create(session: session)
            }
        }
    }

    // MARK: - Navigation

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if #available(iOS 27.0, *),
           viewController is NCCollectionViewCommon || viewController is NCMedia || viewController is AlbumsViewController ||
           viewController is NCTrash || viewController is NCActivity || viewController is UIHostingController<TransfersView> {
            viewController.navigationItem.navigationBarMinimization.minimizationBehavior = .never
        }

        Task { @MainActor in
            if let viewController = viewController as? NCFiles {
                menuPlus?.hiddenPlusButton(isEditMode: viewController.isEditMode, isSearchingMode: viewController.isSearchingMode, animation: false)
            } else {
                menuPlus?.hiddenPlusButton(true, animation: false)
            }
            setNavigationBarAppearance()
            await updateNavigationMenu()
            configureSidebarButton()
        }
    }

    // MARK: - Right

    @MainActor
    func setNavigationRightItems() async {
        // COLLECTION EDIT MODE
        if let collectionViewCommon, collectionViewCommon.isEditMode {
            collectionViewCommon.tabBarSelect?.update(fileSelect: collectionViewCommon.fileSelect, metadatas: collectionViewCommon.getSelectedMetadatas(), userId: session.userId)
            collectionViewCommon.tabBarSelect?.show()
            // SEARCH (OFF)
            collectionViewCommon.navigationItem.searchController = nil

            setCancelButton(for: collectionViewCommon.navigationItem) {
                Task {
                    await collectionViewCommon.setEditMode(false)
                }
            }
            return
        }

        // TRASH EDIT MODE
        if let trashViewController, trashViewController.isEditMode {
            trashViewController.tabBarSelect.update(selectOcId: [])
            trashViewController.tabBarSelect.show()

            setCancelButton(for: trashViewController.navigationItem) {
                trashViewController.setEditMode(false)
            }
            return
        }

        // NORMAL MODE
        trashViewController?.tabBarSelect?.hide()
        collectionViewCommon?.tabBarSelect?.hide()
        // SEARCH (ON)
        collectionViewCommon?.navigationItem.searchController = collectionViewCommon?.searchController
        await updateNavigationMenu()
    }

    private func setCancelButton(for navigationItem: UINavigationItem, action: @escaping () -> Void) {
        let cancel = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain) {
            action()
        }
        cancel.accessibilityLabel = NSLocalizedString("_cancel_", comment: "")
        navigationItem.additionalOverflowItems = nil
        navigationItem.trailingItemGroups = [UIBarButtonItemGroup(barButtonItems: [cancel], representativeItem: nil)]
    }

    @MainActor
    func updateNavigationMenu() async {
        guard let topViewController else {
            return
        }

        guard !isEditingContent,
              !(topViewController is NCViewerPDF),
              !(topViewController is NCViewerRichdocuments),
              !(topViewController is NCViewerDirectEditing)
        else {
            return
        }

        let menu = await createOptionMenu()
        guard self.topViewController === topViewController, !isEditingContent else { return }
        setOptionMenu(menu, for: topViewController.navigationItem)
        topViewController.navigationItem.trailingItemGroups = []
    }

    func createOptionMenu() async -> UIMenu? { return nil }

    func updateMenuOption() async {
        guard let topViewController, topViewController.navigationItem.additionalOverflowItems != nil else { return }
        let menu = await createOptionMenu()
        guard self.topViewController === topViewController, topViewController.navigationItem.additionalOverflowItems != nil else { return }
        setOptionMenu(menu, for: topViewController.navigationItem)
    }

    /// Shares UIKit's overflow button with navigation items that no longer fit in the bar.
    func setOptionMenu(_ menu: UIMenu?, for navigationItem: UINavigationItem) {
        navigationItem.additionalOverflowItems = menu.map { menu in
            UIDeferredMenuElement.uncached { completion in
                completion(menu.children)
            }
        }
    }

    // MARK: - Left

    func setNavigationLeftItems() async {
        configureSidebarButton()
    }

    func configureSidebarButton() {
        guard let navigationItem = topViewController?.navigationItem else { return }
        var items = leadingItems
        items.removeAll { $0 === sidebarButtonItem }
        // Rebuild loading from its state so repeated updates cannot duplicate or retain a stopped spinner.
        let albums = topViewController as? AlbumsViewController
        let loadingItem = collectionViewCommon?.serverDataActivityBarButtonItem ?? trashViewController?.serverDataActivityBarButtonItem ?? albums?.serverDataActivityBarButtonItem
        let loadingIndicator = collectionViewCommon?.serverDataActivityIndicator ?? trashViewController?.serverDataActivityIndicator ?? albums?.serverDataActivityIndicator
        items.removeAll { $0 === loadingItem }
        let isFiles = topViewController is NCFiles
        if isFiles || topViewController === viewControllers.first,
           controller != nil,
           !isEditingContent {
            items.insert(sidebarButtonItem, at: 0)
            if isFiles {
                navigationItem.leftItemsSupplementBackButton = true
            }
        }
        if albums != nil {
            navigationItem.leftItemsSupplementBackButton = true
        }
        if let loadingItem, loadingIndicator?.isAnimating == true {
            items.append(loadingItem)
        }
        // Each item can move independently into UIKit's overflow menu.
        navigationItem.leadingItemGroups = items.map { item in
            UIBarButtonItemGroup(barButtonItems: [item], representativeItem: nil)
        }
    }

    /// Changes the tint color of a specific left bar button item identified by tag.
    /// - Parameters:
    ///   - tag: The tag used to identify the UIBarButtonItem.
    ///   - color: The UIColor to be applied.
    @MainActor
    func setLeftItemColor(tag: Int, to color: UIColor) {
        guard let item = leadingItems.first(where: { $0.tag == tag }) else { return }

        applyTint(item, color: color)
    }

    /// Changes the tint color of all left bar button items currently visible
    /// in the topViewController's navigation item.
    /// - Parameter color: The UIColor to be applied.
    @MainActor
    func setAllLeftItemsColor(_ color: UIColor) {
        for item in leadingItems {
            applyTint(item, color: color)
        }
    }

    // MARK: - Tint helpers

    /// Applies a tint color to a given UIButton, handling both UIButton.Configuration
    /// and legacy setup with SF Symbols or titles.
    /// - Parameters:
    ///   - button: The UIButton to apply the color.
    ///   - color: The UIColor to be applied.
    @MainActor
    private func applyTint(_ button: UIButton, color: UIColor) {
        if var cfg = button.configuration {
            cfg.baseForegroundColor = color
            button.configuration = cfg
        } else {
            button.tintColor = color
            button.setTitleColor(color, for: .normal)
        }
    }

    @MainActor
    private func applyTint(_ item: UIBarButtonItem, color: UIColor) {
        if let button = item.customView as? UIButton {
            applyTint(button, color: color)
        } else {
            item.tintColor = color
        }
    }

    /// Updates the tint color of the system overflow and currently visible right bar buttons.
    /// - Parameter color: The UIColor to be applied to all right bar button items.
    @MainActor
    func updateRightBarButtonsTint(to color: UIColor) {
        navigationBar.tintColor = color

        if let visibleItems = topViewController?.navigationItem.rightBarButtonItems {
            for item in visibleItems {
                applyTint(item, color: color)
            }
        }
    }
}

private final class NCMenuPlusButton: UIButton {
    // Keep hit testing so taps don't fall through if the button is disabled, hidden or low alpha.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let view = super.hitTest(point, with: event) {
            return view
        }

        guard !isEnabled, !isHidden, alpha >= 0.01, bounds.contains(point) else {
            return nil
        }

        return self
    }

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard isEnabled else { return nil }

        return super.contextMenuInteraction(interaction, configurationForMenuAtLocation: location)
    }
}

extension UIButton {
    func setPlusButtonColor(_ color: UIColor) {
        if #available(iOS 26.0, *) {
            tintColor = color
        } else {
            backgroundColor = color
            tintColor = .white
        }
    }
}
