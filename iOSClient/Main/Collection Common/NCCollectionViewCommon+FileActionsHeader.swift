//
//  NCCollectionViewCommon+FileActionsHeader.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 28.02.2025.
//  Copyright © 2025 STRATO GmbH. All rights reserved.
//

import Foundation

extension NCCollectionViewCommon {
    
    func fixSearchBarPlacementForIOS16() {
        if #available(iOS 16.0, *) {
            navigationItem.preferredSearchBarPlacement = .stacked
        }
    }
    
    // MARK: - Headers view
    
    func updateHeadersView() {
        fileActionsHeader?.isHidden = isSearchingMode
        collectionViewTop?.constant = isSearchingMode ? 0 : fileActionsHeader?.bounds.height ?? 0
        fileActionsHeader?.setIsEditingMode(isEditingMode: isEditMode)
        fileActionsHeader?.enableSelection(enable: !self.dataSource.isEmpty())
        
        fileActionsHeader?.setSortingMenu(sortingMenuElements: createSortMenuActions(), title: sortTitle, image: sortDirectionImage)
        fileActionsHeader?.setViewModeMenu(viewMenuElements: createViewModeMenuActions(), image: viewModeImage?.templateRendered())
        
        fileActionsHeader?.onSelectModeChange = { [weak self] isSelectionMode in
            self?.setEditMode(isSelectionMode)
            (self?.navigationController as? NCMainNavigationController)?.setNavigationRightItems()
            self?.updateHeadersView()
            self?.fileActionsHeader?.setSelectionState(selectionState: .none)
        }
        
        fileActionsHeader?.onSelectAll = { [weak self] in
            guard let self = self else { return }
            self.selectAll()
            let selectionState: FileActionsHeaderSelectionState = self.fileSelect.count == 0 ? .none : .all
            self.fileActionsHeader?.setSelectionState(selectionState: selectionState)
        }
    }
    
    private func createSortMenuActions() -> [UIMenuElement] {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl) else { return [] }
        
        let ascending = layoutForView.ascending
        let ascendingChevronImage = utility.loadImage(named: ascending ? "chevron.up" : "chevron.down")
        let isName = layoutForView.sort == "fileName"
        let isDate = layoutForView.sort == "date"
        let isSize = layoutForView.sort == "size"
        
        let byName = UIAction(title: NSLocalizedString("_name_", comment: ""), image: isName ? ascendingChevronImage : nil, state: isName ? .on : .off) { [weak self] _ in
            if isName { // repeated press
                layoutForView.ascending = !layoutForView.ascending
            }
            layoutForView.sort = "fileName"
            self?.notifyAboutLayoutChange(layoutForView)
        }
        
        let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""), image: isDate ? ascendingChevronImage : nil, state: isDate ? .on : .off) { [weak self]  _ in
            if isDate { // repeated press
                layoutForView.ascending = !layoutForView.ascending
            }
            layoutForView.sort = "date"
            self?.notifyAboutLayoutChange(layoutForView)
        }
        
        let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""), image: isSize ? ascendingChevronImage : nil, state: isSize ? .on : .off) { [weak self]  _ in
            if isSize { // repeated press
                layoutForView.ascending = !layoutForView.ascending
            }
            layoutForView.sort = "size"
            self?.notifyAboutLayoutChange(layoutForView)
        }
        
        let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""), options: .displayInline, children: [byName, byNewest, byLargest])
        
        let directoryOnTop = NCKeychain().getDirectoryOnTop(account: session.account)
        let foldersOnTop = UIAction(title: NSLocalizedString("_directory_on_top_no_", comment: ""), image: utility.loadImage(named: "folder"), state: directoryOnTop ? .on : .off) { [weak self]  _ in
            if let account = self?.session.account {
                NCKeychain().setDirectoryOnTop(account: account, value: !directoryOnTop)
            }
            self?.notifyAboutLayoutChange(layoutForView)
        }
        
        let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop])
        return [sortSubmenu, additionalSubmenu]
    }
    
    private func createViewModeMenuActions() -> [UIMenuElement] {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl) else { return [] }

        let listImage = UIImage(resource: .FileSelection.viewModeList).templateRendered()
        let gridImage = UIImage(resource: .FileSelection.viewModeGrid).templateRendered()

        let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: listImage, state: layoutForView.layout == NCGlobal.shared.layoutList ? .on : .off) { _ in
            layoutForView.layout = self.global.layoutList
            self.notifyAboutLayoutChange(layoutForView)
        }

        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: gridImage, state: layoutForView.layout == NCGlobal.shared.layoutGrid ? .on : .off) { _ in
            layoutForView.layout = self.global.layoutGrid
            self.notifyAboutLayoutChange(layoutForView)
        }

        let menuPhoto = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: NSLocalizedString("_media_square_", comment: ""), image: gridImage, state: layoutForView.layout == NCGlobal.shared.layoutPhotoSquare ? .on : .off) { _ in
                layoutForView.layout = self.global.layoutPhotoSquare
                self.notifyAboutLayoutChange(layoutForView)
            },
            UIAction(title: NSLocalizedString("_media_ratio_", comment: ""), image: gridImage, state: layoutForView.layout == NCGlobal.shared.layoutPhotoRatio ? .on : .off) { _ in
                layoutForView.layout = self.global.layoutPhotoRatio
                self.notifyAboutLayoutChange(layoutForView)
            }
        ])

        return [list, grid, UIMenu(title: NSLocalizedString("_media_view_options_", comment: ""), children: [menuPhoto])]
    }
    
    private func notifyAboutLayoutChange(_ layoutForView: NCDBLayoutForView) {
        NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                    object: nil,
                                                    userInfo: ["account": self.session.account,
                                                               "serverUrl": self.serverUrl,
                                                               "layoutForView": layoutForView])
    }
    
    private var sortTitle: String? {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl) else { return nil }
        
        switch layoutForView.sort {
        case "fileName": return NSLocalizedString("_name_", comment: "")
        case "date": return NSLocalizedString("_date_", comment: "")
        case "size": return NSLocalizedString("_size_", comment: "")
        default: return nil
        }
    }
    
    private var sortDirectionImage: UIImage? {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl) else { return nil }
        let imageName = layoutForView.ascending ? "arrow.up" : "arrow.down"
        return UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
    }
    
    private var viewModeImage: UIImage? {
        var imageResource: ImageResource?
        
        switch layoutType {
        case NCGlobal.shared.layoutList: imageResource = .FileSelection.viewModeList
        case NCGlobal.shared.layoutGrid, NCGlobal.shared.layoutPhotoRatio, NCGlobal.shared.layoutPhotoSquare: imageResource = .FileSelection.viewModeGrid
        default: break
        }
        
        if let imageResource {
            return UIImage(resource: imageResource)
        }
        return nil
    }
    
    func setNavigationBarLogoIfNeeded() {
        if isCurrentScreenInMainTabBar() && self.navigationController?.viewControllers.count == 1 {
            setNavigationBarLogo()
        }
    }
    
    var selectionState: FileActionsHeaderSelectionState {
        let selectedItemsCount = fileSelect.count
        if selectedItemsCount == dataSource.getMetadatas().count {
            return .all
        }
        
        return selectedItemsCount == 0 ? .none : .some(selectedItemsCount)
    }
}
