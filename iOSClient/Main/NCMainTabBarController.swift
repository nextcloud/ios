// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import NextcloudKit

struct NavigationCollectionViewCommon {
    var serverUrl: String
    var navigationController: UINavigationController?
    var viewController: NCCollectionViewCommon
}

class NCMainTabBarController: UITabBarController {
    var sceneIdentifier: String = UUID().uuidString
    var account: String = "" {
        didSet {
            // Restore Files before account-change notifications reach its controllers.
            if isViewLoaded, account != oldValue {
                openSidebarFiles(personalFilesOnly: false)
            }
        }
    }
    var availableNotifications: Bool = false
    var documentPickerViewController: NCDocumentPickerViewController?
    let navigationCollectionViewCommon = ThreadSafeArray<NavigationCollectionViewCommon>()
    let sidebarOpeningGesture = UIPanGestureRecognizer()
    var sidebarHostingController: UIHostingController<NCSidebarView>?
    private var filesNavigationController: NCFilesNavigationController?
    private var previousIndex: Int?
    private var checkUserDelaultErrorInProgress: Bool = false
    private var timerTask: Task<Void, Never>?
    private let global = NCGlobal.shared

    override var selectedViewController: UIViewController? {
        didSet {
            NotificationCenter.default.post(name: NCSidebarView.selectionChanged, object: self)
        }
    }

    var window: UIWindow? {
        return SceneManager.shared.getWindow(controller: self)
    }

    var barHeightBottom: CGFloat {
        return tabBar.frame.height - tabBar.safeAreaInsets.bottom
    }

    var barHeightTop: CGFloat {
        return tabBar.frame.height - tabBar.safeAreaInsets.top
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        NCNetworking.shared.setupScene(sceneIdentifier: sceneIdentifier, controller: self)

        tabBar.tintColor = NCBrandColor.shared.getElement(account: account)

        filesNavigationController = viewControllers?.first as? NCFilesNavigationController
        configureTabBarItems()
        configureTabBarAppearance()
        configureSidebarGesture()

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: self.global.notificationCenterChangeTheming), object: nil, queue: .main) { [weak self] notification in
            if let userInfo = notification.userInfo as? NSDictionary,
               let account = userInfo["account"] as? String,
               self?.account == account {
                self?.tabBar.tintColor = NCBrandColor.shared.getElement(account: account)
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: self.global.notificationCenterCheckUserDelaultErrorDone), object: nil, queue: nil) { notification in
            if let userInfo = notification.userInfo,
               let account = userInfo["account"] as? String,
               let controller = userInfo["controller"] as? NCMainTabBarController,
               account == self.account,
               controller == self {
                self.checkUserDelaultErrorInProgress = false
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.timerTask?.cancel()
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
            if !isAppInBackground {
                self.timerTask = Task { @MainActor [weak self = self] in
                    await self?.timerCheck()
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previousIndex = selectedIndex

        if NCBrandOptions.shared.enforce_passcode_lock && NCPreferences().passcode.isEmptyOrNil {
            let vc = UIHostingController(rootView: SetupPasscodeView(isLockActive: .constant(false), controller: self))
            vc.isModalInPresentation = true

            present(vc, animated: true)
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    /// Browse keeps a fixed identity while displaying the selected sidebar section.
    /// Files retains its navigation stack when another destination occupies Browse.
    func selectSidebarDestination(_ navigationController: NCMainNavigationController) {
        guard var controllers = viewControllers, !controllers.isEmpty else { return }
        if controllers.first !== navigationController {
            let image = UIImage(systemName: "square.grid.2x2.fill")
            navigationController.tabBarItem = UITabBarItem(
                title: NSLocalizedString("_browse_", comment: ""),
                image: image,
                selectedImage: image
            )
            navigationController.tabBarItem.tag = 100
            controllers[0] = navigationController
            setViewControllers(controllers, animated: false)
        }
        selectedViewController = navigationController
        previousIndex = selectedIndex
    }

    func openSidebarFiles(personalFilesOnly: Bool? = nil) {
        guard let filesNavigationController else { return }
        if let personalFilesOnly {
            filesNavigationController.personalFilesOnly = personalFilesOnly
            filesNavigationController.popToRootViewController(animated: false)
        }
        selectSidebarDestination(filesNavigationController)
        if personalFilesOnly != nil {
            let selectedAccount = account
            Task { @MainActor [weak self] in
                guard self?.account == selectedAccount,
                      let files = filesNavigationController.topViewController as? NCFiles else { return }
                files.titleCurrentFolder = files.getNavigationTitle()
                files.navigationItem.title = files.titleCurrentFolder
                let serverUrl = files.serverUrl
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadDataSource(serverUrl: serverUrl, requestData: false, status: nil)
                }
                await filesNavigationController.updateMenuOption()
            }
        }
    }

    private func configureTabBarItems() {
        configureTabBarItem(
            at: 0,
            title: "_browse_",
            imageName: "square.grid.2x2.fill",
            tag: 100
        )

        configureTabBarItem(
            at: 1,
            title: "_favorites_",
            imageName: "star.fill",
            tag: 101
        )

        configureTabBarItem(
            at: 2,
            title: "_media_",
            imageName: "photo.fill",
            tag: 102
        )

        configureTabBarItem(
            at: 3,
            title: "_albums_",
            imageName: "photo.stack.fill",
            tag: 103
        )

        configureTabBarItem(
            at: 4,
            title: "_activity_",
            imageName: "bolt.fill",
            tag: 104
        )
    }

    private func configureTabBarItem(at index: Int, title: String, imageName: String, tag: Int) {
        guard let items = tabBar.items, items.indices.contains(index) else { return }

        let item = items[index]
        item.title = NSLocalizedString(title, comment: "")
        item.image = UIImage(systemName: imageName)
        item.selectedImage = item.image
        item.tag = tag
    }

    @MainActor
    private func timerCheck() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))

            guard isViewLoaded, view.window != nil else {
                continue
            }

            // Check error
            await NCNetworking.shared.checkServerError(account: self.account, controller: self)
        }
    }

    func currentViewController() -> UIViewController? {
        return (selectedViewController as? UINavigationController)?.topViewController
    }

    func currentNavigationController() -> UINavigationController? {
        return selectedViewController as? UINavigationController
    }

    func currentServerUrl() -> String {
        let session = NCSession.shared.getSession(account: account)
        var serverUrl = NCUtilityFileSystem().getHomeServer(session: session)
        let viewController = currentViewController()
        if let collectionViewCommon = viewController as? NCCollectionViewCommon {
            if !collectionViewCommon.serverUrl.isEmpty {
                serverUrl = collectionViewCommon.serverUrl
            }
        }
        return serverUrl
    }

    func hide() {
        if #available(iOS 18.0, *) {
            setTabBarHidden(true, animated: true)
        } else {
            tabBar.isHidden = true
        }
    }

    func show() {
        if #available(iOS 18.0, *) {
            setTabBarHidden(false, animated: true)
        } else {
            tabBar.isHidden = false
        }
    }
}

extension NCMainTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if previousIndex == tabBarController.selectedIndex {
            scrollToTop(viewController: viewController)
        }
        previousIndex = tabBarController.selectedIndex
        NotificationCenter.default.post(name: NCSidebarView.selectionChanged, object: self)
    }

    private func scrollToTop(viewController: UIViewController) {
        guard let navigationController = viewController as? UINavigationController,
              let topViewController = navigationController.topViewController else { return }

        if let scrollView = topViewController.view.subviews.compactMap({ $0 as? UIScrollView }).first {
            scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top), animated: true)
        }
    }
}
