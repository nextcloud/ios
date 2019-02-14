//
//  NCMedia.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/02/2019.
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

class NCMedia: UIViewController ,UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, NCListCellDelegate, NCSectionHeaderMenuDelegate, DropdownMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate  {
    
    @IBOutlet fileprivate weak var collectionView: UICollectionView!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
   
    private var metadataPush: tableMetadata?
    private var isEditMode = false
    private var selectFileID = [String]()
    
    private var filterTypeFileImage = false;
    private var filterTypeFileVideo = false;
    
    private var sectionDatasource = CCSectionDataSourceMetadata()
    
    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
    
    private var gridLayout: NCGridLayout!
    
    private var actionSheet: ActionSheet?
    
    private let headerMenuHeight: CGFloat = 50
    private let sectionHeaderHeight: CGFloat = 20
    private let footerHeight: CGFloat = 50
    
    private var addWidth: CGFloat = 10
    
    private var readLastdays = 30

    private let refreshControl = UIRefreshControl()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        appDelegate.activeMedia = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCGridMediaCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header
        collectionView.register(UINib.init(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        collectionView.register(UINib.init(nibName: "NCSectionHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeader")
        
        // Footer
        collectionView.register(UINib.init(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        
        collectionView.alwaysBounceVertical = true

        gridLayout = NCGridLayout()
        gridLayout.heightLabelPlusButton = 0
        gridLayout.preferenceWidth = 80
        gridLayout.sectionInset = UIEdgeInsets(top: 10, left: 1, bottom: 10, right: 1)

        collectionView.collectionViewLayout = gridLayout

        // Add Refresh Control
        collectionView.refreshControl = refreshControl
        
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
        
        self.navigationItem.title = NSLocalizedString("_media_", comment: "")
        
        // get auto upload folder
        autoUploadFileName = NCManageDatabase.sharedInstance.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.sharedInstance.getAccountAutoUploadDirectory(appDelegate.activeUrl)
        
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
        
        let itemSizeStart = self.gridLayout.itemSize
        
        UIView.animate(withDuration: 0.0, animations: {
            
            if self.gridLayout.numItems == 1 && self.addWidth > 0 {
                self.addWidth = -10
            } else if itemSizeStart.width < 50 {
                self.addWidth = 10
            }
            
            repeat {
                self.gridLayout.preferenceWidth = self.gridLayout.preferenceWidth + self.addWidth
            } while (self.gridLayout.itemSize == itemSizeStart)
            
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    func tapOrderHeader(sender: Any) {
    
    }
    
    func tapMoreHeader(sender: Any) {
        
        var menuView: DropdownMenu?
        
        if isEditMode {
            
            //let item0 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "checkedNo"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_cancel_", comment: ""))
            //let item1 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), multiplier: 1, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_trash_restore_selected_", comment: ""))
            let item2 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_trash_delete_selected_", comment: ""))
            
            menuView = DropdownMenu(navigationController: self.navigationController!, items: [item2], selectedRow: -1)
            menuView?.token = "tapMoreHeaderMenuSelect"
            
        } else {
            
            let item0 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "select"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_select_", comment: ""))
            let item1 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "folderMedia"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_select_media_folder_", comment: ""))
            var item2: DropdownItem
            if filterTypeFileImage {
                item2 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "imageno"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_media_viewimage_show_", comment: ""))
            } else {
                item2 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "imageyes"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_media_viewimage_hide_", comment: ""))
            }
            var item3: DropdownItem
            if filterTypeFileVideo {
                item3 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "videono"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_media_viewvideo_show_", comment: ""))
            } else {
                item3 = DropdownItem(image: CCGraphics.changeThemingColorImage(UIImage.init(named: "videoyes"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), title:  NSLocalizedString("_media_viewvideo_hide_", comment: ""))
            }
            menuView = DropdownMenu(navigationController: self.navigationController!, items: [item0,item1,item2,item3], selectedRow: -1)
            menuView?.token = "tapMoreHeaderMenu"
        }
        
        menuView?.delegate = self
        menuView?.rowHeight = 45
        menuView?.highlightColor = NCBrandColor.sharedInstance.brand
        menuView?.tableView.alwaysBounceVertical = false
        menuView?.tableViewBackgroundColor = UIColor.white
        
        let header = (sender as? UIButton)?.superview
        let headerRect = self.collectionView.convert(header!.bounds, from: self.view)
        let menuOffsetY =  headerRect.height - headerRect.origin.y - 2
        menuView?.topOffsetY = CGFloat(menuOffsetY)
        
        menuView?.showMenu()
    }
    
    func tapMoreListItem(with fileID: String, sender: Any) {
        tapMoreGridItem(with: fileID, sender: sender)
    }
    
    func tapMoreGridItem(with fileID: String, sender: Any) {
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileID)) else {
            return
        }
        
        if !isEditMode {
            
            var items = [ActionSheetItem]()
            let appearanceDelete = ActionSheetItemAppearance.init()
            appearanceDelete.textColor = UIColor.red
            
            // 0 == CCMore, 1 = first NCOffline ....
            if (self == self.navigationController?.viewControllers[1]) {
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
                        NCManageDatabase.sharedInstance.setDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!, offline: false, account: self.appDelegate.activeAccount)
                    } else {
                        NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, offline: false)
                    }
                    self.loadDatasource()
                }
                if item.value as? Int == 1 { self.appDelegate.activeMain.readShare(withAccount: self.appDelegate.activeAccount, openWindow: true, metadata: metadata) }
                if item.value as? Int == 2 { self.deleteItem(with: metadata, sender: sender) }
                if item is ActionSheetCancelButton { print("Cancel buttons has the value `true`") }
            }
            
            let headerView = NCActionSheetHeader.sharedInstance.actionSheetHeader(isDirectory: metadata.directory, iconName: metadata.iconName, fileID: metadata.fileID, fileNameView: metadata.fileNameView, text: metadata.fileNameView)
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
        
        if dropdownMenu.token == "tapMoreHeaderMenu" {
        
        }
        
        if dropdownMenu.token == "tapMoreHeaderMenuSelect" {
            
        }
    }
    
    // MARK: NC API
    
    func deleteItem(with metadata: tableMetadata, sender: Any) {
        
        var items = [ActionSheetItem]()
        
        guard let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == serverUrl", appDelegate.activeAccount, metadata.serverUrl)) else {
            return
        }
        
        items.append(ActionSheetDangerButton(title: NSLocalizedString("_delete_", comment: "")))
        items.append(ActionSheetCancelButton(title: NSLocalizedString("_cancel_", comment: "")))
        
        actionSheet = ActionSheet(items: items) { sheet, item in
            if item is ActionSheetDangerButton {
                NCMainCommon.sharedInstance.deleteFile(metadatas: [metadata], e2ee: tableDirectory.e2eEncrypted, serverUrl: tableDirectory.serverUrl, folderFileID: tableDirectory.fileID) { (errorCode, message) in
                    self.loadDatasource()
                }
            }
            if item is ActionSheetCancelButton { print("Cancel buttons has the value `true`") }
        }
        
        let headerView = NCActionSheetHeader.sharedInstance.actionSheetHeader(isDirectory: metadata.directory, iconName: metadata.iconName, fileID: metadata.fileID, fileNameView: metadata.fileNameView, text: metadata.fileNameView)
        actionSheet?.headerView = headerView
        actionSheet?.headerView?.frame.size.height = 50
        
        actionSheet?.present(in: self, from: sender as! UIButton)
    }
    
    func search(_ lteDate: Date, gteDate: Date) {
        
        if appDelegate.activeAccount.count == 0 {
            return
        }
        
        let startDirectory = NCManageDatabase.sharedInstance.getAccountStartDirectoryMediaTabView(CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl))

        OCNetworking.sharedManager()?.search(withAccount: appDelegate.activeAccount, fileName: "", serverUrl: startDirectory, contentType: ["image/%", "video/%"], lteDateLastModified: lteDate, gteDateLastModified: gteDate, depth: "infinity", completion: { (account, metadatas, message, errorCode) in
            
            if errorCode == 0 && account == self.appDelegate.activeAccount {
               
                NCManageDatabase.sharedInstance.createTablePhotos(metadatas as! [tableMetadata], lteDate: lteDate, gteDate: gteDate, account: account!)
                self.loadDatasource()
            }
            
            self.refreshControl.endRefreshing()
        })
    }
    
    // MARK: DATASOURCE
    @objc func loadDatasource() {
        
        if appDelegate.activeAccount.count == 0 {
            return
        }
        
        DispatchQueue.global().async {
            
            if let metadatas = NCManageDatabase.sharedInstance.getTablePhotos(predicate: NSPredicate(format: "account == %@", self.appDelegate.activeAccount))  {
                self.sectionDatasource = CCSectionMetadata.creataDataSourseSectionMetadata(metadatas, listProgressMetadata: nil, groupByField: "date", filterFileID: nil, filterTypeFileImage: self.filterTypeFileImage, filterTypeFileVideo: self.filterTypeFileVideo, activeAccount: self.appDelegate.activeAccount)
            } else {
                self.sectionDatasource = CCSectionDataSourceMetadata()
                
                let gteDate = Calendar.current.date(byAdding: .day, value: -self.readLastdays, to: Date())!
                self.search(Date(), gteDate: gteDate)
            }
        
            DispatchQueue.main.async {
                self.collectionView?.reloadData()
            }
        }
    }
    
    // MARK: COLLECTIONVIEW METHODS

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        //caused by user
        print("SCROLL scrollViewDidEndDecelerating")
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if (!decelerate) {
            //cause by user
            print("SCROLL scrollViewDidEndDragging")
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if (indexPath.section == 0) {
            
            if kind == UICollectionView.elementKindSectionHeader {
                
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCSectionHeaderMenu
                
                header.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchGridChange"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
                header.viewLabelSection.backgroundColor = .clear

                header.delegate = self
                
                header.setStatusButton(count: sectionDatasource.allFileID.count)
                
                header.buttonOrder.isHidden = true
                header.labelSection.isHidden = false
                header.buttonMore.isHidden = false
                
                header.setTitleLabel(sectionDatasource: sectionDatasource, section: indexPath.section)
                header.labelSectionHeightConstraint.constant = sectionHeaderHeight
                
                return header
            
            } else {
                
                let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
                
                footer.setTitleLabel(sectionDatasource: sectionDatasource)
                
                return footer
            }
            
        } else {
        
            if kind == UICollectionView.elementKindSectionHeader {
                
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as! NCSectionHeader
                
                header.backgroundColor = .clear
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
            return CGSize(width: collectionView.frame.width, height: headerMenuHeight + sectionHeaderHeight)
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
        
        let cell: UICollectionViewCell
        
        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridMediaCell
        }
        
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridMediaCell
      
        NCMainCommon.sharedInstance.collectionViewCellForItemAt(indexPath, collectionView: collectionView, cell: cell, metadata: metadata, metadataFolder: nil, serverUrl: metadata.serverUrl, isEditMode: isEditMode, selectFileID: selectFileID, autoUploadFileName: autoUploadFileName, autoUploadDirectory: autoUploadDirectory, hideButtonMore: true, source: self)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else {
            return
        }
        metadataPush = metadata
        
        if isEditMode {
            if let index = selectFileID.index(of: metadata.fileID) {
                selectFileID.remove(at: index)
            } else {
                selectFileID.append(metadata.fileID)
            }
            collectionView.reloadItems(at: [indexPath])
            return
        }
        
        performSegue(withIdentifier: "segueDetail", sender: self)
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
            
                segueViewController.metadataDetail = metadataPush
                segueViewController.dateFilterQuery = nil
                segueViewController.photoDataSource = photoDataSource
                segueViewController.title = metadataPush!.fileNameView
            }
        }
    }
}
