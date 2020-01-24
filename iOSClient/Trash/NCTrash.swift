//
//  NCTrash.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import Sheeeeeeeeet

class NCTrash: UIViewController, UIGestureRecognizerDelegate, NCTrashListCellDelegate, NCGridCellDelegate, NCTrashSectionHeaderMenuDelegate, DropdownMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate  {
    
    @IBOutlet fileprivate weak var collectionView: UICollectionView!

    var path = ""
    var titleCurrentFolder = NSLocalizedString("_trash_view_", comment: "")
    var blinkocId: String?
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    private var isEditMode = false
    private var selectocId = [String]()
    
    private var datasource = [tableTrash]()
    
    private var typeLayout = ""
    private var datasourceSorted = ""
    private var datasourceAscending = true
    private var datasourceGroupBy = "none"
    private var datasourceDirectoryOnTop = false
    
    private var listLayout: NCListLayout!
    private var gridLayout: NCGridLayout!
    
    private var actionSheet: ActionSheet?

    private let highHeader: CGFloat = 50
    
    private let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCTrashListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib.init(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header - Footer
        collectionView.register(UINib.init(nibName: "NCTrashSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        collectionView.register(UINib.init(nibName: "NCTrashSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")

        collectionView.alwaysBounceVertical = true

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()
        
        // Add Refresh Control
        collectionView.refreshControl = refreshControl
        
        // Configure Refresh Control
        refreshControl.addTarget(self, action: #selector(loadListingTrash), for: .valueChanged)
        
        // empty Data Source
        self.collectionView.emptyDataSetDelegate = self;
        self.collectionView.emptyDataSetSource = self;
        
        // changeTheming
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.title = titleCurrentFolder

        (typeLayout, datasourceSorted, datasourceAscending, datasourceGroupBy, datasourceDirectoryOnTop) = NCUtility.sharedInstance.getLayoutForView(key: k_layout_view_trash)

        if typeLayout == k_layout_list {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }
        
        // Datasource & serverUrl
        
        if path == "" {
            let userID = (appDelegate.activeUserID as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlFragmentAllowed)
            path = k_dav + "/trashbin/" + userID! + "/trash/"
        }
        
        if (datasource.count == 0) {
            loadDatasource()
        }
        
        loadListingTrash()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.actionSheet?.viewDidLayoutSubviews()
        }
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: collectionView, form: false)
        
        refreshControl.tintColor = NCBrandColor.sharedInstance.brandText
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.brand
    }
    
    // MARK: DZNEmpty
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 300, height: 300, color: NCBrandColor.sharedInstance.graySoft)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n"+NSLocalizedString("_trash_no_trash_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n"+NSLocalizedString("_trash_no_trash_description_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }

    // MARK: TAP EVENT
    
    func tapSwitchHeaderMenu(sender: Any) {
        
        if collectionView.collectionViewLayout == gridLayout {
            // list layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.listLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                    self.collectionView.setContentOffset(CGPoint(x:0,y:0), animated: false)
                })
            })
            typeLayout = k_layout_list
            NCUtility.sharedInstance.setLayoutForView(key: k_layout_view_trash, layout: typeLayout, sort: datasourceSorted, ascending: datasourceAscending, groupBy: datasourceGroupBy, directoryOnTop: datasourceDirectoryOnTop)
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                    self.collectionView.setContentOffset(CGPoint(x:0,y:0), animated: false)
                })
            })
            typeLayout = k_layout_grid
            NCUtility.sharedInstance.setLayoutForView(key: k_layout_view_trash, layout: typeLayout, sort: datasourceSorted, ascending: datasourceAscending, groupBy: datasourceGroupBy, directoryOnTop: datasourceDirectoryOnTop)
        }
    }
    
    func tapOrderHeaderMenu(sender: Any) {
        
        var menuView: DropdownMenu?
        var selectedRow = 0
        
        let item1 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortFileNameAZ"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_name_a_z_", comment: ""))
        let item2 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortFileNameZA"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_name_z_a_", comment: ""))
        let item3 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortDateMoreRecent"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_date_more_recent_", comment: ""))
        let item4 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortDateLessRecent"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_date_less_recent_", comment: ""))
        let item5 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortSmallest"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_size_smallest_", comment: ""))
        let item6 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortLargest"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_size_largest_", comment: ""))
        
        switch datasourceSorted {
        case "fileName":
            if datasourceAscending == true { item1.style = .highlight; selectedRow = 0 }
            if datasourceAscending == false { item2.style = .highlight; selectedRow = 1 }
        case "date":
            if datasourceAscending == false { item3.style = .highlight; selectedRow = 2 }
            if datasourceAscending == true { item4.style = .highlight; selectedRow = 3 }
        case "size":
            if datasourceAscending == true { item5.style = .highlight; selectedRow = 4 }
            if datasourceAscending == false { item6.style = .highlight; selectedRow = 5 }
        default:
            print("")
        }
        
        menuView = DropdownMenu(navigationController: self.navigationController!, items: [item1, item2, item3, item4, item5, item6], selectedRow: selectedRow)
        menuView?.token = "tapOrderHeaderMenu"
        menuView?.delegate = self
        menuView?.rowHeight = 45
        menuView?.highlightColor = NCBrandColor.sharedInstance.brand
        menuView?.tableView.alwaysBounceVertical = false
        menuView?.tableViewSeperatorColor = NCBrandColor.sharedInstance.separator
        menuView?.tableViewBackgroundColor = NCBrandColor.sharedInstance.backgroundForm
        menuView?.cellBackgroundColor = NCBrandColor.sharedInstance.backgroundForm
        menuView?.textColor = NCBrandColor.sharedInstance.textView

        let header = (sender as? UIButton)?.superview as! NCTrashSectionHeaderMenu
        let headerRect = self.collectionView.convert(header.bounds, from: self.view)
        let menuOffsetY =  headerRect.height - headerRect.origin.y - 2
        menuView?.topOffsetY = CGFloat(menuOffsetY)
        
        menuView?.showMenu()
    }
    
    func tapMoreHeaderMenu(sender: Any) {
        
        var menuView: DropdownMenu?
        
        if isEditMode {
            
            //let item0 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "checkedNo"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_cancel_", comment: ""))
            //let item1 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), multiplier: 1, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_trash_restore_selected_", comment: ""))
            let item2 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_trash_delete_selected_", comment: ""))
            
            menuView = DropdownMenu(navigationController: self.navigationController!, items: [item2], selectedRow: -1)
            menuView?.token = "tapMoreHeaderMenuSelect"
            
        } else {
            
            //let item0 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "select"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_select_", comment: ""))
            //let item1 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), multiplier: 1, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_trash_restore_all_", comment: ""))
            let item2 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_trash_delete_all_", comment: ""))
            
            menuView = DropdownMenu(navigationController: self.navigationController!, items: [item2], selectedRow: -1)
            menuView?.token = "tapMoreHeaderMenu"
        }
        
        menuView?.delegate = self
        menuView?.rowHeight = 45
        menuView?.highlightColor = NCBrandColor.sharedInstance.brand
        menuView?.tableView.alwaysBounceVertical = false
        menuView?.tableViewBackgroundColor = NCBrandColor.sharedInstance.backgroundForm
        menuView?.cellBackgroundColor = NCBrandColor.sharedInstance.backgroundForm
        menuView?.textColor = NCBrandColor.sharedInstance.textView
        
        let header = (sender as? UIButton)?.superview as! NCTrashSectionHeaderMenu
        let headerRect = self.collectionView.convert(header.bounds, from: self.view)
        let menuOffsetY =  headerRect.height - headerRect.origin.y - 2
        menuView?.topOffsetY = CGFloat(menuOffsetY)
        
        menuView?.showMenu()
    }
    
    func tapRestoreListItem(with ocId: String, sender: Any) {
        
        if !isEditMode {
            restoreItem(with: ocId)
        } else {
            let buttonPosition:CGPoint = (sender as! UIButton).convert(CGPoint.zero, to:collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }
    
    func tapMoreListItem(with objectId: String, sender: Any) {

        if !isEditMode {
            var items = [MenuItem]()
            
            ActionSheetTableView.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
            ActionSheetTableView.appearance().separatorColor = NCBrandColor.sharedInstance.separator
            ActionSheetItemCell.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
            ActionSheetItemCell.appearance().titleColor = NCBrandColor.sharedInstance.textView
            
            items.append(DestructiveButton(title: NSLocalizedString("_delete_", comment: "")))
            items.append(CancelButton(title: NSLocalizedString("_cancel_", comment: "")))
            
            actionSheet = ActionSheet(menu: Menu(items: items), action: { (shhet, item) in
                if item is DestructiveButton { self.deleteItem(with: objectId) }
                if item is CancelButton { print("Cancel buttons has the value `true`") }
            })
            
            guard let tableTrash = NCManageDatabase.sharedInstance.getTrashItem(fileId: objectId, account: appDelegate.activeAccount) else {
                return
            }
            
            let headerView = NCActionSheetHeader.sharedInstance.actionSheetHeader(isDirectory: tableTrash.directory, iconName: tableTrash.iconName, ocId: tableTrash.fileId, fileNameView: tableTrash.fileName, text: tableTrash.trashbinFileName)
            actionSheet?.headerView = headerView
            actionSheet?.headerView?.frame.size.height = 50
            
            actionSheet?.present(in: self, from: sender as! UIButton)
        } else {
            let buttonPosition:CGPoint = (sender as! UIButton).convert(CGPoint.zero, to:collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }
    
    func tapMoreGridItem(with objectId: String, sender: Any) {
        
        if !isEditMode {
            var items = [MenuItem]()

            ActionSheetTableView.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
            ActionSheetTableView.appearance().separatorColor = NCBrandColor.sharedInstance.separator
            ActionSheetItemCell.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
            ActionSheetItemCell.appearance().titleColor = NCBrandColor.sharedInstance.textView
            
            items.append(MenuItem(title: NSLocalizedString("_restore_", comment: ""), value: 0, image: CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)))
            items.append(MenuItem(title: NSLocalizedString("_delete_", comment: ""), value: 1, image: CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 50, height: 50, color: UIColor.red)))
            items.append(CancelButton(title: NSLocalizedString("_cancel_", comment: "")))
            
            actionSheet = ActionSheet(menu: Menu(items: items), action: { (shhet, item) in
                if item.value as? Int == 0 { self.restoreItem(with: objectId) }
                if item.value as? Int == 1 { self.deleteItem(with: objectId) }
                if item is CancelButton { print("Cancel buttons has the value `true`") }
            })
            
            guard let tableTrash = NCManageDatabase.sharedInstance.getTrashItem(fileId: objectId, account: appDelegate.activeAccount) else {
                return
            }
            
            let headerView = NCActionSheetHeader.sharedInstance.actionSheetHeader(isDirectory: tableTrash.directory, iconName: tableTrash.iconName, ocId: tableTrash.fileId, fileNameView: tableTrash.fileName, text: tableTrash.trashbinFileName)
            actionSheet?.headerView = headerView
            actionSheet?.headerView?.frame.size.height = 50
            
            actionSheet?.present(in: self, from: sender as! UIButton)
        } else {
            let buttonPosition:CGPoint = (sender as! UIButton).convert(CGPoint.zero, to:collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }
    
    // MARK: DROP-DOWN-MENU

    func dropdownMenu(_ dropdownMenu: DropdownMenu, didSelectRowAt indexPath: IndexPath) {
        
        if dropdownMenu.token == "tapOrderHeaderMenu" {
            
            switch indexPath.row {
                
            case 0: datasourceSorted = "fileName"; datasourceAscending = true
            case 1: datasourceSorted = "fileName"; datasourceAscending = false
                
            case 2: datasourceSorted = "date"; datasourceAscending = false
            case 3: datasourceSorted = "date"; datasourceAscending = true
                
            case 4: datasourceSorted = "size"; datasourceAscending = true
            case 5: datasourceSorted = "size"; datasourceAscending = false
                
            default: print("")
            }
            
            NCUtility.sharedInstance.setLayoutForView(key: k_layout_view_trash, layout: typeLayout, sort: datasourceSorted, ascending: datasourceAscending, groupBy: datasourceGroupBy, directoryOnTop: datasourceDirectoryOnTop)

            loadDatasource()
        }
        
        if dropdownMenu.token == "tapMoreHeaderMenu" {
        
            /*
            // Select
            if indexPath.row == 0 {
                isEditMode = true
                collectionView.reloadData()
            }
            
            // Restore ALL
            if indexPath.row == 1 {
                for record: tableTrash in self.datasource {
                    restoreItem(with: record.ocId)
                }
            }
            */
            
            // Empty Trash
            if indexPath.row == 0 {
                
                var items = [MenuItem]()
                
                ActionSheetTableView.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
                ActionSheetTableView.appearance().separatorColor = NCBrandColor.sharedInstance.separator
                ActionSheetItemCell.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
                ActionSheetItemCell.appearance().titleColor = NCBrandColor.sharedInstance.textView
                
                items.append(MenuItem(title: NSLocalizedString("_trash_delete_all_", comment: "")))
                items.append(DestructiveButton(title: NSLocalizedString("_ok_", comment: "")))
                items.append(CancelButton(title: NSLocalizedString("_cancel_", comment: "")))
                
                actionSheet = ActionSheet(menu: Menu(items: items), action: { (shhet, item) in
                    if item is DestructiveButton {
                        self.emptyTrash()
                        //for record: tableTrash in self.datasource {
                        //    self.deleteItem(with: record.ocId)
                        //}
                    }
                    if item is CancelButton { return }
                })
                
                actionSheet?.present(in: self, from: self.view)
            }
        }
        
        if dropdownMenu.token == "tapMoreHeaderMenuSelect" {
            
            // Cancel
            if indexPath.row == 0 {
                isEditMode = false
                selectocId.removeAll()
                collectionView.reloadData()
            }
            
            // Restore selected files
            if indexPath.row == 1 {
                for ocId in selectocId {
                    restoreItem(with: ocId)
                }
                isEditMode = false
                selectocId.removeAll()
                collectionView.reloadData()
            }
            
            // Delete selected files
            if indexPath.row == 2 {
                
                var items = [MenuItem]()
                
                ActionSheetTableView.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
                ActionSheetTableView.appearance().separatorColor = NCBrandColor.sharedInstance.separator
                ActionSheetItemCell.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
                ActionSheetItemCell.appearance().titleColor = NCBrandColor.sharedInstance.textView
                
                items.append(MenuItem(title: NSLocalizedString("_trash_delete_selected_", comment: "")))
                items.append(DestructiveButton(title: NSLocalizedString("_delete_", comment: "")))
                items.append(CancelButton(title: NSLocalizedString("_cancel_", comment: "")))
                
                actionSheet = ActionSheet(menu: Menu(items: items), action: { (shhet, item) in
                    if item is DestructiveButton {
                        for ocId in self.selectocId {
                            self.deleteItem(with: ocId)
                        }
                        self.isEditMode = false
                        self.selectocId.removeAll()
                        self.collectionView.reloadData()
                    }
                    if item is CancelButton { return }
                })
                
                actionSheet?.present(in: self, from: self.view)
            }
            
        }
    }
    
    /*
    func dropdownMenuWillDismiss(_ dropdownMenu: DropdownMenu) {
        if dropdownMenu.token == "tapOrderHeaderMenu" {
            let trashHeader = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(row: 0, section: 0)) as! NCTrashHeaderMenu
            let title = String(trashHeader.buttonOrder.title(for: .normal)!.dropLast()) + "▽"
            trashHeader.buttonOrder.setTitle(title, for: .normal)
        }
    }
    
    func dropdownMenuWillShow(_ dropdownMenu: DropdownMenu) {
        
        if dropdownMenu.token == "tapOrderHeaderMenu" {
            let trashHeader = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(row: 0, section: 0)) as! NCTrashHeaderMenu
            let title = String(trashHeader.buttonOrder.title(for: .normal)!.dropLast()) + "△"
            trashHeader.buttonOrder.setTitle(title, for: .normal)
        }
    }
    */
}

// MARK: - Collection View

extension NCTrash: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let tableTrash = datasource[indexPath.item]
        
        if isEditMode {
            if let index = selectocId.firstIndex(of: tableTrash.fileId) {
                selectocId.remove(at: index)
            } else {
                selectocId.append(tableTrash.fileId)
            }
            collectionView.reloadItems(at: [indexPath])
            return
        }
        
        if tableTrash.directory {
            
            let ncTrash:NCTrash = UIStoryboard(name: "NCTrash", bundle: nil).instantiateInitialViewController() as! NCTrash
            
            ncTrash.path = tableTrash.filePath + tableTrash.fileName
            ncTrash.titleCurrentFolder = tableTrash.trashbinFileName
            
            self.navigationController?.pushViewController(ncTrash, animated: true)
        }
    }
}

extension NCTrash: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            
            let trashHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCTrashSectionHeaderMenu
            
            if collectionView.collectionViewLayout == gridLayout {
                trashHeader.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
            } else {
                trashHeader.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchGrid"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
            }
            
            trashHeader.delegate = self
            trashHeader.backgroundColor = NCBrandColor.sharedInstance.backgroundView
            trashHeader.separator.backgroundColor = NCBrandColor.sharedInstance.separator
            trashHeader.setStatusButton(datasource: datasource)
            trashHeader.setTitleOrder(datasourceSorted: datasourceSorted, datasourceAscending: datasourceAscending)
            
            
            return trashHeader
            
        } else {
            
            let trashFooter = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCTrashSectionFooter
            
            trashFooter.setTitleLabelFooter(datasource: datasource)
            
            return trashFooter
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return datasource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let tableTrash = datasource[indexPath.item]
        var image: UIImage?
        
        if tableTrash.iconName.count > 0 {
            image = UIImage.init(named: tableTrash.iconName)
        } else {
            image = UIImage.init(named: "file")
        }
        
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, fileNameView: tableTrash.fileName)) {
            image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, fileNameView: tableTrash.fileName))
        } else {
            if tableTrash.hasPreview && !CCUtility.fileProviderStorageIconExists(tableTrash.fileId, fileNameView: tableTrash.fileName) {
                downloadThumbnail(with: tableTrash, indexPath: indexPath)
            }
        }
        
        if collectionView.collectionViewLayout == listLayout {
            
            // LIST
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCTrashListCell
            cell.delegate = self
            
            cell.objectId = tableTrash.fileId
            cell.indexPath = indexPath
            cell.labelTitle.text = tableTrash.trashbinFileName
            cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
            cell.separator.backgroundColor = NCBrandColor.sharedInstance.separator

            if tableTrash.directory {
                cell.imageItem.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                cell.labelInfo.text = CCUtility.dateDiff(tableTrash.date as Date)
            } else {
                cell.imageItem.image = image
                cell.labelInfo.text = CCUtility.dateDiff(tableTrash.date as Date) + ", " + CCUtility.transformedSize(tableTrash.size)
            }
            
            if isEditMode {
                cell.imageItemLeftConstraint.constant = 45
                cell.imageSelect.isHidden = false
                
                if selectocId.contains(tableTrash.fileId) {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedYes"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = NCUtility.sharedInstance.cellBlurEffect(with: cell.bounds)
                } else {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedNo"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = nil
                }
            } else {
                cell.imageItemLeftConstraint.constant = 10
                cell.imageSelect.isHidden = true
                cell.backgroundView = nil
            }
            
            return cell
            
        } else {
            
            // GRID
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
            cell.delegate = self
            
            cell.objectId = tableTrash.fileId
            cell.indexPath = indexPath
            cell.labelTitle.text = tableTrash.trashbinFileName
            cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
            
            if tableTrash.directory {
                cell.imageItem.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
            } else {
                cell.imageItem.image = image
            }
            
            if isEditMode {
                cell.imageSelect.isHidden = false
                if selectocId.contains(tableTrash.fileId) {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedYes"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = NCUtility.sharedInstance.cellBlurEffect(with: cell.bounds)
                } else {
                    cell.imageSelect.isHidden = true
                    cell.backgroundView = nil
                }
            } else {
                cell.imageSelect.isHidden = true
                cell.backgroundView = nil
            }
            return cell
        }
    }
}

extension NCTrash: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: highHeader)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: highHeader)
    }
}

// MARK: - NC API & Algorithm

extension NCTrash {

    @objc func loadDatasource() {
        
        datasource.removeAll()
        
        guard let tashItems = NCManageDatabase.sharedInstance.getTrash(filePath: path, sorted: datasourceSorted, ascending: datasourceAscending, account: appDelegate.activeAccount) else {
            return
        }
        
        datasource = tashItems
        
        reloadDataThenPerform {
            // GoTo ocId
            if self.blinkocId != nil {
                for item in 0...self.datasource.count-1 {
                    if self.datasource[item].fileId.contains(self.blinkocId!) {
                        let indexPath = IndexPath(item: item, section: 0)
                        self.collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.blinkocId = nil
                            NCUtility.sharedInstance.blink(cell: self.collectionView.cellForItem(at: indexPath))
                        }
                    }
                }
            }
        }        
    }
    
    @objc func loadListingTrash() {
        
        OCNetworking.sharedManager().listingTrash(withAccount: appDelegate.activeAccount, path: path, serverUrl: appDelegate.activeUrl, depth: "1", completion: { (account, item, message, errorCode) in
            
            self.refreshControl.endRefreshing()
            
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                NCManageDatabase.sharedInstance.deleteTrash(filePath: self.path, account: self.appDelegate.activeAccount)
                NCManageDatabase.sharedInstance.addTrashs(item as! [tableTrash])
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
            
            self.loadDatasource()
        })
    }
    
    func reloadDataThenPerform(_ closure: @escaping (() -> Void)) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(closure)
        collectionView.reloadData()
        CATransaction.commit()
    }
    
    func restoreItem(with fileId: String) {
        
        guard let tableTrash = NCManageDatabase.sharedInstance.getTrashItem(fileId: fileId, account: appDelegate.activeAccount) else {
            return
        }
        
        let fileName = appDelegate.activeUrl + tableTrash.filePath + tableTrash.fileName
        let fileNameTo = appDelegate.activeUrl + k_dav + "/trashbin/" + appDelegate.activeUserID + "/restore/" + tableTrash.fileName
        
        OCNetworking.sharedManager().moveFileOrFolder(withAccount: appDelegate.activeAccount, fileName: fileName, fileNameTo: fileNameTo, completion: { (account, message, errorCode) in
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                NCManageDatabase.sharedInstance.deleteTrash(fileId: fileId, account: account!)
                self.loadDatasource()
            }  else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
        })
    }
    
    func emptyTrash() {
        
        OCNetworking.sharedManager().emptyTrash(withAccount: appDelegate.activeAccount, completion: { (account, message, errorCode) in
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                NCManageDatabase.sharedInstance.deleteTrash(fileId: nil, account: self.appDelegate.activeAccount)
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
            self.loadDatasource()
        })
    }
    
    func deleteItem(with fileId: String) {
        
        guard let tableTrash = NCManageDatabase.sharedInstance.getTrashItem(fileId: fileId, account: appDelegate.activeAccount) else {
            return
        }
        
        let path = appDelegate.activeUrl + tableTrash.filePath + tableTrash.fileName
        
        OCNetworking.sharedManager().deleteFileOrFolder(withAccount: appDelegate.activeAccount, path: path, completion: { (account, message, errorCode) in
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                NCManageDatabase.sharedInstance.deleteTrash(fileId: fileId, account: account!)
                self.loadDatasource()
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
        })
    }
    
    func downloadThumbnail(with tableTrash: tableTrash, indexPath: IndexPath) {
        
        OCNetworking.sharedManager().downloadPreviewTrash(withAccount: appDelegate.activeAccount, fileId: tableTrash.fileId, size: "128", fileName: tableTrash.fileName, completion: { (account, image, message, errorCode) in
            
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                if let cell = self.collectionView.cellForItem(at: indexPath) {
                    if cell is NCTrashListCell {
                        (cell as! NCTrashListCell).imageItem.image = image
                    } else if cell is NCGridCell {
                        (cell as! NCGridCell).imageItem.image = image
                    }
                }
            }
        })
    }
}
