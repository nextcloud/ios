//
//  NCOffline.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/10/2018.
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

class NCOffline: UIViewController ,UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, NCOfflineListCellDelegate, NCOfflineGridCellDelegate, NCOfflineHeaderMenuDelegate, DropdownMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate  {
    
    @IBOutlet fileprivate weak var collectionView: UICollectionView!

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var titleCurrentFolder = NSLocalizedString("_manage_file_offline_", comment: "")
    var directoryID = ""
    var datasource = [tableMetadata]()
    var datasourceSorted = ""
    var datasourceAscending = true
    var isEditMode = false
    var selectFileID = [String]()
    
    var listLayout: ListLayoutOffline!
    var gridLayout: GridLayoutOffline!
    
    private let highHeader: CGFloat = 50
    
    private let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.register(UINib.init(nibName: "NCOfflineListCell", bundle: nil), forCellWithReuseIdentifier: "cell-list")
        collectionView.register(UINib.init(nibName: "NCOfflineGridCell", bundle: nil), forCellWithReuseIdentifier: "cell-grid")
        
        collectionView.alwaysBounceVertical = true

        listLayout = ListLayoutOffline()
        gridLayout = GridLayoutOffline()
        
        if CCUtility.getLayoutOffline() == "list" {
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
        refreshControl.addTarget(self, action: #selector(loadDatasource(withSynchronized:)), for: .valueChanged)
        
        // empty Data Source
        self.collectionView.emptyDataSetDelegate = self;
        self.collectionView.emptyDataSetSource = self;        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.title = titleCurrentFolder

        datasourceSorted = CCUtility.getOrderSettings()
        datasourceAscending = CCUtility.getAscendingSettings()
        
        loadDatasource(withSynchronized: false)
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
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "filesNoFiles"), multiplier: 2, color: NCBrandColor.sharedInstance.brandElement)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n"+NSLocalizedString("_files_no_files_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    /*
    func description(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n"+NSLocalizedString("_no_file_pull_down_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    */
    
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
            CCUtility.setLayoutOffline("list")
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                    self.collectionView.setContentOffset(CGPoint(x:0,y:0), animated: false)
                })
            })
            CCUtility.setLayoutOffline("grid")
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
        
        let header = (sender as? UIButton)?.superview as! NCOfflineHeaderMenu
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
        
        let header = (sender as? UIButton)?.superview as! NCOfflineHeaderMenu
        let headerRect = self.collectionView.convert(header.bounds, from: self.view)
        let menuOffsetY =  headerRect.height - headerRect.origin.y - 2
        menuView?.topOffsetY = CGFloat(menuOffsetY)
        
        menuView?.showMenu()
    }
    
    func tapMoreItem(with fileID: String, sender: Any) {
        tapMoreGridItem(with: fileID, sender: sender)
    }
    
    func tapMoreGridItem(with fileID: String, sender: Any) {
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileID)) else {
            return
        }
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            return
        }
        
        if !isEditMode {
            
            var items = [ActionSheetItem]()
            let appearanceDelete = ActionSheetItemAppearance.init()
            appearanceDelete.textColor = UIColor.red
            
            if (metadata.directory == false || serverUrl == CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl)) {
                items.append(ActionSheetItem(title: NSLocalizedString("_remove_available_offline_", comment: ""), value: 0, image: CCGraphics.changeThemingColorImage(UIImage.init(named: "offline"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)))
            }
            items.append(ActionSheetItem(title: NSLocalizedString("_share_", comment: ""), value: 1, image: CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)))

            let itemDelete = ActionSheetItem(title: NSLocalizedString("_delete_", comment: ""), value: 2, image: CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), multiplier: 2, color: UIColor.red))
            itemDelete.customAppearance = appearanceDelete
            items.append(itemDelete)
            items.append(ActionSheetCancelButton(title: NSLocalizedString("_cancel_", comment: "")))
            
            let actionSheet = ActionSheet(items: items) { sheet, item in
                if item.value as? Int == 0 {
                    if metadata.directory {
                        NCManageDatabase.sharedInstance.setDirectory(serverUrl: CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)!, offline: false)
                    } else {
                        NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, offline: false)
                    }
                    self.loadDatasource(withSynchronized: false)
                }
                if item.value as? Int == 1 { self.appDelegate.activeMain.openWindowShare(metadata) }
                if item.value as? Int == 2 {  }
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
            
            loadDatasource(withSynchronized: false)
        }
        
        if dropdownMenu.token == "tapMoreHeaderMenu" {
        
        }
        
        if dropdownMenu.token == "tapMoreHeaderMenuSelect" {
            
        }
    }
    
    // MARK: NC API
    
    func downloadThumbnail(with tableMetadata: tableMetadata, indexPath: IndexPath) {
                
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        ocNetworking?.downloadPreviewTrash(withFileID: tableMetadata.fileID, fileName: tableMetadata.fileName, completion: { (message, errorCode) in
            if errorCode == 0 && CCUtility.fileProviderStorageIconExists(tableMetadata.fileID, fileNameView: tableMetadata.fileName) {
                self.collectionView.reloadItems(at: [indexPath])
            }
        })
    }
    
    // MARK: DATASOURCE
    @objc func loadDatasource(withSynchronized: Bool = false) {
        
        datasource.removeAll()
        
        if directoryID == "" {
        
            let directories = NCManageDatabase.sharedInstance.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", appDelegate.activeAccount), sorted: "serverUrl", ascending: true)
            if directories != nil {
                for directory: tableDirectory in directories! {
                    guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", directory.fileID)) else {
                        continue
                    }
                    datasource.append(metadata)
                }
            }
            
            let files = NCManageDatabase.sharedInstance.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", appDelegate.activeAccount), sorted: "fileName", ascending: true)
            if files != nil {
                for file: tableLocalFile in files! {
                    guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", file.fileID)) else {
                        continue
                    }
                    datasource.append(metadata)
                }
            }
            
        } else {
        
            if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND directoryID == %@", appDelegate.activeAccount, directoryID), sorted: self.datasourceSorted, ascending: self.datasourceAscending)  {
                
                datasource = metadatas
            }
        }
        
        collectionView.reloadData()
    }
    
    // MARK: COLLECTIONVIEW METHODS
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            
            let offlineHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "headerMenu", for: indexPath) as! NCOfflineHeaderMenu
            
            if collectionView.collectionViewLayout == gridLayout {
                offlineHeader.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
            } else {
                offlineHeader.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchGrid"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
            }
            
            offlineHeader.delegate = self
            
            if self.datasource.count == 0 {
                offlineHeader.buttonSwitch.isEnabled = false
                offlineHeader.buttonOrder.isEnabled = false
                offlineHeader.buttonMore.isEnabled = false
            } else {
                offlineHeader.buttonSwitch.isEnabled = true
                offlineHeader.buttonOrder.isEnabled = true
                offlineHeader.buttonMore.isEnabled = true
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
            
            title = title + "  ▽"
            let size = title.size(withAttributes:[.font: offlineHeader.buttonOrder.titleLabel?.font as Any])
            
            offlineHeader.buttonOrder.setTitle(title, for: .normal)
            offlineHeader.buttonOrderWidthConstraint.constant = size.width + 5
            
            return offlineHeader
            
        } else {
            
            let offlineFooter = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "footerMenu", for: indexPath) as! NCOfflineFooterMenu
            
            offlineFooter.labelFooter.textColor = NCBrandColor.sharedInstance.icon
            
            var folders: Int = 0, foldersText = ""
            var files: Int = 0, filesText = ""
            var size: Double = 0
            
            for record: tableMetadata in self.datasource {
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
                offlineFooter.labelFooter.text = filesText
            } else if filesText == "" {
                offlineFooter.labelFooter.text = foldersText
            } else {
                offlineFooter.labelFooter.text = foldersText + ", " + filesText
            }
            
            return offlineFooter
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
        
        let tableMetadata = datasource[indexPath.item]
        var image: UIImage?
        
        if tableMetadata.iconName.count > 0 {
            image = UIImage.init(named: tableMetadata.iconName)
        } else {
            image = UIImage.init(named: "file")
        }
        
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconFileID(tableMetadata.fileID, fileNameView: tableMetadata.fileName)) {
            image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(tableMetadata.fileID, fileNameView: tableMetadata.fileName))
        } else {
            if tableMetadata.thumbnailExists && !CCUtility.fileProviderStorageIconExists(tableMetadata.fileID, fileNameView: tableMetadata.fileName) {
                downloadThumbnail(with: tableMetadata, indexPath: indexPath)
            }
        }
        
        if collectionView.collectionViewLayout == listLayout {
            
            // LIST
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell-list", for: indexPath) as! NCOfflineListCell
            cell.delegate = self
            
            cell.fileID = tableMetadata.fileID
            cell.indexPath = indexPath
            cell.labelTitle.text = tableMetadata.fileNameView
            
            if tableMetadata.directory {
                cell.imageItem.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                cell.labelInfo.text = CCUtility.dateDiff(tableMetadata.date as Date)
            } else {
                cell.imageItem.image = image
                cell.labelInfo.text = CCUtility.dateDiff(tableMetadata.date as Date) + " " + CCUtility.transformedSize(tableMetadata.size)
            }
            
            if isEditMode {
                cell.imageItemLeftConstraint.constant = 45
                cell.imageSelect.isHidden = false
                
                if selectFileID.contains(tableMetadata.fileID) {
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell-grid", for: indexPath) as! NCOfflineGridCell
            cell.delegate = self
            
            cell.fileID = tableMetadata.fileID
            cell.indexPath = indexPath
            cell.labelTitle.text = tableMetadata.fileNameView
            
            if tableMetadata.directory {
                cell.imageItem.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
            } else {
                cell.imageItem.image = image
            }
            
            if isEditMode {
                cell.imageSelect.isHidden = false
                if selectFileID.contains(tableMetadata.fileID) {
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
        
        let metadata = datasource[indexPath.item]

        if isEditMode {
            if let index = selectFileID.index(of: metadata.fileID) {
                selectFileID.remove(at: index)
            } else {
                selectFileID.append(metadata.fileID)
            }
            collectionView.reloadItems(at: [indexPath])
            return
        }
        
        if metadata.directory {
        
            let ncOffline:NCOffline = UIStoryboard(name: "NCOffline", bundle: nil).instantiateInitialViewController() as! NCOffline
            guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                return
            }
            let serverUrlPush = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)
            guard let directoryIDPush = NCManageDatabase.sharedInstance.getDirectoryID(serverUrlPush) else {
                return
            }
            ncOffline.directoryID = directoryIDPush
            ncOffline.titleCurrentFolder = metadata.fileNameView
            self.navigationController?.pushViewController(ncOffline, animated: true)
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

class ListLayoutOffline: UICollectionViewFlowLayout {
    
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

class GridLayoutOffline: UICollectionViewFlowLayout {
    
    let heightLabelPlusButton: CGFloat = 45
    let preferenceWidth: CGFloat = 110
    let marginLeftRight: CGFloat = 5
    
    override init() {
        super.init()
        
        minimumInteritemSpacing = 1
        minimumLineSpacing = 1

        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 10, left: marginLeftRight, bottom: 10, right:  marginLeftRight)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                
                let numItems: Int = Int(collectionView.frame.width / preferenceWidth)                
                let itemWidth: CGFloat = (collectionView.frame.width - (marginLeftRight * 2) - CGFloat(numItems)) / CGFloat(numItems)
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
