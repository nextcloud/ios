// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

class NCContextMenuNavigation: NSObject {
    // MARK: - collectionViewCommon MENU OPTION ACTION
    //
    @MainActor
    func viewMenuOption(collectionViewCommon: NCCollectionViewCommon?,
                        mainNavigationController: NCMainNavigationController,
                        session: NCSession.Session)
    async -> (select: UIAction,
              viewStyleSubmenu: UIMenu,
              sortSubmenu: UIMenu,
              favoriteOnTop: UIAction,
              directoryOnTop: UIAction,
              hiddenFiles: UIAction,
              personalFilesOnly: UIAction,
              showDescription: UIAction,
              showRecommendedFiles: UIAction?)? {
        guard let collectionViewCommon else {
            return nil
        }
        let utility = NCUtility()
        let global = NCGlobal.shared

        var showRecommendedFiles: UIAction?
        let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: collectionViewCommon.layoutKey, serverUrl: collectionViewCommon.serverUrl)
        let select = UIAction(title: NSLocalizedString("_select_", comment: ""),
                              image: utility.loadImage(named: "checkmark.circle")) { _ in
            Task {
                if !collectionViewCommon.dataSource.isEmpty() {
                    await collectionViewCommon.setEditMode(true)
                    collectionViewCommon.collectionView.reloadData()
                }
            }
        }

        let list = UIAction(title: NSLocalizedString("_list_", comment: ""),
                            image: utility.loadImage(named: "list.bullet"),
                            state: layoutForView.layout == global.layoutList ? .on : .off) { _ in
            Task {
                layoutForView.layout = global.layoutList
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await mainNavigationController.updateMenuOption()
            }
        }

        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""),
                            image: utility.loadImage(named: "square.grid.2x2"),
                            state: layoutForView.layout == global.layoutGrid ? .on : .off) { _ in
            Task {
                layoutForView.layout = global.layoutGrid
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await mainNavigationController.updateMenuOption()
            }
        }

        let mediaSquare = UIAction(title: NSLocalizedString("_media_square_", comment: ""),
                                   image: utility.loadImage(named: "square.grid.3x3"),
                                   state: layoutForView.layout == global.layoutPhotoSquare ? .on : .off) { _ in
            Task {
                layoutForView.layout = global.layoutPhotoSquare
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await mainNavigationController.updateMenuOption()
            }
        }

        let mediaRatio = UIAction(title: NSLocalizedString("_media_ratio_", comment: ""),
                                  image: utility.loadImage(named: "rectangle.grid.3x2"),
                                  state: layoutForView.layout == global.layoutPhotoRatio ? .on : .off) { _ in
            Task {
                layoutForView.layout = global.layoutPhotoRatio
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await mainNavigationController.updateMenuOption()
            }
        }

        let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid, mediaSquare, mediaRatio])

        let ascending = layoutForView.ascending
        let ascendingChevronImage = utility.loadImage(named: ascending ? "chevron.up" : "chevron.down")
        let isName = layoutForView.sort == "fileName"
        let isDate = layoutForView.sort == "date"
        let isSize = layoutForView.sort == "size"

        let byName = UIAction(title: NSLocalizedString("_name_", comment: ""),
                              image: isName ? ascendingChevronImage : nil,
                              state: isName ? .on : .off) { _ in
            Task {
                if isName {
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "fileName"
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await mainNavigationController.updateMenuOption()
            }
        }

        let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""),
                                image: isDate ? ascendingChevronImage : nil,
                                state: isDate ? .on : .off) { _ in
            Task {
                if isDate {
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "date"
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await mainNavigationController.updateMenuOption()
            }
        }

        let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""),
                                 image: isSize ? ascendingChevronImage : nil,
                                 state: isSize ? .on : .off) { _ in
            Task {
                if isSize {
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "size"
                collectionViewCommon.changeLayout(layoutForView: layoutForView)
                await mainNavigationController.updateMenuOption()
            }
        }

        let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""),
                                 options: .displayInline,
                                 children: [byName, byNewest, byLargest])

        let favoriteOnTop = NCPreferences().getFavoriteOnTop(account: session.account)
        let favoriteOnTopAction = UIAction(title: NSLocalizedString("_favorite_on_top_", comment: ""),
                                           state: favoriteOnTop ? .on : .off) { _ in
            Task {
                NCPreferences().setFavoriteOnTop(account: session.account, value: !favoriteOnTop)
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadDataSource(serverUrl: collectionViewCommon.serverUrl, requestData: false, status: nil)
                }
                await mainNavigationController.updateMenuOption()
            }
        }

        let directoryOnTop = NCPreferences().getDirectoryOnTop(account: session.account)
        let directoryOnTopAction = UIAction(title: NSLocalizedString("_directory_on_top_", comment: ""),
                                            state: directoryOnTop ? .on : .off) { _ in
            Task {
                NCPreferences().setDirectoryOnTop(account: session.account, value: !directoryOnTop)
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadDataSource(serverUrl: collectionViewCommon.serverUrl, requestData: false, status: nil)
                }
                await mainNavigationController.updateMenuOption()
            }
        }

        let hiddenFiles = NCPreferences().getShowHiddenFiles(account: session.account)
        let hiddenFilesAction = UIAction(title: NSLocalizedString("_show_hidden_files_", comment: ""),
                                         state: hiddenFiles ? .on : .off) { _ in
            Task {
                NCPreferences().setShowHiddenFiles(account: session.account, value: !hiddenFiles)
                await collectionViewCommon.getServerData(forced: true)
                await mainNavigationController.updateMenuOption()
            }
        }

        let personalFilesOnly = NCPreferences().getPersonalFilesOnly(account: session.account)
        let personalFilesOnlyAction = UIAction(title: NSLocalizedString("_personal_files_only_", comment: ""),
                                               image: utility.loadImage(named: "folder.badge.person.crop", colors: NCBrandColor.shared.iconImageMultiColors),
                                               state: personalFilesOnly ? .on : .off) { _ in
            Task {
                NCPreferences().setPersonalFilesOnly(account: session.account, value: !personalFilesOnly)
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadDataSource(serverUrl: collectionViewCommon.serverUrl, requestData: false, status: nil)
                }
                await mainNavigationController.updateMenuOption()
            }
        }

        let showDescriptionKeychain = NCPreferences().showDescription
        let showDescription = UIAction(title: NSLocalizedString("_show_description_", comment: ""),
                                       state: showDescriptionKeychain ? .on : .off) { _ in
            NCPreferences().showDescription = !showDescriptionKeychain
            Task {
                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferReloadDataSource(serverUrl: collectionViewCommon.serverUrl, requestData: false, status: nil)
                }
                await mainNavigationController.updateMenuOption()
            }
        }

        let showRecommendedFilesKeychain = NCPreferences().showRecommendedFiles
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
        let capabilityRecommendations = capabilities.recommendations

        if capabilityRecommendations {
            showRecommendedFiles = UIAction(title: NSLocalizedString("_show_recommended_files_", comment: ""),
                                            state: showRecommendedFilesKeychain ? .on : .off) { _ in
                Task {
                    NCPreferences().showRecommendedFiles = !showRecommendedFilesKeychain
                    collectionViewCommon.collectionView.reloadData()
                    await mainNavigationController.updateMenuOption()
                }
            }
        }

        return (select, viewStyleSubmenu, sortSubmenu, favoriteOnTopAction, directoryOnTopAction, hiddenFilesAction, personalFilesOnlyAction, showDescription, showRecommendedFiles)
    }

    // MARK: - TRASH MENU OPTION ACTION
    //
    @MainActor
    func viewMenuOption(trashViewController: NCTrash?,
                        mainNavigationController: NCMainNavigationController,
                        session: NCSession.Session) async -> [UIMenuElement]? {
        guard let trashViewController else {
            return nil
        }
        let utility = NCUtility()
        let global = NCGlobal.shared
        let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: trashViewController.layoutKey, serverUrl: "")

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""),
                              image: utility.loadImage(named: "checkmark.circle")) { _ in
            if let datasource = trashViewController.datasource,
               !datasource.isEmpty {
                trashViewController.setEditMode(true)
                trashViewController.collectionView.reloadData()
            }
        }
        let list = UIAction(title: NSLocalizedString("_list_", comment: ""),
                            image: utility.loadImage(named: "list.bullet", colors: [NCBrandColor.shared.iconImageColor]),
                            state: layoutForView.layout == global.layoutList ? .on : .off) { _ in
            Task {
                trashViewController.onListSelected()
                await mainNavigationController.updateMenuOption()
            }
        }
        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""),
                            image: utility.loadImage(named: "square.grid.2x2", colors: [NCBrandColor.shared.iconImageColor]),
                            state: layoutForView.layout == global.layoutGrid ? .on : .off) { _ in
            Task {
                trashViewController.onGridSelected()
                await mainNavigationController.updateMenuOption()
            }
        }

        let emptyTrash = UIAction(title: NSLocalizedString("_empty_trash_", comment: ""),
                                  image: utility.loadImage(named: "trash", colors: [NCBrandColor.shared.iconImageColor])) { _ in
            Task {
                await trashViewController.emptyTrash()
            }
        }

        let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid])

        return [select, viewStyleSubmenu, emptyTrash]
    }
}
