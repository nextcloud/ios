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

    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    var collectionViewCommon: NCCollectionViewCommon? {
        topViewController as? NCCollectionViewCommon
    }

    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    let menuButtonTag = 1
    let transfersButtonTag = 2
    let notificationsButtonTag = 3

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self

        navigationBar.prefersLargeTitles = true
        setNavigationBarHidden(false, animated: true)
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController is NCMore || viewController is UIHostingController<Nextcloud.NCSettingsView> {
            setGroupAppearance()
        } else {
            setNavigationBarAppearance()
        }
    }

    func setNavigationLeftItems() { }
    func setNavigationRightItems() { }

    func createMenuActions() -> (select: UIAction, viewStyleSubmenu: UIMenu, sortSubmenu: UIMenu, foldersOnTop: UIAction, personalFilesOnlyAction: UIAction, showDescription: UIAction, showRecommendedFiles: UIAction)? {
        guard let collectionViewCommon,
              let layoutForView = database.getLayoutForView(account: session.account, key: collectionViewCommon.layoutKey, serverUrl: collectionViewCommon.serverUrl) else { return nil }

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""),
                              image: utility.loadImage(named: "checkmark.circle"),
                              attributes: (collectionViewCommon.dataSource.isEmpty() || NCNetworking.shared.isOffline) ? .disabled : []) { _ in
            collectionViewCommon.setEditMode(true)
            collectionViewCommon.collectionView.reloadData()
        }

        let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: utility.loadImage(named: "list.bullet"), state: layoutForView.layout == global.layoutList ? .on : .off) { _ in

            layoutForView.layout = self.global.layoutList

            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: utility.loadImage(named: "square.grid.2x2"), state: layoutForView.layout == global.layoutGrid ? .on : .off) { _ in

            layoutForView.layout = self.global.layoutGrid

            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let mediaSquare = UIAction(title: NSLocalizedString("_media_square_", comment: ""), image: utility.loadImage(named: "square.grid.3x3"), state: layoutForView.layout == global.layoutPhotoSquare ? .on : .off) { _ in

            layoutForView.layout = self.global.layoutPhotoSquare

            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let mediaRatio = UIAction(title: NSLocalizedString("_media_ratio_", comment: ""), image: utility.loadImage(named: "rectangle.grid.3x2"), state: layoutForView.layout == self.global.layoutPhotoRatio ? .on : .off) { _ in

            layoutForView.layout = self.global.layoutPhotoRatio

            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid, mediaSquare, mediaRatio])

        let ascending = layoutForView.ascending
        let ascendingChevronImage = utility.loadImage(named: ascending ? "chevron.up" : "chevron.down")
        let isName = layoutForView.sort == "fileName"
        let isDate = layoutForView.sort == "date"
        let isSize = layoutForView.sort == "size"

        let byName = UIAction(title: NSLocalizedString("_name_", comment: ""), image: isName ? ascendingChevronImage : nil, state: isName ? .on : .off) { _ in

            if isName { // repeated press
                layoutForView.ascending = !layoutForView.ascending
            }
            layoutForView.sort = "fileName"

            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""), image: isDate ? ascendingChevronImage : nil, state: isDate ? .on : .off) { _ in

            if isDate { // repeated press
                layoutForView.ascending = !layoutForView.ascending
            }
            layoutForView.sort = "date"

            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""), image: isSize ? ascendingChevronImage : nil, state: isSize ? .on : .off) { _ in

            if isSize { // repeated press
                layoutForView.ascending = !layoutForView.ascending
            }
            layoutForView.sort = "size"

            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let directoryOnTop = NCKeychain().getDirectoryOnTop(account: session.account)
        let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""), options: .displayInline, children: [byName, byNewest, byLargest])

        let foldersOnTop = UIAction(title: NSLocalizedString("_directory_on_top_no_", comment: ""), image: utility.loadImage(named: "folder"), state: directoryOnTop ? .on : .off) { _ in

            NCKeychain().setDirectoryOnTop(account: self.session.account, value: !directoryOnTop)

            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                        object: nil,
                                                        userInfo: ["account": self.session.account,
                                                                   "serverUrl": collectionViewCommon.serverUrl,
                                                                   "layoutForView": layoutForView])
        }

        let personalFilesOnly = NCKeychain().getPersonalFilesOnly(account: self.session.account)
        let personalFilesOnlyAction = UIAction(title: NSLocalizedString("_personal_files_only_", comment: ""), image: utility.loadImage(named: "folder.badge.person.crop", colors: NCBrandColor.shared.iconImageMultiColors), state: personalFilesOnly ? .on : .off) { _ in

            NCKeychain().setPersonalFilesOnly(account: self.session.account, value: !personalFilesOnly)

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": collectionViewCommon.serverUrl, "clearDataSource": true])
            self.setNavigationRightItems()
        }

        let showDescriptionKeychain = NCKeychain().showDescription
        let showDescription = UIAction(title: NSLocalizedString("_show_description_", comment: ""), attributes: collectionViewCommon.richWorkspaceText == nil ? .disabled : [], state: showDescriptionKeychain && collectionViewCommon.richWorkspaceText != nil ? .on : .off) { _ in

            NCKeychain().showDescription = !showDescriptionKeychain

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": collectionViewCommon.serverUrl, "clearDataSource": true])
            self.setNavigationRightItems()
        }

        showDescription.subtitle = collectionViewCommon.richWorkspaceText == nil ? NSLocalizedString("_no_description_available_", comment: "") : ""

        let showRecommendedFilesKeychain = NCKeychain().showRecommendedFiles
        let capabilityRecommendations = NCCapabilities.shared.getCapabilities(account: session.account).capabilityRecommendations
        let showRecommendedFiles = UIAction(title: NSLocalizedString("_show_recommended_files_", comment: ""), attributes: !capabilityRecommendations ? .disabled : [], state: showRecommendedFilesKeychain ? .on : .off) { _ in

            NCKeychain().showRecommendedFiles = !showRecommendedFilesKeychain

            collectionViewCommon.collectionView.reloadData()
            self.setNavigationRightItems()
        }

        return (select, viewStyleSubmenu, sortSubmenu, foldersOnTop, personalFilesOnlyAction, showDescription, showRecommendedFiles)
    }
}
