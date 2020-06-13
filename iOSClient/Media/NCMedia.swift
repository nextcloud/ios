//
//  NCMedia.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/02/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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
import NCCommunication

class NCMedia: UIViewController, DropdownMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    
    @IBOutlet weak var collectionView : UICollectionView!
    
    private var mediaCommandView: NCMediaCommandView?
    private var gridLayout: NCGridMediaLayout!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    public var metadatas: [tableMetadata] = []
    private var metadataPush: tableMetadata?
    
    private var isEditMode = false
    private var selectocId: [String] = []
    
    private var filterTypeFileImage = false;
    private var filterTypeFileVideo = false;
            
    private var stepImageWidth: CGFloat = 10
    private let kMaxImageGrid: CGFloat = 5
    
    private var oldInProgress = false
    private var newInProgress = false
    
    struct cacheImages {
        static var cellPlayImage = UIImage()
        static var cellFavouriteImage = UIImage()
    }

    // MARK: - View Life Cycle
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        appDelegate.activeMedia = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: k_notificationCenter_initializeMain), object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.register(UINib.init(nibName: "NCGridMediaCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0);
                
        gridLayout = NCGridMediaLayout()
        gridLayout.itemPerLine = CGFloat(min(CCUtility.getMediaWidthImage(), 5))
        gridLayout.sectionHeadersPinToVisibleBounds = true

        collectionView.collectionViewLayout = gridLayout
        
        // empty Data Source
        collectionView.emptyDataSetDelegate = self
        collectionView.emptyDataSetSource = self
                
        // 3D Touch peek and pop
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: view)
        }
        
        // Notification
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
            
        mediaCommandView = Bundle.main.loadNibNamed("NCMediaCommandView", owner: self, options: nil)?.first as? NCMediaCommandView
        self.view.addSubview(mediaCommandView!)
        mediaCommandView?.mediaView = self
        mediaCommandView?.zoomInButton.isEnabled = !(self.gridLayout.itemPerLine == 1)
        mediaCommandView?.zoomOutButton.isEnabled = !(self.gridLayout.itemPerLine == self.kMaxImageGrid - 1)
        mediaCommandView?.collapseControlButtonView(true)
        mediaCommandView?.translatesAutoresizingMaskIntoConstraints = false
        mediaCommandView?.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        mediaCommandView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        mediaCommandView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        mediaCommandView?.heightAnchor.constraint(equalToConstant: 150).isActive = true
        if self.metadatas.count == 0 {
            self.mediaCommandView?.isHidden = true
        }
        
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        mediaCommandTitle()
        readFiles()
        searchNewPhotoVideo()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.reloadDataThenPerform { }
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    //MARK: - Command
    
    func mediaCommandTitle() {
        mediaCommandView?.title.text = ""
        if let cell = collectionView?.visibleCells.first as? NCGridMediaCell {
            if cell.date != nil {
                mediaCommandView?.title.text = CCUtility.getTitleSectionDate(cell.date)
            }
        }
    }
    
    @objc func zoomOutGrid() {
        UIView.animate(withDuration: 0.0, animations: {
            if(self.gridLayout.itemPerLine + 1 < self.kMaxImageGrid) {
                self.gridLayout.itemPerLine += 1
                self.mediaCommandView?.zoomInButton.isEnabled = true
            }
            if(self.gridLayout.itemPerLine == self.kMaxImageGrid - 1) {
                self.mediaCommandView?.zoomOutButton.isEnabled = false
            }

            self.collectionView.collectionViewLayout.invalidateLayout()
            CCUtility.setMediaWidthImage(Int(self.gridLayout.itemPerLine))
        })
    }

    @objc func zoomInGrid() {
        UIView.animate(withDuration: 0.0, animations: {
            if(self.gridLayout.itemPerLine - 1 > 0) {
                self.gridLayout.itemPerLine -= 1
                self.mediaCommandView?.zoomOutButton.isEnabled = true
            }
            if(self.gridLayout.itemPerLine == 1) {
                self.mediaCommandView?.zoomInButton.isEnabled = false
            }

            self.collectionView.collectionViewLayout.invalidateLayout()
            CCUtility.setMediaWidthImage(Int(self.gridLayout.itemPerLine))
        })
    }
    
    @objc func openMenuButtonMore(_ sender: Any) {
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        var actions: [NCMenuAction] = []

        if !isEditMode {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_select_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "selectFull"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.isEditMode = true
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString(filterTypeFileImage ? "_media_viewimage_show_" : "_media_viewimage_hide_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: filterTypeFileImage ? "imageno" : "imageyes"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.filterTypeFileImage = !self.filterTypeFileImage
                        self.filterTypeFileVideo = false
                        self.reloadDataSource()
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString(filterTypeFileVideo ? "_media_viewvideo_show_" : "_media_viewvideo_hide_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: filterTypeFileVideo ? "videono" : "videoyes"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.filterTypeFileVideo = !self.filterTypeFileVideo
                        self.filterTypeFileImage = false
                        self.reloadDataSource()
                    }
                )
            )

        } else {
           
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_deselect_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "cancel"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.isEditMode = false
                        self.selectocId.removeAll()
                        self.reloadDataThenPerform { }
                    }
                )
            )
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_delete_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                    action: { menuAction in
                        self.isEditMode = false
                        for ocId in self.selectocId {
                            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", ocId)) {
                                NCNetworking.shared.deleteMetadata(metadata, account: self.appDelegate.activeAccount, url: self.appDelegate.activeUrl) { (errorCode, errorDescription) in }
                            }
                        }
                    }
                )
            )
        }

        mainMenuViewController.actions = actions
        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)

        self.present(menuPanelController, animated: true, completion: nil)
    }
    
    //MARK: - NotificationCenter

    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: collectionView, form: false)
        
        cacheImages.cellPlayImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "play"), width: 100, height: 100, color: .white)
        cacheImages.cellFavouriteImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 100, height: 100, color: NCBrandColor.sharedInstance.yellowFavorite)
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }

    @objc func deleteFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                let metadatas = self.metadatas.filter { $0.ocId != metadata.ocId }
                self.metadatas = metadatas
                    
                if self.metadatas.count  > 0 {
                    self.mediaCommandView?.isHidden = false
                } else {
                    self.mediaCommandView?.isHidden = true
                }
                self.reloadDataThenPerform {
                    self.mediaCommandTitle()
                }
                    
                if errorCode == 0 && (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                    let userInfo: [String : Any] = ["metadata": metadata, "type": "delete"]
                    NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_synchronizationMedia), object: nil, userInfo: userInfo)
                }
            }
        }
    }
    
    @objc func moveFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataNew = userInfo["metadataNew"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                self.reloadDataSource()

                if errorCode == 0 && (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                    let userInfo: [String : Any] = ["metadata": metadata, "metadataNew": metadataNew, "type": "move"]
                    NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_synchronizationMedia), object: nil, userInfo: userInfo)
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                self.reloadDataSource()

                if errorCode == 0 && (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                    let userInfo: [String : Any] = ["metadata": metadata, "type": "rename"]
                    NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_synchronizationMedia), object: nil, userInfo: userInfo)
                }
            }
        }
    }
    
    // MARK: DZNEmpty
    
    func verticalOffset(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
        return 0
    }
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "media"), width: 300, height: 300, color: NCBrandColor.sharedInstance.brandElement)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        
        var text = "\n" + NSLocalizedString("_tutorial_photo_view_", comment: "")

        if oldInProgress || newInProgress {
            text = "\n" + NSLocalizedString("_search_in_progress_", comment: "")
        }
        
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    // MARK: SEGUE
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let segueNavigationController = segue.destination as? UINavigationController {
            if let segueViewController = segueNavigationController.topViewController as? NCDetailViewController {
            
                segueViewController.metadata = metadataPush
                segueViewController.metadatas = metadatas
                segueViewController.mediaFilterImage = true
            }
        }
    }
}

// MARK: - 3D Touch peek and pop

extension NCMedia: UIViewControllerPreviewingDelegate {
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        guard let point = collectionView?.convert(location, from: collectionView?.superview) else { return nil }
        guard let indexPath = collectionView?.indexPathForItem(at: point) else { return nil }
        let metadata = metadatas[indexPath.row]
        guard let cell = collectionView?.cellForItem(at: indexPath) as? NCGridMediaCell  else { return nil }
        guard let viewController = UIStoryboard(name: "CCPeekPop", bundle: nil).instantiateViewController(withIdentifier: "PeekPopImagePreview") as? CCPeekPop else { return nil }
        
        previewingContext.sourceRect = cell.frame
        viewController.metadata = metadata
        viewController.imageFile = cell.imageItem.image
        viewController.showOpenIn = true
        viewController.showShare = false
        viewController.showOpenQuickLook = false

        return viewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        
        guard let indexPath = collectionView?.indexPathForItem(at: previewingContext.sourceRect.origin) else { return }
        
        collectionView(collectionView, didSelectItemAt: indexPath)
    }
}

// MARK: - Collection View

extension NCMedia: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let metadata = metadatas[indexPath.row]
        metadataPush = metadata
        
        if isEditMode {
            if let index = selectocId.firstIndex(of: metadata.ocId) {
                selectocId.remove(at: index)
            } else {
                selectocId.append(metadata.ocId)
            }
            if indexPath.section <  collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section) {
                collectionView.reloadItems(at: [indexPath])
            }
            
            return
        }
        
        performSegue(withIdentifier: "segueDetail", sender: self)
    }
}

extension NCMedia: UICollectionViewDataSource {
    
    func reloadDataThenPerform(_ closure: @escaping (() -> Void)) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(closure)
        collectionView?.reloadData()
        CATransaction.commit()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return metadatas.count
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.row < metadatas.count {
            let metadata = metadatas[indexPath.row]
            NCOperationQueue.shared.downloadThumbnail(metadata: metadata, activeUrl: self.appDelegate.activeUrl, view: self.collectionView as Any, indexPath: indexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.row < metadatas.count {
            let metadata = metadatas[indexPath.row]
            NCOperationQueue.shared.cancelDownloadThumbnail(metadata: metadata)
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let metadata = metadatas[indexPath.row]
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridMediaCell

        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)) {
            cell.imageItem.backgroundColor = nil
            cell.imageItem.image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView))
        } else if(!metadata.hasPreview) {
            cell.imageItem.backgroundColor = nil
            if metadata.iconName.count > 0 {
                cell.imageItem.image = UIImage.init(named: metadata.iconName)
            } else {
                cell.imageItem.image = UIImage.init(named: "file")
            }
        }
        cell.date = metadata.date as Date

        // image status
        if metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio {
            cell.imageStatus.image = cacheImages.cellPlayImage
        }
        
        // image Local
        let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            if tableLocalFile!.offline { cell.imageLocal.image = UIImage.init(named: "offlineFlag") }
            else { cell.imageLocal.image = UIImage.init(named: "local") }
        }
        
        // image Favorite
        if metadata.favorite {
            cell.imageFavorite.image = cacheImages.cellFavouriteImage
        }
        
        if isEditMode {
            cell.imageSelect.isHidden = false
            if selectocId.contains(metadata.ocId) {
                cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedYes"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                cell.imageVisualEffect.isHidden = false
                cell.imageVisualEffect.alpha = 0.4
            } else {
                cell.imageSelect.isHidden = true
                cell.imageVisualEffect.isHidden = true
            }
        } else {
            cell.imageSelect.isHidden = true
            cell.imageVisualEffect.isHidden = true
        }
       
        return cell
    }
}

extension NCMedia: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 0)
    }
}

// MARK: - NC API & Algorithm

extension NCMedia {

    @objc func reloadDataSource() {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        var predicate: NSPredicate?
        
        if filterTypeFileImage {
            predicate = NSPredicate(format: "account == %@ AND typeFile == %@", appDelegate.activeAccount, k_metadataTypeFile_video)
        } else if filterTypeFileVideo {
            predicate = NSPredicate(format: "account == %@ AND typeFile == %@", appDelegate.activeAccount, k_metadataTypeFile_image)
        } else {
            predicate = NSPredicate(format: "account == %@ AND (typeFile == %@ OR typeFile == %@)", appDelegate.activeAccount, k_metadataTypeFile_image, k_metadataTypeFile_video)
        }
                
        NCManageDatabase.sharedInstance.getMetadatasMedia(predicate: predicate!) { (metadatas) in
            DispatchQueue.main.async {
                self.metadatas = metadatas
                
                if self.metadatas.count  > 0 {
                    self.mediaCommandView?.isHidden = false
                } else {
                    self.mediaCommandView?.isHidden = true
                }
                self.reloadDataThenPerform {
                    self.mediaCommandTitle()
                }
            }
        }
    }
    
    @objc func searchNewPhotoVideo() {
        
        if newInProgress { return }
        else { newInProgress = true }
        collectionView.reloadData()
        
        let tableAccount = NCManageDatabase.sharedInstance.getAccountActive()
        
        //let elementDate = "nc:upload_time/"
        //let lteDate: Int = Int(Date().timeIntervalSince1970)
        //let gteDate: Int = Int(fromDate!.timeIntervalSince1970)
        
        guard let lessDate = Calendar.current.date(byAdding: .second, value: 1, to: Date()) else { return }
        guard var greaterDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
        
        if let date = tableAccount?.dateUpdateNewMedia {
            greaterDate = date as Date
        }
                
        NCCommunication.shared.searchMedia(lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/" ,showHiddenFiles: CCUtility.getShowHiddenFiles(), user: appDelegate.activeUser) { (account, files, errorCode, errorDescription) in
            
            self.newInProgress = false
            self.collectionView.reloadData()

            if errorCode == 0 && files != nil && files!.count > 0 {
                
                NCManageDatabase.sharedInstance.addMetadatas(files: files, account: self.appDelegate.activeAccount)
                if tableAccount?.dateLessMedia == nil {
                    NCManageDatabase.sharedInstance.setAccountDateLessMedia(date: files?.last?.date)
                }
                NCManageDatabase.sharedInstance.setAccountDateUpdateNewMedia()
                
                self.reloadDataSource()
            }
            
            if errorCode == 0 && files != nil && files!.count == 0 && self.metadatas.count == 0 {
                self.searchOldPhotoVideo()
            }
        }
    }
    
    private func searchOldPhotoVideo(value: Int = -30) {
        
        if oldInProgress { return }
        else { oldInProgress = true }
        collectionView.reloadData()

        var lessDate = Date()
        let tableAccount = NCManageDatabase.sharedInstance.getAccountActive()
        if let date = tableAccount?.dateLessMedia {
            lessDate = date as Date
        }
        var greaterDate: Date
        
        if value == -999 {
            greaterDate = Date.distantPast
        } else {
            greaterDate = Calendar.current.date(byAdding: .day, value:value, to: lessDate)!
        }
        
        let height = self.tabBarController?.tabBar.frame.size.height ?? 0
        NCUtility.sharedInstance.startActivityIndicator(view: self.view, bottom: height + 50)

        NCCommunication.shared.searchMedia(lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/" ,showHiddenFiles: CCUtility.getShowHiddenFiles(), user: appDelegate.activeUser) { (account, files, errorCode, errorDescription) in
            
            self.oldInProgress = false
            NCUtility.sharedInstance.stopActivityIndicator()
            self.collectionView.reloadData()

            if errorCode == 0 {
                if files != nil && files!.count > 0 {
                    
                    NCManageDatabase.sharedInstance.addMetadatas(files: files, account: self.appDelegate.activeAccount)
                    NCManageDatabase.sharedInstance.setAccountDateLessMedia(date: files?.last?.date)
                    self.reloadDataSource()
                    
                } else {
                    
                    if value == -30 {
                        self.searchOldPhotoVideo(value: -90)
                    } else if value == -90 {
                        self.searchOldPhotoVideo(value: -180)
                    } else if value == -180 {
                        self.searchOldPhotoVideo(value: -999)
                    }
                }
            }
        }
    }
    
    private func downloadThumbnail() {
        guard let collectionView = self.collectionView else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for indexPath in collectionView.indexPathsForVisibleItems {
                let metadata = self.metadatas[indexPath.row]
                NCOperationQueue.shared.downloadThumbnail(metadata: metadata, activeUrl: self.appDelegate.activeUrl, view: self.collectionView as Any, indexPath: indexPath)
            }
        }
    }
    
    private func readFiles() {
        guard let collectionView = self.collectionView else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for indexPath in collectionView.indexPathsForVisibleItems {
                let metadata = self.metadatas[indexPath.row]
                NCOperationQueue.shared.readFileForMedia(metadata: metadata)
            }
        }
    }
}

// MARK: - ScrollView

extension NCMedia: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        mediaCommandTitle()
        mediaCommandView?.collapseControlButtonView(true)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.readFiles()
            
            if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height)) {
                searchOldPhotoVideo()
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.readFiles()
        
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height)) {
            searchOldPhotoVideo()
        }
    }
}

// MARK: - Media Command View

class NCMediaCommandView: UIView {
    
    @IBOutlet weak var moreView: UIVisualEffectView!
    @IBOutlet weak var gridSwitchButton: UIButton!
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var buttonControlWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var zoomInButton: UIButton!
    @IBOutlet weak var zoomOutButton: UIButton!
    @IBOutlet weak var controlButtonView: UIVisualEffectView!
    @IBOutlet weak var title : UILabel!
    
    var mediaView:NCMedia?
    private let gradient: CAGradientLayer = CAGradientLayer()
    
    override func awakeFromNib() {
        moreView.layer.cornerRadius = 20
        moreView.layer.masksToBounds = true
        controlButtonView.layer.cornerRadius = 20
        controlButtonView.layer.masksToBounds = true
        gradient.frame = bounds
        gradient.startPoint = CGPoint(x: 0, y: 0.50)
        gradient.endPoint = CGPoint(x: 0, y: 0.9)
        gradient.colors = [UIColor.black.withAlphaComponent(0.4).cgColor , UIColor.clear.cgColor]
        layer.insertSublayer(gradient, at: 0)
        
        title.text = ""
    }
    
    @IBAction func moreButtonPressed(_ sender: UIButton) {
        mediaView?.openMenuButtonMore(sender)
    }
    
    @IBAction func zoomInPressed(_ sender: UIButton) {
        mediaView?.zoomInGrid()
    }
    
    @IBAction func zoomOutPressed(_ sender: UIButton) {
        mediaView?.zoomOutGrid()
    }
    
    @IBAction func gridSwitchButtonPressed(_ sender: Any) {
        self.collapseControlButtonView(false)
    }
    
    func collapseControlButtonView(_ collapse: Bool) {
        if (collapse) {
            self.buttonControlWidthConstraint.constant = 40
            UIView.animate(withDuration: 0.25) {
                self.zoomOutButton.isHidden = true
                self.zoomInButton.isHidden = true
                self.separatorView.isHidden = true
                self.gridSwitchButton.isHidden = false
                self.layoutIfNeeded()
            }
        } else {
            self.buttonControlWidthConstraint.constant = 80
            UIView.animate(withDuration: 0.25) {
                self.zoomOutButton.isHidden = false
                self.zoomInButton.isHidden = false
                self.separatorView.isHidden = false
                self.gridSwitchButton.isHidden = true
                self.layoutIfNeeded()
            }
        }
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return moreView.frame.contains(point) || controlButtonView.frame.contains(point)
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        gradient.frame = bounds
    }
}
