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

class NCOffline: UIViewController ,UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, DropdownMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate  {
    
    @IBOutlet fileprivate weak var collectionView: UICollectionView!

    var titleCurrentFolder = NSLocalizedString("_manage_file_offline_", comment: "")
    var directoryID = ""
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
   
    private var isEditMode = false
    private var selectFileID = [String]()
    
    private var sectionDatasource = CCSectionDataSourceMetadata()
    
    private var datasourceSorted = ""
    private var datasourceAscending = true
    private var datasourceGroupBy = ""
    private var datasourceDirectoryOnTop = false
    
    private var listLayout: NCListLayout!
    private var gridLayout: NCGridLayout!
    
    private var actionSheet: ActionSheet?
    
    private let headerMenuHeight: CGFloat = 50
    private let sectionHeaderHeight: CGFloat = 20
    private let footerHeight: CGFloat = 50

    private let refreshControl = UIRefreshControl()
    
    private var metadataSelect = tableMetadata()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib.init(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header
        collectionView.register(UINib.init(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        collectionView.register(UINib.init(nibName: "NCSectionHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeader")
        
        // Footer
        collectionView.register(UINib.init(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        
        collectionView.alwaysBounceVertical = true

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()
        
        // Add Refresh Control
        if #available(iOS 10.0, *) {
            collectionView.refreshControl = refreshControl
        } else {
            collectionView.addSubview(refreshControl)
        }
        
        // Configure Refresh Control
        refreshControl.tintColor = NCBrandColor.sharedInstance.brandText
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.brand
        refreshControl.addTarget(self, action: #selector(loadDatasource), for: .valueChanged)
        
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
        datasourceGroupBy = CCUtility.getGroupBySettings()
        datasourceDirectoryOnTop = CCUtility.getDirectoryOnTop()
        
        if CCUtility.getLayoutOffline() == "list" {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }
        
        loadDatasource()
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
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "filesNoFiles"), multiplier: 2, color: NCBrandColor.sharedInstance.brandElement)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n"+NSLocalizedString("_files_no_files_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }

    // MARK: TAP EVENT
    
    func tapSwitchHeader(sender: Any) {
        
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
    
    func tapOrderHeader(sender: Any) {
        
        var menuView: DropdownMenu?
        var selectedIndexPath = [IndexPath()]
        
        let item1 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortFileNameAZ"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_name_a_z_", comment: ""))
        let item2 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortFileNameZA"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_name_z_a_", comment: ""))
        let item3 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortDateMoreRecent"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_date_more_recent_", comment: ""))
        let item4 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortDateLessRecent"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_date_less_recent_", comment: ""))
        let item5 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortSmallest"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_size_smallest_", comment: ""))
        let item6 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "sortLargest"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_order_by_size_largest_", comment: ""))
        
        switch datasourceSorted {
        case "fileName":
            if datasourceAscending == true { item1.style = .highlight; selectedIndexPath.append(IndexPath(row: 0, section: 0)) }
            if datasourceAscending == false { item2.style = .highlight; selectedIndexPath.append(IndexPath(row: 1, section: 0)) }
        case "date":
            if datasourceAscending == false { item3.style = .highlight; selectedIndexPath.append(IndexPath(row: 2, section: 0)) }
            if datasourceAscending == true { item4.style = .highlight; selectedIndexPath.append(IndexPath(row: 3, section: 0)) }
        case "size":
            if datasourceAscending == true { item5.style = .highlight; selectedIndexPath.append(IndexPath(row: 4, section: 0)) }
            if datasourceAscending == false { item6.style = .highlight; selectedIndexPath.append(IndexPath(row: 5, section: 0)) }
        default:
            ()
        }
        
        let item7 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "MenuGroupByAlphabetic"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_group_alphabetic_no_", comment: ""))
        let item8 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "MenuGroupByFile"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_group_typefile_no_", comment: ""))
        let item9 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "MenuGroupByDate"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_group_date_no_", comment: ""))
        
        switch datasourceGroupBy {
        case "alphabetic":
            item7.style = .highlight; selectedIndexPath.append(IndexPath(row: 0, section: 1))
        case "typefile":
            item8.style = .highlight; selectedIndexPath.append(IndexPath(row: 1, section: 1))
        case "date":
            item9.style = .highlight; selectedIndexPath.append(IndexPath(row: 2, section: 1))
        default:
            ()
        }
        
        let item10 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "foldersOnTop"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title: NSLocalizedString("_directory_on_top_no_", comment: ""))
        
        if datasourceDirectoryOnTop {
            item10.style = .highlight; selectedIndexPath.append(IndexPath(row: 0, section: 2))
        }
        
        let sectionOrder = DropdownSection(sectionIdentifier: "", items: [item1, item2, item3, item4, item5, item6])
        let sectionGroupBy = DropdownSection(sectionIdentifier: "", items: [item7, item8, item9])
        let sectionFolderOnTop = DropdownSection(sectionIdentifier: "", items: [item10])
        
        menuView = DropdownMenu(navigationController: self.navigationController!, sections: [sectionOrder, sectionGroupBy, sectionFolderOnTop], selectedIndexPath: selectedIndexPath)
        menuView?.token = "tapOrderHeaderMenu"
        menuView?.delegate = self
        menuView?.rowHeight = 45
        menuView?.sectionHeaderHeight = 8
        menuView?.highlightColor = NCBrandColor.sharedInstance.brand
        menuView?.tableView.alwaysBounceVertical = false
        menuView?.tableViewBackgroundColor = UIColor.white
        
        let header = (sender as? UIButton)?.superview
        let headerRect = self.collectionView.convert(header!.bounds, from: self.view)
        let menuOffsetY =  headerRect.height - headerRect.origin.y - 2
        menuView?.topOffsetY = CGFloat(menuOffsetY)
        
        menuView?.showMenu()
    }
    
    func tapMoreHeader(sender: Any) {
        
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
            
            actionSheet = ActionSheet(items: items) { sheet, item in
                if item.value as? Int == 0 {
                    if metadata.directory {
                        NCManageDatabase.sharedInstance.setDirectory(serverUrl: CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)!, offline: false)
                    } else {
                        NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, offline: false)
                    }
                    self.loadDatasource()
                }
                if item.value as? Int == 1 { self.appDelegate.activeMain.openWindowShare(metadata) }
                if item.value as? Int == 2 { self.deleteItem(with: metadata, sender: sender) }
                if item is ActionSheetCancelButton { print("Cancel buttons has the value `true`") }
            }
            
            let headerView = actionSheetHeader(with: metadata)
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
            
            switch indexPath.section {
            
            case 0: switch indexPath.row {
                    
                    case 0: CCUtility.setOrderSettings("fileName"); CCUtility.setAscendingSettings(true)
                    case 1: CCUtility.setOrderSettings("fileName"); CCUtility.setAscendingSettings(false)
                
                    case 2: CCUtility.setOrderSettings("date"); CCUtility.setAscendingSettings(false)
                    case 3: CCUtility.setOrderSettings("date"); CCUtility.setAscendingSettings(true)
                
                    case 4: CCUtility.setOrderSettings("size"); CCUtility.setAscendingSettings(true)
                    case 5: CCUtility.setOrderSettings("size"); CCUtility.setAscendingSettings(false)
                
                    default: ()
                    }
            case 1: switch indexPath.row {
                
                    case 0:
                    if datasourceGroupBy == "alphabetic" {
                        CCUtility.setGroupBySettings("none")
                    } else {
                        CCUtility.setGroupBySettings("alphabetic")
                    }
                    case 1:
                    if datasourceGroupBy == "typefile" {
                        CCUtility.setGroupBySettings("none")
                    } else {
                        CCUtility.setGroupBySettings("typefile")
                    }
                    case 2:
                    if datasourceGroupBy == "date" {
                        CCUtility.setGroupBySettings("none")
                    } else {
                        CCUtility.setGroupBySettings("date")
                    }
    
                    default: ()
                    }
            case 2: if datasourceDirectoryOnTop {
                        CCUtility.setDirectoryOnTop(false)
                    } else {
                        CCUtility.setDirectoryOnTop(true)
                    }
            default: ()
            }
            
            datasourceAscending = CCUtility.getAscendingSettings()
            datasourceSorted = CCUtility.getOrderSettings()
            datasourceGroupBy = CCUtility.getGroupBySettings()
            datasourceDirectoryOnTop = CCUtility.getDirectoryOnTop()
            
            loadDatasource()
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
    
    func deleteItem(with metadata: tableMetadata, sender: Any) {
        
        var items = [ActionSheetItem]()
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            return
        }
        guard let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == serverUrl", appDelegate.activeAccount, serverUrl)) else {
            return
        }
        
        items.append(ActionSheetDangerButton(title: NSLocalizedString("_delete_", comment: "")))
        items.append(ActionSheetCancelButton(title: NSLocalizedString("_cancel_", comment: "")))
        
        actionSheet = ActionSheet(items: items) { sheet, item in
            if item is ActionSheetDangerButton {
                NCMainCommon.sharedInstance.deleteFile(metadatas: [metadata], e2ee: tableDirectory.e2eEncrypted, serverUrl: serverUrl, folderFileID: tableDirectory.fileID) { (errorCode, message) in
                    self.loadDatasource()
                }
            }
            if item is ActionSheetCancelButton { print("Cancel buttons has the value `true`") }
        }
        
        let headerView = actionSheetHeader(with: metadata)
        actionSheet?.headerView = headerView
        actionSheet?.headerView?.frame.size.height = 50
        
        actionSheet?.present(in: self, from: sender as! UIButton)
    }
    
    // MARK: DATASOURCE
    @objc func loadDatasource() {
        
        var fileIDs = [String]()
        sectionDatasource = CCSectionDataSourceMetadata()

        if directoryID == "" {
        
            if let directories = NCManageDatabase.sharedInstance.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", appDelegate.activeAccount), sorted: "serverUrl", ascending: true) {
                for directory: tableDirectory in directories {
                    fileIDs.append(directory.fileID)
                }
            }
          
            if let files = NCManageDatabase.sharedInstance.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", appDelegate.activeAccount), sorted: "fileName", ascending: true) {
                for file: tableLocalFile in files {
                    fileIDs.append(file.fileID)
                }
            }
            
            if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND fileID IN %@", appDelegate.activeAccount, fileIDs), sorted: datasourceSorted, ascending: datasourceAscending)  {

                sectionDatasource = CCSectionMetadata.creataDataSourseSectionMetadata(metadatas, listProgressMetadata: nil, groupByField: datasourceGroupBy, filterFileID: nil, filterTypeFileImage: false, filterTypeFileVideo: false, activeAccount: appDelegate.activeAccount)
            }
            
        } else {
        
            if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND directoryID == %@", appDelegate.activeAccount, directoryID), sorted: datasourceSorted, ascending: datasourceAscending)  {
                
                sectionDatasource = CCSectionMetadata.creataDataSourseSectionMetadata(metadatas, listProgressMetadata: nil, groupByField: datasourceGroupBy, filterFileID: nil, filterTypeFileImage: false, filterTypeFileVideo: false, activeAccount: appDelegate.activeAccount)
            }
        }
        
        self.refreshControl.endRefreshing()
        
        collectionView.reloadData()
    }
    
    // MARK: COLLECTIONVIEW METHODS
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if (indexPath.section == 0) {
            
            if kind == UICollectionView.elementKindSectionHeader {
                
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCSectionHeaderMenu
                
                if collectionView.collectionViewLayout == gridLayout {
                    header.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
                } else {
                    header.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchGrid"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
                }
                
                header.delegate = self
                
                header.setStatusButton(count: sectionDatasource.allFileID.count)
                header.setTitleOrder(datasourceSorted: datasourceSorted, datasourceAscending: datasourceAscending)
                
                if datasourceGroupBy == "none" {
                    header.labelSection.isHidden = true
                    header.labelSectionHeightConstraint.constant = 0
                } else {
                    header.labelSection.isHidden = false
                    header.setTitleLabel(sectionDatasource: sectionDatasource, section: indexPath.section)
                    header.labelSectionHeightConstraint.constant = sectionHeaderHeight
                }
         
                return header
            
            } else {
                
                let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
                
                footer.setTitleLabel(sectionDatasource: sectionDatasource)
                
                return footer
            }
            
        } else {
        
            if kind == UICollectionView.elementKindSectionHeader {
                
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as! NCSectionHeader
                
                header.setTitleLabel(sectionDatasource: sectionDatasource, section: indexPath.section)
                
                return header
                
            } else {
                
                let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
                
                footer.setTitleLabel(sectionDatasource: sectionDatasource)

                return footer
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 0 {
            if datasourceGroupBy == "none" {
                return CGSize(width: collectionView.frame.width, height: headerMenuHeight)
            } else {
                return CGSize(width: collectionView.frame.width, height: headerMenuHeight + sectionHeaderHeight)
            }
        } else {
            return CGSize(width: collectionView.frame.width, height: sectionHeaderHeight)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let sections = sectionDatasource.sectionArrayRow.allKeys.count
        if (section == sections - 1) {
            return CGSize(width: collectionView.frame.width, height: footerHeight)
        } else {
            return CGSize(width: collectionView.frame.width, height: 0)
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        let sections = sectionDatasource.sectionArrayRow.allKeys.count
        return sections
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let key = sectionDatasource.sections.object(at: section)
        let datasource = sectionDatasource.sectionArrayRow.object(forKey: key) as! [tableMetadata]
        return datasource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        var image: UIImage?

        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
        }
        
        if metadata.iconName.count > 0 {
            image = UIImage.init(named: metadata.iconName)
        } else {
            image = UIImage.init(named: "file")
        }
        
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileName)) {
            image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileName))
        } else {
            if metadata.thumbnailExists && !CCUtility.fileProviderStorageIconExists(metadata.fileID, fileNameView: metadata.fileName) {
                downloadThumbnail(with: metadata, indexPath: indexPath)
            }
        }
        
        if collectionView.collectionViewLayout == listLayout {
            
            // LIST
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
            cell.delegate = self
            
            cell.fileID = metadata.fileID
            cell.indexPath = indexPath
            cell.labelTitle.text = metadata.fileNameView
            
            if metadata.directory {
                cell.imageItem.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date)
            } else {
                cell.imageItem.image = image
                cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date) + " " + CCUtility.transformedSize(metadata.size)
            }
            
            if isEditMode {
                cell.imageItemLeftConstraint.constant = 45
                cell.imageSelect.isHidden = false
                
                if selectFileID.contains(metadata.fileID) {
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
            
            // Remove last separator
            if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 {
                cell.separator.isHidden = true
            } else {
                cell.separator.isHidden = false
            }
            
            return cell
        
        } else {
            
            // GRID
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
            cell.delegate = self
            
            cell.fileID = metadata.fileID
            cell.indexPath = indexPath
            cell.labelTitle.text = metadata.fileNameView
            
            if metadata.directory {
                cell.imageItem.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
            } else {
                cell.imageItem.image = image
            }
            
            if isEditMode {
                cell.imageSelect.isHidden = false
                if selectFileID.contains(metadata.fileID) {
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
        
        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else {
            return
        }
    
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
            
        } else {
            
            metadataSelect = metadata
            performSegue(withIdentifier: "segueDetail", sender: self)
        }
    }
    
    // MARK: SEGUE
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let photoDataSource: NSMutableArray = []
        
        for fileID: String in sectionDatasource.allFileID as! [String] {
            let metadata = sectionDatasource.allRecordsDataSource.object(forKey: fileID) as! tableMetadata
            if metadata.typeFile == k_metadataTypeFile_image {
                photoDataSource.add(metadata)
            }
        }
        
        if let segueNavigationController = segue.destination as? UINavigationController {
            if let segueViewController = segueNavigationController.topViewController as? CCDetail {
            
                segueViewController.metadataDetail = metadataSelect
                segueViewController.dateFilterQuery = nil
                segueViewController.photoDataSource = photoDataSource
                segueViewController.title = metadataSelect.fileNameView
            }
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
    
    private func actionSheetHeader(with metadata: tableMetadata) -> UIView? {
        
        var image: UIImage?

        // Header
        if metadata.directory {
            image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
        } else if metadata.iconName.count > 0 {
            image = UIImage.init(named: metadata.iconName)
        } else {
            image = UIImage.init(named: "file")
        }
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileNameView)) {
            image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileNameView))
        }
        
        let headerView = UINib(nibName: "NCActionSheetHeaderView", bundle: nil).instantiate(withOwner: self, options: nil).first as! NCActionSheetHeaderView
        
        headerView.imageItem.image = image
        headerView.label.text = metadata.fileNameView
        headerView.label.textColor = NCBrandColor.sharedInstance.icon
        
        return headerView
    }
}
