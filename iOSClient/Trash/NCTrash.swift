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

class NCTrash: UIViewController ,UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, NCTrashListCellDelegate, NCGridCellDelegate, NCTrashHeaderMenuDelegate, DropdownMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate  {
    
    @IBOutlet fileprivate weak var collectionView: UICollectionView!

    var path = ""
    var titleCurrentFolder = NSLocalizedString("_trash_view_", comment: "")
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    private var isEditMode = false
    private var selectFileID = [String]()
    
    private var datasource = [tableTrash]()
    
    private var datasourceSorted = ""
    private var datasourceAscending = true
    
    private var listLayout: NCListLayoutTrash!
    private var gridLayout: NCGridLayoutTrash!
    
    private var actionSheet: ActionSheet?

    private let highHeader: CGFloat = 50
    
    private let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCTrashListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib.init(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header - Footer
        collectionView.register(UINib.init(nibName: "NCTrashHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "headerMenu")
        collectionView.register(UINib.init(nibName: "NCTrashSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")

        collectionView.alwaysBounceVertical = true

        listLayout = NCListLayoutTrash()
        gridLayout = NCGridLayoutTrash()
        
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
        
        // Color
        appDelegate.aspectNavigationControllerBar(self.navigationController?.navigationBar, online: appDelegate.reachability.isReachable(), hidden: false)
        appDelegate.aspectTabBar(self.tabBarController?.tabBar, hidden: false)
        
        self.navigationItem.title = titleCurrentFolder

        datasourceSorted = CCUtility.getOrderSettings()
        datasourceAscending = CCUtility.getAscendingSettings()
        
        if CCUtility.getLayoutTrash() == "list" {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }
        
        loadDatasource()
        loadListingTrash()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.actionSheet?.viewDidLayoutSubviews()
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
        menuView?.rowHeight = 45
        menuView?.highlightColor = NCBrandColor.sharedInstance.brand
        menuView?.tableView.alwaysBounceVertical = false
        menuView?.tableViewBackgroundColor = UIColor.white

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
        menuView?.rowHeight = 45
        menuView?.highlightColor = NCBrandColor.sharedInstance.brand
        menuView?.tableView.alwaysBounceVertical = false
        menuView?.tableViewBackgroundColor = UIColor.white
        
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
            
            actionSheet = ActionSheet(items: items) { sheet, item in
                if item is ActionSheetDangerButton { self.deleteItem(with: fileID) }
                if item is ActionSheetCancelButton { print("Cancel buttons has the value `true`") }
            }
            
            let headerView = actionSheetHeader(with: fileID)
            actionSheet?.headerView = headerView
            actionSheet?.headerView?.frame.size.height = 50
            
            actionSheet?.present(in: self, from: sender as! UIButton)
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
            
            actionSheet = ActionSheet(items: items) { sheet, item in
                if item.value as? Int == 0 { self.restoreItem(with: fileID) }
                if item.value as? Int == 1 { self.deleteItem(with: fileID) }
                if item is ActionSheetCancelButton { print("Cancel buttons has the value `true`") }
            }
            
            let headerView = actionSheetHeader(with: fileID)
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
            
            loadDatasource()
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
                
                actionSheet = ActionSheet(items: items) { sheet, item in
                    if item is ActionSheetDangerButton {
                        for record: tableTrash in self.datasource {
                            self.deleteItem(with: record.fileID)
                        }
                    }
                    if item is ActionSheetCancelButton { return }
                }
                
                actionSheet?.present(in: self, from: self.view)
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
                
                actionSheet = ActionSheet(items: items) { sheet, item in
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
    
    // MARK: NC API
    
    @objc func loadListingTrash() {
        
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        ocNetworking?.listingTrash(appDelegate.activeUrl, path:path, account: appDelegate.activeAccount, success: { (item) in
            
            self.refreshControl.endRefreshing()

            NCManageDatabase.sharedInstance.deleteTrash(filePath: self.path)
            NCManageDatabase.sharedInstance.addTrashs(item as! [tableTrash])
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadDatasource()
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
            
            self.loadDatasource()
            
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
                
                self.loadDatasource()
                
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
    
    // MARK: DATASOURCE
    @objc func loadDatasource() {
        
        datasource.removeAll()
        
        if path == "" {
            let userID = (appDelegate.activeUserID as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlFragmentAllowed)
            path = k_dav + "/trashbin/" + userID! + "/trash/"
        }
        
        guard let tashItems = NCManageDatabase.sharedInstance.getTrash(filePath: path, sorted: datasourceSorted, ascending: datasourceAscending) else {
            return
        }
        
        datasource = tashItems
        
        collectionView.reloadData()
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
            
            trashHeader.setStatusButton(datasource: datasource)
            trashHeader.setTitleOrder(datasourceSorted: datasourceSorted, datasourceAscending: datasourceAscending)
            
            return trashHeader
            
        } else {
            
            let trashFooter = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCTrashSectionFooter
            
            trashFooter.setTitleLabelFooter(datasource: datasource)
            
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCTrashListCell
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
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
        if tableTrash.directory {
            image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
        } else if tableTrash.iconName.count > 0 {
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

