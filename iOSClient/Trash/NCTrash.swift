//
//  NCTrash.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//

import Foundation

class NCTrash: UIViewController , UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, NCTrashListDelegate, NCTrashGridDelegate, NCTrashHeaderMenuDelegate {
    
    @IBOutlet fileprivate weak var collectionView: UICollectionView!

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var path = ""
    var titleCurrentFolder = NSLocalizedString("_trash_view_", comment: "")
    var datasource: [tableTrash]?

    var listLayout: ListLayout!
    var gridLayout: GridLayout!
    
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
        refreshControl.tintColor = NCBrandColor.sharedInstance.brand
        refreshControl.addTarget(self, action: #selector(loadListingTrash), for: .valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.title = titleCurrentFolder

        if path == "" {
            let userID = (appDelegate.activeUserID as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlFragmentAllowed)
            path = k_dav + "/trashbin/" + userID! + "/trash/"
        }
        
        let results = NCManageDatabase.sharedInstance.getTrash(filePath: path, sorted: "fileName", ascending: true)
        if (results != nil) {
            datasource = results!
            collectionView.reloadData()
        }
        
        loadListingTrash()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    // MARK: TAP EVENT
    
    func tapRestoreItem(with fileID: String, sender: Any) {
        restoreItem(with: fileID)
    }
    
    func tapMoreItem(with fileID: String, sender: Any) {
        
        var items = [ActionSheetItem]()
        
        items.append(ActionSheetTitle(title: NSLocalizedString("_delete_selected_files_", comment: "")))
        items.append(ActionSheetDangerButton(title: NSLocalizedString("_delete_", comment: "")))
        items.append(ActionSheetCancelButton(title: NSLocalizedString("_cancel_", comment: "")))
        
        let actionSheet = ActionSheet(items: items) { sheet, item in
            if item is ActionSheetDangerButton { self.deleteItem(with: fileID) }
            if item is ActionSheetCancelButton { print("Cancel buttons has the value `true`") }
        }
        
        actionSheet.present(in: self, from: sender as! UIButton)
    }
    
    func tapSwitchHeaderMenu() {
        
        if collectionView.collectionViewLayout == gridLayout {
            // list layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.listLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                }) 
            })
            CCUtility.setLayoutTrash("list")
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                })
            })
            CCUtility.setLayoutTrash("grid")
        }
    }
    
    func tapMoreHeaderMenu() {
        print("tap header more")
    }
    
    // MARK: NC API
    
    @objc func loadListingTrash() {
        
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        ocNetworking?.listingTrash(appDelegate.activeUrl, path:path, account: appDelegate.activeAccount, success: { (item) in
            
            NCManageDatabase.sharedInstance.deleteTrash(filePath: self.path)
            NCManageDatabase.sharedInstance.addTrashs(item as! [tableTrash])
            
            let results = NCManageDatabase.sharedInstance.getTrash(filePath: self.path, sorted: "fileName", ascending: true)
            if (results != nil) {
                self.datasource = results!
                self.collectionView.reloadData()
            }
            
            self.refreshControl.endRefreshing()
            
        }, failure: { (message, errorCode) in
            
            print("error " + message!)
            self.refreshControl.endRefreshing()
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
            self.datasource = NCManageDatabase.sharedInstance.getTrash(filePath: self.path, sorted: "fileName", ascending: true)
            self.collectionView.reloadData()
            
            // Remove, if exists, fileID in appDelegate.filterFileID
            for number in 0..<(self.appDelegate.filterFileID.count) {
                
                let fileIDDeleted = self.appDelegate.filterFileID[number] as! String
                
                if fileIDDeleted.range(of: fileID) != nil {
                    self.appDelegate.filterFileID.remove(fileIDDeleted)
                    break
                }
            }
            
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
                self.datasource = NCManageDatabase.sharedInstance.getTrash(filePath: self.path, sorted: "fileName", ascending: true)
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
            
            return trashHeader
            
        } else {
            
            let trashFooter = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "footerMenu", for: indexPath) as! NCTrashFooterMenu
            
            trashFooter.labelFooter.textColor = NCBrandColor.sharedInstance.icon
            
            var folders: Int = 0, foldersText = ""
            var files: Int = 0, filesText = ""
            var size: Double = 0
            
            if self.datasource != nil {
                for record: tableTrash in self.datasource! {
                    if record.directory {
                        folders += 1
                    } else {
                        files += 1
                    }
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
            } else if folders == 1 {
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
        return CGSize(width: collectionView.frame.width, height: 50)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 50)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return datasource?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let tableTrash = datasource![indexPath.item]
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
            
            return cell
        
        } else {
            
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
            
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let tableTrash = datasource![indexPath.item]
        
        if tableTrash.directory {
        
            let ncTrash:NCTrash = UIStoryboard(name: "NCTrash", bundle: nil).instantiateInitialViewController() as! NCTrash
            ncTrash.path = tableTrash.filePath + tableTrash.fileName
            ncTrash.titleCurrentFolder = tableTrash.trashbinFileName
            self.navigationController?.pushViewController(ncTrash, animated: true)
        }
    }
}

class ListLayout: UICollectionViewFlowLayout {
    
    let itemHeight: CGFloat = 60
    
    override init() {
        super.init()
        
        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
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
    
    let numberOfColumns: Int = 5
    let itemHeightWithoutImage: CGFloat = 34

    override init() {
        super.init()
        
        minimumInteritemSpacing = 10
        
        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                let itemWidth: CGFloat = (collectionView.frame.width/CGFloat(self.numberOfColumns)) - self.minimumInteritemSpacing
                let itemHeight: CGFloat = itemWidth + itemHeightWithoutImage
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
