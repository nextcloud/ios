//
//  NCSelect.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/11/2018.
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

@objc protocol NCSelectDelegate {
    @objc func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String)
}

class NCSelect: UIViewController ,UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, DropdownMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    
    @IBOutlet fileprivate weak var collectionView: UICollectionView!
    @IBOutlet fileprivate weak var toolbar: UIToolbar!

    @IBOutlet fileprivate weak var buttonCancel: UIBarButtonItem!
    @IBOutlet fileprivate weak var buttonCreateFolder: UIBarButtonItem!
    @IBOutlet fileprivate weak var buttonDone: UIBarButtonItem!

    // ------ external settings ------------------------------------
    @objc var delegate: NCSelectDelegate?
    
    @objc var hideButtonCreateFolder = false
    @objc var selectFile = false
    @objc var includeDirectoryE2EEncryption = false
    @objc var includeImages = false
    @objc var type = ""
    @objc var titleButtonDone = NSLocalizedString("_move_", comment: "")
    @objc var layoutViewSelect = k_layout_view_move
    
    var titleCurrentFolder = NCBrandOptions.sharedInstance.brand
    var serverUrl = ""
    var directoryID = ""
    // -------------------------------------------------------------
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    private var isEditMode = false
    private var networkInProgress = false
    private var selectFileID = [String]()
    
    private var sectionDatasource = CCSectionDataSourceMetadata()
    
    private var typeLayout = ""
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
        
        // title button
        buttonCancel.title = NSLocalizedString("_cancel_", comment: "")
        buttonCreateFolder.title = NSLocalizedString("_create_folder_", comment: "")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Color
        appDelegate.aspectNavigationControllerBar(self.navigationController?.navigationBar, online: appDelegate.reachability.isReachable(), hidden: false)
        toolbar.barTintColor = NCBrandColor.sharedInstance.tabBar
        toolbar.tintColor = NCBrandColor.sharedInstance.brandElement
        
        self.navigationItem.title = titleCurrentFolder
        
        buttonDone.title = titleButtonDone
        
        if hideButtonCreateFolder {
            buttonCreateFolder.isEnabled = false
            buttonCreateFolder.tintColor = UIColor.clear
        }
        
        (typeLayout, datasourceSorted, datasourceAscending, datasourceGroupBy, datasourceDirectoryOnTop) = NCUtility.sharedInstance.getLayoutForView(key: layoutViewSelect)
        
        if typeLayout == "list" {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }
        
        loadDatasource(withLoadFolder: true)
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
        if networkInProgress {
            return CCGraphics.changeThemingColorImage(UIImage.init(named: "networkInProgress"), multiplier: 2, color: UIColor.lightGray)
        } else {
            return CCGraphics.changeThemingColorImage(UIImage.init(named: "filesNoFiles"), multiplier: 2, color: NCBrandColor.sharedInstance.brandElement)
        }
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        
        if networkInProgress {
            return NSAttributedString.init(string: "\n"+NSLocalizedString("_request_in_progress_", comment: ""), attributes: attributes)
        } else if includeImages {
            return NSAttributedString.init(string: "\n"+NSLocalizedString("_files_no_files_", comment: ""), attributes: attributes)
        } else {
            return NSAttributedString.init(string: "\n"+NSLocalizedString("_files_no_folders_", comment: ""), attributes: attributes)
        }
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    // MARK: ACTION
    
    @IBAction func actionCancel(_ sender: Any) {
        delegate?.dismissSelect(serverUrl: nil, metadata: nil, type: type)
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func actionDone(_ sender: Any) {
        delegate?.dismissSelect(serverUrl: serverUrl, metadata: nil, type: type)
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func actionCreateFolder(_ sender: Any) {
        
        let alertController = UIAlertController(title: NSLocalizedString("_create_folder_", comment: ""), message:"", preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.autocapitalizationType = UITextAutocapitalizationType.words
        }
        
        let actionSave = UIAlertAction(title: NSLocalizedString("_save_", comment: ""), style: .default) { (action:UIAlertAction) in
            if let fileName = alertController.textFields?.first?.text  {
                self.createFolder(with: fileName)
            }
        }
        
        let actionCancel = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { (action:UIAlertAction) in
            print("You've pressed cancel button")
        }
        
        alertController.addAction(actionSave)
        alertController.addAction(actionCancel)
        
        self.present(alertController, animated: true, completion:nil)
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
            typeLayout = "list"
            NCUtility.sharedInstance.setLayoutForView(key: layoutViewSelect, layout: typeLayout, sort: datasourceSorted, ascending: datasourceAscending, groupBy: datasourceGroupBy, directoryOnTop: datasourceDirectoryOnTop)
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                    self.collectionView.setContentOffset(CGPoint(x:0,y:0), animated: false)
                })
            })
            typeLayout = "grid"
            NCUtility.sharedInstance.setLayoutForView(key: layoutViewSelect, layout: typeLayout, sort: datasourceSorted, ascending: datasourceAscending, groupBy: datasourceGroupBy, directoryOnTop: datasourceDirectoryOnTop)
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
    
    func tapMoreListItem(with fileID: String, sender: Any) {
    }
    
    func tapMoreGridItem(with fileID: String, sender: Any) {
    }
    
    // MARK: DROP-DOWN-MENU
    
    func dropdownMenu(_ dropdownMenu: DropdownMenu, didSelectRowAt indexPath: IndexPath) {
        
        if dropdownMenu.token == "tapOrderHeaderMenu" {
            
            switch indexPath.section {
                
            case 0: switch indexPath.row {
                
                    case 0: datasourceSorted = "fileName"; datasourceAscending = true
                    case 1: datasourceSorted = "fileName"; datasourceAscending = false
                
                    case 2: datasourceSorted = "date"; datasourceAscending = false
                    case 3: datasourceSorted = "date"; datasourceAscending = true
                
                    case 4: datasourceSorted = "size"; datasourceAscending = true
                    case 5: datasourceSorted = "size"; datasourceAscending = false
                
                    default: ()
                    }
                
            case 1: switch indexPath.row {
                
                    case 0:
                        if datasourceGroupBy == "alphabetic" {
                            datasourceGroupBy = "none"
                        } else {
                            datasourceGroupBy = "alphabetic"
                        }
                    case 1:
                        if datasourceGroupBy == "typefile" {
                            datasourceGroupBy = "none"
                        } else {
                            datasourceGroupBy = "typefile"
                        }
                    case 2:
                        if datasourceGroupBy == "date" {
                            datasourceGroupBy = "none"
                        } else {
                            datasourceGroupBy = "date"
                        }
                
                    default: ()
                        }
                    case 2:
                        if datasourceDirectoryOnTop {
                            datasourceDirectoryOnTop = false
                        } else {
                            datasourceDirectoryOnTop = true
                        }
                    default: ()
                    }
            
            NCUtility.sharedInstance.setLayoutForView(key: layoutViewSelect, layout: typeLayout, sort: datasourceSorted, ascending: datasourceAscending, groupBy: datasourceGroupBy, directoryOnTop: datasourceDirectoryOnTop)
            
            loadDatasource(withLoadFolder: false)
        }
        
        if dropdownMenu.token == "tapMoreHeaderMenu" {
        }
        
        if dropdownMenu.token == "tapMoreHeaderMenuSelect" {
        }
    }
    
    // MARK: NC API
    
    func createFolder(with fileName: String) {
        
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)

        ocNetworking?.createFolder(fileName, serverUrl: serverUrl, account: appDelegate.activeAccount, success: { (fileID, date) in
            self.loadDatasource(withLoadFolder: true)
        }, failure: { (message, errorCode) in
            self.appDelegate.messageNotification("_error_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        })
    }
    
    func downloadThumbnail(with metadata: tableMetadata, indexPath: IndexPath) {
        
        let width = NCUtility.sharedInstance.getScreenWidthForPreview()
        let height = NCUtility.sharedInstance.getScreenHeightForPreview()
        
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        ocNetworking?.downloadPreview(with: metadata, serverUrl: serverUrl, withWidth: width, andHeight: height, completion: { (message, errorCode) in
            if errorCode == 0 && CCUtility.fileProviderStorageIconExists(metadata.fileID, fileNameView: metadata.fileName) {
                self.collectionView.reloadItems(at: [indexPath])
            }
        })
    }
    
    func loadFolder() {
        
        networkInProgress = true
        collectionView.reloadData()
        
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        ocNetworking?.readFolder(serverUrl, depth: "1", account: appDelegate.activeAccount, success: { (metadatas, metadataFolder, directoryID) in
            
            // Update directory etag
            NCManageDatabase.sharedInstance.setDirectory(serverUrl: self.serverUrl, serverUrlTo: nil, etag: metadataFolder?.etag, fileID: metadataFolder?.fileID, encrypted: metadataFolder!.e2eEncrypted)
            NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "directoryID == %@ AND (status == %d OR status == %d)", directoryID!, k_metadataStatusNormal, k_metadataStatusHide), clearDateReadDirectoryID: directoryID)
            NCManageDatabase.sharedInstance.setDateReadDirectory(directoryID: directoryID!)
            
            _ = NCManageDatabase.sharedInstance.addMetadatas(metadatas as! [tableMetadata], serverUrl: self.serverUrl)
            
            if let metadatasInDownload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "directoryID == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", directoryID!, k_metadataStatusWaitDownload, k_metadataStatusInDownload, k_metadataStatusDownloading, k_metadataStatusDownloadError), sorted: nil, ascending: false) {
                
                _ = NCManageDatabase.sharedInstance.addMetadatas(metadatasInDownload, serverUrl: self.serverUrl)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.networkInProgress = false
                self.loadDatasource(withLoadFolder: false)
            }
            
        }, failure: { (message, errorCode) in
                        
            self.appDelegate.messageNotification("_error_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.networkInProgress = false
                self.loadDatasource(withLoadFolder: false)
            }
        })
    }
    
    // MARK: DATASOURCE
    @objc func loadDatasource(withLoadFolder: Bool) {
        
        sectionDatasource = CCSectionDataSourceMetadata()
        var predicate: NSPredicate?
        
        if directoryID == "" {
            
            serverUrl = CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl)
            directoryID = NCManageDatabase.sharedInstance.getDirectoryID(serverUrl) ?? ""
        }
        
        if includeDirectoryE2EEncryption {
            
            if includeImages {
                predicate = NSPredicate(format: "directoryID == %@ AND (directory == true OR typeFile == 'image')", directoryID)
            } else {
                predicate = NSPredicate(format: "directoryID == %@ AND directory == true", directoryID)
            }
            
        } else {
            
            if includeImages {
                predicate = NSPredicate(format: "directoryID == %@ AND e2eEncrypted == false AND (directory == true OR typeFile == 'image')", directoryID)
            } else {
                predicate = NSPredicate(format: "directoryID == %@ AND e2eEncrypted == false AND directory == true", directoryID)
            }
        }
        
        if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: predicate!, sorted: datasourceSorted, ascending: datasourceAscending) {
            
            sectionDatasource = CCSectionMetadata.creataDataSourseSectionMetadata(metadatas, listProgressMetadata: nil, groupByField: datasourceGroupBy, filterFileID: nil, filterTypeFileImage: false, filterTypeFileVideo: false, activeAccount: appDelegate.activeAccount)
        }
        
        if withLoadFolder {
            loadFolder()
        } else {
            self.refreshControl.endRefreshing()
        }
        
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
        var imagePreview = false
        
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
            imagePreview = true
        } else {
            if metadata.hasPreview == 1 && !CCUtility.fileProviderStorageIconExists(metadata.fileID, fileNameView: metadata.fileName) {
                downloadThumbnail(with: metadata, indexPath: indexPath)
            }
        }
        
        if collectionView.collectionViewLayout == listLayout {
            
            // LIST
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
            cell.delegate = self
            
            // hide button more
            cell.hideButtonMore()
            
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
            
            // hide button more
            cell.hideButtonMore()
            
            cell.fileID = metadata.fileID
            cell.indexPath = indexPath
            cell.labelTitle.text = metadata.fileNameView
            
            if metadata.directory {
                image = UIImage.init(named: "folder")
                cell.imageItem.image = CCGraphics.changeThemingColorImage(image, width: image!.size.width*6, height: image!.size.height*6, scale: 3.0, color: NCBrandColor.sharedInstance.brandElement)
                cell.imageItem.contentMode = .center
            } else {
                cell.imageItem.image = image
                if imagePreview == false {
                    let width = cell.imageItem.image!.size.width * 2
                    //let scale = UIScreen.main.scale
                    cell.imageItem.image = NCUtility.sharedInstance.resizeImage(image: image!, newWidth: width)
                    cell.imageItem.contentMode = .center
                }
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
            
            guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                return
            }
            guard let serverUrlPush = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName) else {
                return
            }
            guard let directoryIDPush = NCManageDatabase.sharedInstance.getDirectoryID(serverUrlPush) else {
                return
            }
            guard let visualController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateViewController(withIdentifier: "NCSelect.storyboard") as? NCSelect else {
                return
            }
            
            visualController.delegate = delegate
            
            visualController.hideButtonCreateFolder = hideButtonCreateFolder
            visualController.selectFile = selectFile
            visualController.includeDirectoryE2EEncryption = includeDirectoryE2EEncryption
            visualController.includeImages = includeImages
            visualController.type = type
            visualController.titleButtonDone = titleButtonDone
            visualController.layoutViewSelect = layoutViewSelect

            visualController.titleCurrentFolder = metadata.fileNameView
            visualController.serverUrl = serverUrlPush
            visualController.directoryID = directoryIDPush
            
            self.navigationController?.pushViewController(visualController, animated: true)
            
        } else {
            
            delegate?.dismissSelect(serverUrl: serverUrl, metadata: metadata, type: type)
            self.dismiss(animated: true, completion: nil)
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
