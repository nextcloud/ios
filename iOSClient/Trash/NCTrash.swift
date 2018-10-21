//
//  NCTrash.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class NCTrash: UIViewController ,UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, NCTrashListDelegate, NCTrashGridDelegate, NCTrashHeaderMenuDelegate, DropdownMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate  {
    
    @IBOutlet fileprivate weak var collectionView: UICollectionView!

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var path = ""
    var titleCurrentFolder = NSLocalizedString("_trash_view_", comment: "")
    var datasource = [tableTrash]()
    var datasourceSorted = ""
    var datasourceAscending = true
    var isEditMode = false
    var selectFileID = [String]()
    
    var listLayout: ListLayout!
    var gridLayout: GridLayout!
    
    private let highHeader: CGFloat = 50
    
    private let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.register(UINib.init(nibName: "NCTrashListCell", bundle: nil), forCellWithReuseIdentifier: "cell-list")
        collectionView.register(UINib.init(nibName: "NCTrashGridCell", bundle: nil), forCellWithReuseIdentifier: "cell-grid")
        
        collectionView.alwaysBounceVertical = true

        listLayout = ListLayout()
        gridLayout = GridLayout()
        
        if CCUtility.getLayoutTrash() == "list" {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }
        
        // Add Refresh Control
        if #available(iOS 10.0, *) {
            collectionView.refreshControl = refreshControl
        } else {
            collectionView.addSubview(refreshControl)
        }
        
        // Configure Refresh Control
        refreshControl.tintColor = NCBrandColor.sharedInstance.brandText
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.brand
        refreshControl.addTarget(self, action: #selector(loadListingTrash), for: .valueChanged)
        
        // empty Data Source
        self.collectionView.emptyDataSetDelegate = self;
        self.collectionView.emptyDataSetSource = self;        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.title = titleCurrentFolder

        if path == "" {
            let userID = (appDelegate.activeUserID as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlFragmentAllowed)
            path = k_dav + "/trashbin/" + userID! + "/trash/"
        }
        
        datasourceSorted = CCUtility.getOrderSettings()
        datasourceAscending = CCUtility.getAscendingSettings()
        
        guard let datasource = NCManageDatabase.sharedInstance.getTrash(filePath: path, sorted: datasourceSorted, ascending: datasourceAscending) else {
            return
        }
        
        self.datasource = datasource
        collectionView.reloadData()
        
        loadListingTrash()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    // MARK: DZNEmpty
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "trashNoFiles"), multiplier: 2, color: NCBrandColor.sharedInstance.graySoft)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n"+NSLocalizedString("_trash_no_trash_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
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
            CCUtility.setLayoutTrash("list")
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                    self.collectionView.setContentOffset(CGPoint(x:0,y:0), animated: false)
                })
            })
            CCUtility.setLayoutTrash("grid")
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
        menuView?.rowHeight = 50
        menuView?.highlightColor = NCBrandColor.sharedInstance.brand
        menuView?.tableView.alwaysBounceVertical = false
        
        let header = (sender as? UIButton)?.superview as! NCTrashHeaderMenu
        let headerRect = self.collectionView.convert(header.bounds, from: self.view)
        let menuOffsetY =  headerRect.height - headerRect.origin.y - 2
        menuView?.topOffsetY = CGFloat(menuOffsetY)
        
        menuView?.showMenu()
    }
    
    func tapMoreHeaderMenu(sender: Any) {
        
        var menuView: DropdownMenu?
        
        if isEditMode {
            
            let item0 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "checkedNo"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_cancel_", comment: ""))
            let item1 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), multiplier: 1, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_trash_restore_selected_", comment: ""))
            let item2 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_trash_delete_selected_", comment: ""))
            
            menuView = DropdownMenu(navigationController: self.navigationController!, items: [item0, item1, item2], selectedRow: -1)
            menuView?.token = "tapMoreHeaderMenuSelect"
            
        } else {
            
            let item0 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "select"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_select_", comment: ""))
            let item1 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), multiplier: 1, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_trash_restore_all_", comment: ""))
            let item2 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_trash_delete_all_", comment: ""))
            
            menuView = DropdownMenu(navigationController: self.navigationController!, items: [item0, item1, item2], selectedRow: -1)
            menuView?.token = "tapMoreHeaderMenu"
        }
        
        
        menuView?.delegate = self
        menuView?.rowHeight = 50
        menuView?.tableView.alwaysBounceVertical = false
        
        let header = (sender as? UIButton)?.superview as! NCTrashHeaderMenu
        let headerRect = self.collectionView.convert(header.bounds, from: self.view)
        let menuOffsetY =  headerRect.height - headerRect.origin.y - 2
        menuView?.topOffsetY = CGFloat(menuOffsetY)
        
        menuView?.showMenu()
    }
    
    func tapRestoreItem(with fileID: String, sender: Any) {
        
        if !isEditMode {
            restoreItem(with: fileID)
        } else {
            let buttonPosition:CGPoint = (sender as! UIButton).convert(CGPoint.zero, to:collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }
    
    func tapMoreItem(with fileID: String, sender: Any) {

        if !isEditMode {
            var items = [ActionSheetItem]()
            
            items.append(ActionSheetDangerButton(title: NSLocalizedString("_delete_", comment: "")))
            items.append(ActionSheetCancelButton(title: NSLocalizedString("_cancel_", comment: "")))
            
            let actionSheet = ActionSheet(items: items) { sheet, item in
                if item is ActionSheetDangerButton { self.deleteItem(with: fileID) }
                if item is ActionSheetCancelButton { print("Cancel buttons has the value `true`") }
            }
            
            let headerView = actionSheetHeader(with: fileID)
            actionSheet.headerView = headerView
            actionSheet.headerView?.frame.size.height = 50
            
            actionSheet.present(in: self, from: sender as! UIButton)
        } else {
            let buttonPosition:CGPoint = (sender as! UIButton).convert(CGPoint.zero, to:collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }
    
    func tapMoreGridItem(with fileID: String, sender: Any) {
        
        if !isEditMode {
            var items = [ActionSheetItem]()
            let appearanceDelete = ActionSheetItemAppearance.init()
            appearanceDelete.textColor = UIColor.red
            
            items.append(ActionSheetItem(title: NSLocalizedString("_restore_", comment: ""), value: 0, image: CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), multiplier: 1, color: NCBrandColor.sharedInstance.icon)))
            let itemDelete = ActionSheetItem(title: NSLocalizedString("_delete_", comment: ""), value: 1, image: CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), multiplier: 2, color: UIColor.red))
            itemDelete.customAppearance = appearanceDelete
            items.append(itemDelete)
            items.append(ActionSheetCancelButton(title: NSLocalizedString("_cancel_", comment: "")))
            
            let actionSheet = ActionSheet(items: items) { sheet, item in
                if item.value as? Int == 0 { self.restoreItem(with: fileID) }
                if item.value as? Int == 1 { self.deleteItem(with: fileID) }
                if item is ActionSheetCancelButton { print("Cancel buttons has the value `true`") }
            }
            
            let headerView = actionSheetHeader(with: fileID)
            actionSheet.headerView = headerView
            actionSheet.headerView?.frame.size.height = 50
            
            actionSheet.present(in: self, from: sender as! UIButton)
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
                
            case 0: CCUtility.setOrderSettings("fileName"); CCUtility.setAscendingSettings(true)
            case 1: CCUtility.setOrderSettings("fileName"); CCUtility.setAscendingSettings(false)
                
            case 2: CCUtility.setOrderSettings("date"); CCUtility.setAscendingSettings(false)
            case 3: CCUtility.setOrderSettings("date"); CCUtility.setAscendingSettings(true)
                
            case 4: CCUtility.setOrderSettings("size"); CCUtility.setAscendingSettings(true)
            case 5: CCUtility.setOrderSettings("size"); CCUtility.setAscendingSettings(false)
                
            default: print("")
            }
            
            datasourceSorted = CCUtility.getOrderSettings()
            datasourceAscending = CCUtility.getAscendingSettings()
            
            guard let datasource = NCManageDatabase.sharedInstance.getTrash(filePath: path, sorted: datasourceSorted, ascending: datasourceAscending) else {
                return
            }
            
            self.datasource = datasource
            collectionView.reloadData()
        }
        
        if dropdownMenu.token == "tapMoreHeaderMenu" {
        
            // Select
            if indexPath.row == 0 {
                isEditMode = true
                collectionView.reloadData()
            }
            
            // Restore ALL
            if indexPath.row == 1 {
                for record: tableTrash in self.datasource {
                    restoreItem(with: record.fileID)
                }
            }
            
            // Delete ALL
            if indexPath.row == 2 {
                
                var items = [ActionSheetItem]()
                
                items.append(ActionSheetTitle(title: NSLocalizedString("_trash_delete_all_", comment: "")))
                items.append(ActionSheetDangerButton(title: NSLocalizedString("_delete_", comment: "")))
                items.append(ActionSheetCancelButton(title: NSLocalizedString("_cancel_", comment: "")))
                
                let actionSheet = ActionSheet(items: items) { sheet, item in
                    if item is ActionSheetDangerButton {
                        for record: tableTrash in self.datasource {
                            self.deleteItem(with: record.fileID)
                        }
                    }
                    if item is ActionSheetCancelButton { return }
                }
                
                actionSheet.present(in: self, from: self.view)
            }
        }
        
        if dropdownMenu.token == "tapMoreHeaderMenuSelect" {
            
            // Cancel
            if indexPath.row == 0 {
                isEditMode = false
                selectFileID.removeAll()
                collectionView.reloadData()
            }
            
            // Restore selected files
            if indexPath.row == 1 {
                for fileID in selectFileID {
                    restoreItem(with: fileID)
                }
                isEditMode = false
                selectFileID.removeAll()
                collectionView.reloadData()
            }
            
            // Delete selected files
            if indexPath.row == 2 {
                
                var items = [ActionSheetItem]()
                
                items.append(ActionSheetTitle(title: NSLocalizedString("_trash_delete_selected_", comment: "")))
                items.append(ActionSheetDangerButton(title: NSLocalizedString("_delete_", comment: "")))
                items.append(ActionSheetCancelButton(title: NSLocalizedString("_cancel_", comment: "")))
                
                let actionSheet = ActionSheet(items: items) { sheet, item in
                    if item is ActionSheetDangerButton {
                        for fileID in self.selectFileID {
                            self.deleteItem(with: fileID)
                        }
                        self.isEditMode = false
                        self.selectFileID.removeAll()
                        self.collectionView.reloadData()
                    }
                    if item is ActionSheetCancelButton { return }
                }
                
                actionSheet.present(in: self, from: self.view)
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
    
    // MARK: NC API
    
    @objc func loadListingTrash() {
        
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        ocNetworking?.listingTrash(appDelegate.activeUrl, path:path, account: appDelegate.activeAccount, success: { (item) in
            
            self.refreshControl.endRefreshing()

            NCManageDatabase.sharedInstance.deleteTrash(filePath: self.path)
            NCManageDatabase.sharedInstance.addTrashs(item as! [tableTrash])
            
            let results = NCManageDatabase.sharedInstance.getTrash(filePath: self.path, sorted: self.datasourceSorted, ascending: self.datasourceAscending)
            if (results != nil) {
                self.datasource = results!
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.collectionView.reloadData()
                }
            }
            
        }, failure: { (message, errorCode) in
            
            self.refreshControl.endRefreshing()
            print("error " + message!)
        })
    }
    
    func restoreItem(with fileID: String) {
        
        guard let tableTrash = NCManageDatabase.sharedInstance.getTrashItem(fileID: fileID) else {
            return
        }
        
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
                
        let fileName = appDelegate.activeUrl + tableTrash.filePath + tableTrash.fileName
        let fileNameTo = appDelegate.activeUrl + k_dav + "/trashbin/" + appDelegate.activeUserID + "/restore/" + tableTrash.fileName
        
        ocNetworking?.moveFileOrFolder(fileName, fileNameTo: fileNameTo, success: {
            
            NCManageDatabase.sharedInstance.deleteTrash(fileID: fileID)
            guard let datasource = NCManageDatabase.sharedInstance.getTrash(filePath: self.path, sorted: self.datasourceSorted, ascending: self.datasourceAscending) else {
                return
            }
            self.datasource = datasource
            self.collectionView.reloadData()
            
        }, failure: { (message, errorCode) in
            
            self.appDelegate.messageNotification("_error_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        })
    }
    
    func deleteItem(with fileID: String) {
        
        guard let tableTrash = NCManageDatabase.sharedInstance.getTrashItem(fileID: fileID) else {
            return
        }
        
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        let path = appDelegate.activeUrl + tableTrash.filePath + tableTrash.fileName

        ocNetworking?.deleteFileOrFolder(path, completion: { (message, errorCode) in
            
            if errorCode == 0 {
                
                NCManageDatabase.sharedInstance.deleteTrash(fileID: fileID)
                guard let datasource = NCManageDatabase.sharedInstance.getTrash(filePath: self.path, sorted: self.datasourceSorted, ascending: self.datasourceAscending) else {
                    return
                }
                self.datasource = datasource
                self.collectionView.reloadData()
                
            } else {
                
                self.appDelegate.messageNotification("_error_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            }
        })
    }
    
    func downloadThumbnail(with tableTrash: tableTrash, indexPath: IndexPath) {
                
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        ocNetworking?.downloadPreviewTrash(withFileID: tableTrash.fileID, fileName: tableTrash.fileName, completion: { (message, errorCode) in
            if errorCode == 0 && CCUtility.fileProviderStorageIconExists(tableTrash.fileID, fileNameView: tableTrash.fileName) {
                self.collectionView.reloadItems(at: [indexPath])
            }
        })
    }
    
    // MARK: COLLECTIONVIEW METHODS
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            
            let trashHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "headerMenu", for: indexPath) as! NCTrashHeaderMenu
            
            if collectionView.collectionViewLayout == gridLayout {
                trashHeader.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
            } else {
                trashHeader.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchGrid"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
            }
            
            trashHeader.delegate = self
            
            if self.datasource.count == 0 {
                trashHeader.buttonSwitch.isEnabled = false
                trashHeader.buttonOrder.isEnabled = false
                trashHeader.buttonMore.isEnabled = false
            } else {
                trashHeader.buttonSwitch.isEnabled = true
                trashHeader.buttonOrder.isEnabled = true
                trashHeader.buttonMore.isEnabled = true
            }
            
            // Order (∨∧▽△)
            var title = ""
            
            switch datasourceSorted {
            case "fileName":
                if datasourceAscending == true { title = NSLocalizedString("_order_by_name_a_z_", comment: "") }
                if datasourceAscending == false { title = NSLocalizedString("_order_by_name_z_a_", comment: "") }
            case "date":
                if datasourceAscending == false { title = NSLocalizedString("_order_by_date_more_recent_", comment: "") }
                if datasourceAscending == true { title = NSLocalizedString("_order_by_date_less_recent_", comment: "") }
            case "size":
                if datasourceAscending == true { title = NSLocalizedString("_order_by_size_smallest_", comment: "") }
                if datasourceAscending == false { title = NSLocalizedString("_order_by_size_largest_", comment: "") }
            default:
                title = NSLocalizedString("_order_by_", comment: "") + " " + datasourceSorted
            }
            
            trashHeader.buttonOrder.setTitle(title + "  ▽", for: .normal)
            
            return trashHeader
            
        } else {
            
            let trashFooter = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "footerMenu", for: indexPath) as! NCTrashFooterMenu
            
            trashFooter.labelFooter.textColor = NCBrandColor.sharedInstance.icon
            
            var folders: Int = 0, foldersText = ""
            var files: Int = 0, filesText = ""
            var size: Double = 0
            
            for record: tableTrash in self.datasource {
                if record.directory {
                    folders += 1
                } else {
                    files += 1
                    size = size + record.size
                }
            }
            
            if folders > 1 {
                foldersText = "\(folders) " + NSLocalizedString("_folders_", comment: "")
            } else if folders == 1 {
                foldersText = "1 " + NSLocalizedString("_folder_", comment: "")
            }
            
            if files > 1 {
                filesText = "\(files) " + NSLocalizedString("_files_", comment: "") + " " + CCUtility.transformedSize(size)
            } else if files == 1 {
                filesText = "1 " + NSLocalizedString("_file_", comment: "") + " " + CCUtility.transformedSize(size)
            }
           
            if foldersText == "" {
                trashFooter.labelFooter.text = filesText
            } else if filesText == "" {
                trashFooter.labelFooter.text = foldersText
            } else {
                trashFooter.labelFooter.text = foldersText + ", " + filesText
            }
            
            return trashFooter
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: highHeader)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: highHeader)
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
        
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconFileID(tableTrash.fileID, fileNameView: tableTrash.fileName)) {
            image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(tableTrash.fileID, fileNameView: tableTrash.fileName))
        } else {
            if tableTrash.thumbnailExists && !CCUtility.fileProviderStorageIconExists(tableTrash.fileID, fileNameView: tableTrash.fileName) {
                downloadThumbnail(with: tableTrash, indexPath: indexPath)
            }
        }
        
        if collectionView.collectionViewLayout == listLayout {
            
            // LIST
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell-list", for: indexPath) as! NCTrashListCell
            cell.delegate = self
            
            cell.fileID = tableTrash.fileID
            cell.indexPath = indexPath
            cell.labelTitle.text = tableTrash.trashbinFileName
            
            if tableTrash.directory {
                cell.imageItem.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                cell.labelInfo.text = CCUtility.dateDiff(tableTrash.date as Date)
            } else {
                cell.imageItem.image = image
                cell.labelInfo.text = CCUtility.dateDiff(tableTrash.date as Date) + " " + CCUtility.transformedSize(tableTrash.size)
            }
            
            if isEditMode {
                cell.imageItemLeftConstraint.constant = 45
                cell.imageSelect.isHidden = false
                
                if selectFileID.contains(tableTrash.fileID) {
                    cell.imageSelect.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "checkedYes"), multiplier: 2, color: NCBrandColor.sharedInstance.brand)
                    cell.backgroundView = cellBlurEffect(with: cell.bounds)
                } else {
                    cell.imageSelect.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "checkedNo"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell-grid", for: indexPath) as! NCTrashGridCell
            cell.delegate = self
            
            cell.fileID = tableTrash.fileID
            cell.indexPath = indexPath
            cell.labelTitle.text = tableTrash.trashbinFileName
            
            if tableTrash.directory {
                cell.imageItem.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
            } else {
                cell.imageItem.image = image
            }
            
            if isEditMode {
                cell.imageSelect.isHidden = false
                if selectFileID.contains(tableTrash.fileID) {
                    cell.imageSelect.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "checkedYes"), multiplier: 2, color: UIColor.white)
                    cell.backgroundView = cellBlurEffect(with: cell.bounds)
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let tableTrash = datasource[indexPath.item]

        if isEditMode {
            if let index = selectFileID.index(of: tableTrash.fileID) {
                selectFileID.remove(at: index)
            } else {
                selectFileID.append(tableTrash.fileID)
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
    
    // MARK: UTILITY
    
    private func cellBlurEffect(with frame: CGRect) -> UIView {
        
        let blurEffect = UIBlurEffect(style: .extraLight)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        blurEffectView.frame = frame
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.backgroundColor = NCBrandColor.sharedInstance.brand.withAlphaComponent(0.2)
        
        return blurEffectView
    }
    
    private func actionSheetHeader(with fileID: String) -> UIView? {
        
        var image: UIImage?

        guard let tableTrash = NCManageDatabase.sharedInstance.getTrashItem(fileID: fileID) else {
            return nil
        }
        
        // Header
        if tableTrash.iconName.count > 0 {
            image = UIImage.init(named: tableTrash.iconName)
        } else {
            image = UIImage.init(named: "file")
        }
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconFileID(tableTrash.fileID, fileNameView: tableTrash.fileName)) {
            image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(tableTrash.fileID, fileNameView: tableTrash.fileName))
        }
        
        let headerView = UINib(nibName: "NCActionSheetHeaderView", bundle: nil).instantiate(withOwner: self, options: nil).first as! NCActionSheetHeaderView
        headerView.imageItem.image = image
        headerView.label.text = tableTrash.trashbinFileName
        headerView.label.textColor = NCBrandColor.sharedInstance.icon
        
        return headerView
    }
}

class ListLayout: UICollectionViewFlowLayout {
    
    let itemHeight: CGFloat = 60
    
    override init() {
        super.init()
        
        minimumInteritemSpacing = 0
        minimumLineSpacing = 1
        
        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                let itemWidth: CGFloat = collectionView.frame.width
                return CGSize(width: itemWidth, height: self.itemHeight)
            }
            
            // Default fallback
            return CGSize(width: 100, height: 100)
        }
        set {
            super.itemSize = newValue
        }
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
}

class GridLayout: UICollectionViewFlowLayout {
    
    let heightLabelPlusButton: CGFloat = 45

    override init() {
        super.init()
        
        minimumInteritemSpacing = 0
        minimumLineSpacing = 1

        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                
                let itemWidth: CGFloat = (collectionView.frame.width/CGFloat(collectionView.bounds.width / 90.0))
                let itemHeight: CGFloat = itemWidth + heightLabelPlusButton
                return CGSize(width: itemWidth, height: itemHeight)
            }
            
            // Default fallback
            return CGSize(width: 100, height: 100)
        }
        set {
            super.itemSize = newValue
        }
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
}
