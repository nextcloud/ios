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

class NCMedia: UIViewController, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, NCSelectDelegate {
    
    @IBOutlet weak var collectionView : UICollectionView!
    
    private var mediaCommandView: NCMediaCommandView?
    private var gridLayout: NCGridMediaLayout!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    public var metadatas: [tableMetadata] = []
    private var metadataTouch: tableMetadata?
    private var account: String = ""

    private var predicateDefault: NSPredicate?
    private var predicate: NSPredicate?

    private var isEditMode = false
    private var selectocId: [String] = []
    
    private var filterTypeFileImage = false
    private var filterTypeFileVideo = false
            
    private let kMaxImageGrid: CGFloat = 5
    private var cellHeigth: CGFloat = 0

    private var oldInProgress = false
    private var newInProgress = false
    
    private var lastContentOffsetY: CGFloat = 0
    private var mediaPath = ""
    private var livePhoto: Bool = false
    
    private var listOcIdReadFileForMedia: [String] = []
    
    struct cacheImages {
        static var cellLivePhotoImage = UIImage()
        static var cellPlayImage = UIImage()
        static var cellFavouriteImage = UIImage()
    }

    // MARK: - View Life Cycle
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        appDelegate.activeMedia = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: k_notificationCenter_reloadMediaDataSource), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: NSNotification.Name(rawValue: k_notificationCenter_applicationWillEnterForeground), object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.register(UINib.init(nibName: "NCGridMediaCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 75, left: 0, bottom: 50, right: 0);
                
        gridLayout = NCGridMediaLayout()
        gridLayout.itemForLine = CGFloat(min(CCUtility.getMediaWidthImage(), 5))
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
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_mediaFileNotFound), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
            
        mediaCommandView = Bundle.main.loadNibNamed("NCMediaCommandView", owner: self, options: nil)?.first as? NCMediaCommandView
        self.view.addSubview(mediaCommandView!)
        mediaCommandView?.mediaView = self
        mediaCommandView?.zoomInButton.isEnabled = !(self.gridLayout.itemForLine == 1)
        mediaCommandView?.zoomOutButton.isEnabled = !(self.gridLayout.itemForLine == self.kMaxImageGrid - 1)
        mediaCommandView?.collapseControlButtonView(true)
        mediaCommandView?.translatesAutoresizingMaskIntoConstraints = false
        mediaCommandView?.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        mediaCommandView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        mediaCommandView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        mediaCommandView?.heightAnchor.constraint(equalToConstant: 150).isActive = true
        self.updateMediaControlVisibility()
        
        collectionView.prefetchDataSource = self
        
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.reloadDataSourceWithCompletion { (_) in
            self.searchNewPhotoVideo()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
    
    //MARK: - Notification
    
    @objc func applicationWillEnterForeground() {
        if self.view.window != nil {
            self.viewDidAppear(false)
        }
    }
    
    //MARK: - Command
    
    func mediaCommandTitle() {
        mediaCommandView?.title.text = ""
        
        if let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) }) {
        
            if let cell = visibleCells.first as? NCGridMediaCell {
                if cell.date != nil {
                    mediaCommandView?.title.text = CCUtility.getTitleSectionDate(cell.date)
                }
            }
        }
    }
    
    @objc func zoomOutGrid() {
        UIView.animate(withDuration: 0.0, animations: {
            if(self.gridLayout.itemForLine + 1 < self.kMaxImageGrid) {
                self.gridLayout.itemForLine += 1
                self.mediaCommandView?.zoomInButton.isEnabled = true
            }
            if(self.gridLayout.itemForLine == self.kMaxImageGrid - 1) {
                self.mediaCommandView?.zoomOutButton.isEnabled = false
            }

            self.collectionView.collectionViewLayout.invalidateLayout()
            CCUtility.setMediaWidthImage(Int(self.gridLayout.itemForLine))
        })
    }

    @objc func zoomInGrid() {
        UIView.animate(withDuration: 0.0, animations: {
            if(self.gridLayout.itemForLine - 1 > 0) {
                self.gridLayout.itemForLine -= 1
                self.mediaCommandView?.zoomOutButton.isEnabled = true
            }
            if(self.gridLayout.itemForLine == 1) {
                self.mediaCommandView?.zoomInButton.isEnabled = false
            }

            self.collectionView.collectionViewLayout.invalidateLayout()
            CCUtility.setMediaWidthImage(Int(self.gridLayout.itemForLine))
        })
    }
    
    @objc func openMenuButtonMore(_ sender: Any) {
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        var actions: [NCMenuAction] = []

        if !isEditMode {
            if metadatas.count > 0 {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_select_", comment: ""),
                        icon: CCGraphics.changeThemingColorImage(UIImage(named: "selectFull"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                        action: { menuAction in
                            self.isEditMode = true
                        }
                    )
                )
            }

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
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_select_media_folder_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "folderAutomaticUpload"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as! UINavigationController
                        let viewController = navigationController.topViewController as! NCSelect
                        
                        viewController.delegate = self
                        viewController.hideButtonCreateFolder = true
                        viewController.includeDirectoryE2EEncryption = false
                        viewController.includeImages = false
                        viewController.keyLayout = k_layout_view_move
                        viewController.selectFile = false
                        viewController.titleButtonDone = NSLocalizedString("_select_", comment: "")
                        viewController.type = "mediaFolder"
                        
                        navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                        self.present(navigationController, animated: true, completion: nil)
                    }
                )
            )
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_media_by_modified_date_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "sortModifiedDate"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    selected: CCUtility.getMediaSortDate() == "date",
                    on: true,
                    action: { menuAction in
                        CCUtility.setMediaSortDate("date")
                        self.reloadDataSource()
                    }
                )
            )
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_media_by_created_date_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "sortCreatedDate"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    selected: CCUtility.getMediaSortDate() == "creationDate",
                    on: true,
                    action: { menuAction in
                        CCUtility.setMediaSortDate("creationDate")
                        self.reloadDataSource()
                    }
                )
            )
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_media_by_upload_date_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "sortUploadDate"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    selected: CCUtility.getMediaSortDate() == "uploadDate",
                    on: true,
                    action: { menuAction in
                        CCUtility.setMediaSortDate("uploadDate")
                        self.reloadDataSource()
                    }
                )
            )
            
        } else {
           
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_cancel_", comment: ""),
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
                            if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
                                NCNetworking.shared.deleteMetadata(metadata, account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, onlyLocal: false) { (errorCode, errorDescription) in
                                    if errorCode != 0 {
                                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                    }
                                }
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
    
    // MARK: Select Path
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, array: [Any], buttonType: String, overwrite: Bool) {
        if serverUrl != nil {
            let path = CCUtility.returnPathfromServerUrl(serverUrl, urlBase: appDelegate.urlBase, account: appDelegate.account) ?? ""
            NCManageDatabase.sharedInstance.setAccountMediaPath(path, account: appDelegate.account)
            reloadDataSourceWithCompletion { (_) in
                self.searchNewPhotoVideo()
            }
        }
    }
    
    //MARK: - NotificationCenter

    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: collectionView, form: false)
        
        cacheImages.cellLivePhotoImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "livePhoto"), width: 100, height: 100, color: .white)
        cacheImages.cellPlayImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "play"), width: 100, height: 100, color: .white)
        cacheImages.cellFavouriteImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 100, height: 100, color: NCBrandColor.sharedInstance.yellowFavorite)
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }

    @objc func deleteFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.account == appDelegate.account {
                    
                    let indexes = self.metadatas.indices.filter { self.metadatas[$0].ocId == metadata.ocId }
                    let metadatas = self.metadatas.filter { $0.ocId != metadata.ocId }
                    self.metadatas = metadatas
                    
                    if self.metadatas.count == 0 {
                        collectionView?.reloadData()
                    } else if let row = indexes.first {
                        let indexPath = IndexPath(row: row, section: 0)
                        collectionView?.deleteItems(at: [indexPath])
                    }
                    
                    self.updateMediaControlVisibility()
                }
            }
        }
    }
    
    @objc func moveFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.account == appDelegate.account {
                    self.reloadDataSource()
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.account == appDelegate.account {
                    self.reloadDataSource()
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
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "media"), width: 300, height: 300, color: .gray)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        
        var text = "\n" + NSLocalizedString("_tutorial_photo_view_", comment: "")

        if oldInProgress || newInProgress {
            text = "\n" + NSLocalizedString("_search_in_progress_", comment: "")
        }
        
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.gray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    // MARK: SEGUE
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let segueNavigationController = segue.destination as? UINavigationController {
            if let segueViewController = segueNavigationController.topViewController as? NCDetailViewController {
            
                segueViewController.metadata = metadataTouch
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
        metadataTouch = metadata
        
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

extension NCMedia: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        //print("[LOG] n. " + String(indexPaths.count))
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
        if indexPath.row < self.metadatas.count {
            let metadata = self.metadatas[indexPath.row]
            NCOperationQueue.shared.downloadThumbnail(metadata: metadata, urlBase: self.appDelegate.urlBase, view: self.collectionView as Any, indexPath: indexPath)
            if !listOcIdReadFileForMedia.contains(metadata.ocId) {
                NCOperationQueue.shared.readFileForMedia(metadata: metadata)
                listOcIdReadFileForMedia.append(metadata.ocId)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !collectionView.indexPathsForVisibleItems.contains(indexPath) && indexPath.row < metadatas.count {
            let metadata = metadatas[indexPath.row]
            NCOperationQueue.shared.cancelDownloadThumbnail(metadata: metadata)
            NCOperationQueue.shared.cancelReadFileForMedia(metadata: metadata)
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let metadata = metadatas[indexPath.row]
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridMediaCell
        self.cellHeigth = cell.frame.size.height

        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            cell.imageItem.backgroundColor = nil
            cell.imageItem.image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
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
        } else if metadata.livePhoto && livePhoto {
            cell.imageStatus.image = cacheImages.cellLivePhotoImage
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
        self.reloadDataSourceWithCompletion { (_) in }
    }
    
    @objc func reloadDataSourceWithCompletion(_ completion: @escaping (_ metadatas: [tableMetadata]) -> Void) {
        
        if (appDelegate.account == nil || appDelegate.account.count == 0 || appDelegate.maintenanceMode == true) { return }
        
        if account != appDelegate.account {
            self.metadatas = []
            account = appDelegate.account
            collectionView?.reloadData()
        }
        
        livePhoto = CCUtility.getLivePhoto()
        
        if let tableAccount = NCManageDatabase.sharedInstance.getAccountActive() {
            self.mediaPath = tableAccount.mediaPath
        }
        let startServerUrl = NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account) + mediaPath
        
        predicateDefault = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (typeFile == %@ OR typeFile == %@) AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, k_metadataTypeFile_image, k_metadataTypeFile_video)
        
        if filterTypeFileImage {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND typeFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, k_metadataTypeFile_video)
        } else if filterTypeFileVideo {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND typeFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, k_metadataTypeFile_image)
        } else {
            predicate = predicateDefault
        }
        
        guard var predicateForGetMetadatasMedia = predicate else { return }
        
        if livePhoto {
            let predicateLivePhoto = NSPredicate(format: "!(ext == 'mov' AND livePhoto == true)")
            predicateForGetMetadatasMedia = NSCompoundPredicate.init(andPredicateWithSubpredicates:[predicateForGetMetadatasMedia, predicateLivePhoto])
        }
              
        DispatchQueue.global().async {
            self.metadatas = NCManageDatabase.sharedInstance.getMetadatasMedia(predicate: predicateForGetMetadatasMedia, sort: CCUtility.getMediaSortDate())
            DispatchQueue.main.sync {
                self.reloadDataThenPerform {
                    self.updateMediaControlVisibility()
                    self.mediaCommandTitle()
                    completion(self.metadatas)
                }
            }
        }
    }
    
    func updateMediaControlVisibility() {
        if self.metadatas.count == 0 {
            if !self.filterTypeFileImage && !self.filterTypeFileVideo {
                self.mediaCommandView?.toggleEmptyView(isEmpty: true)
                self.mediaCommandView?.isHidden = false
            } else {
                self.mediaCommandView?.toggleEmptyView(isEmpty: true)
                self.mediaCommandView?.isHidden = false
            }
        } else {
            self.mediaCommandView?.toggleEmptyView(isEmpty: false)
            self.mediaCommandView?.isHidden = false
        }
    }
    
    private func searchOldPhotoVideo(value: Int = -30, limit: Int = 300) {
        
        if oldInProgress { return }
        else { oldInProgress = true }
        collectionView.reloadData()

        var lessDate = Date()
        if predicateDefault != nil {
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: predicateDefault!, sorted: "date", ascending: true) {
                lessDate = metadata.date as Date
            }
        }
        
        var greaterDate: Date
        if value == -999 {
            greaterDate = Date.distantPast
        } else {
            greaterDate = Calendar.current.date(byAdding: .day, value:value, to: lessDate)!
        }
        
        let height = self.tabBarController?.tabBar.frame.size.height ?? 0
        NCUtility.shared.startActivityIndicator(view: self.view, bottom: height + 50)

        NCCommunication.shared.searchMedia(path: mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: CCUtility.getShowHiddenFiles(), timeout: 120) { (account, files, errorCode, errorDescription) in
            
            self.oldInProgress = false
            NCUtility.shared.stopActivityIndicator()
            self.collectionView.reloadData()

            if errorCode == 0 && account == self.appDelegate.account {
                if files.count > 0 {
                    NCManageDatabase.sharedInstance.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: false, account: self.appDelegate.account) { (_, _, metadatas) in
                        
                        let predicateDate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                        let predicateResult = NSCompoundPredicate.init(andPredicateWithSubpredicates:[predicateDate, self.predicateDefault!])
                        let metadatasResult = NCManageDatabase.sharedInstance.getMetadatas(predicate: predicateResult)
                        let metadatasChanged = NCManageDatabase.sharedInstance.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
                        
                        if metadatasChanged.metadatasUpdate.count == 0 {
                            
                            self.researchOldPhotoVideo(value: value, limit: limit, withElseReloadDataSource: true)
                            
                        } else {
                            
                            self.reloadDataSource()
                        }
                    }

                } else {
                    
                    self.researchOldPhotoVideo(value: value, limit: limit, withElseReloadDataSource: false)
                }
            }
        }
    }
    
    private func researchOldPhotoVideo(value: Int , limit: Int, withElseReloadDataSource: Bool) {
        
        if value == -30 {
            searchOldPhotoVideo(value: -90)
        } else if value == -90 {
            searchOldPhotoVideo(value: -180)
        } else if value == -180 {
            searchOldPhotoVideo(value: -999)
        } else if value == -999 && limit > 0 {
            searchOldPhotoVideo(value: -999, limit: 0)
        } else {
            if withElseReloadDataSource {
                reloadDataSource()
            }
        }
    }
    
    @objc func searchNewPhotoVideo(limit: Int = 300) {
        
        guard var lessDate = Calendar.current.date(byAdding: .second, value: 1, to: Date()) else { return }
        guard var greaterDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
        
        newInProgress = true
        reloadDataThenPerform {
            if let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) }) {
                if let cell = visibleCells.first as? NCGridMediaCell {
                    if cell.date != nil {
                        if cell.date != self.metadatas.first?.date as Date? {
                            lessDate = Calendar.current.date(byAdding: .second, value: 1, to: cell.date!)!
                        }
                    }
                }
                if let cell = visibleCells.last as? NCGridMediaCell {
                    if cell.date != nil {
                        greaterDate = Calendar.current.date(byAdding: .second, value: -1, to: cell.date!)!
                    }
                }
            }

            NCCommunication.shared.searchMedia(path: self.mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: CCUtility.getShowHiddenFiles(), timeout: 120) { (account, files, errorCode, errorDescription) in
                
                self.newInProgress = false
                
                if errorCode == 0 && account == self.appDelegate.account && files.count > 0 {
                    NCManageDatabase.sharedInstance.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: false, account: account) { (_, _, metadatas) in
                        let predicate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                        let predicateResult = NSCompoundPredicate.init(andPredicateWithSubpredicates:[predicate, self.predicate!])
                        let metadatasResult = NCManageDatabase.sharedInstance.getMetadatas(predicate: predicateResult)
                        let updateMetadatas = NCManageDatabase.sharedInstance.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
                        if updateMetadatas.metadatasUpdate.count > 0 {
                            self.reloadDataSource()
                        }
                    }
                } else if errorCode == 0 && files.count == 0 && limit > 0 {
                    self.searchNewPhotoVideo(limit: 0)
                } else if errorCode == 0 && files.count == 0 && self.metadatas.count == 0 {
                    self.searchOldPhotoVideo()
                }
            }
        }
    }
    
    private func downloadThumbnail() {
        guard let collectionView = self.collectionView else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for indexPath in collectionView.indexPathsForVisibleItems {
                let metadata = self.metadatas[indexPath.row]
                NCOperationQueue.shared.downloadThumbnail(metadata: metadata, urlBase: self.appDelegate.urlBase, view: self.collectionView as Any, indexPath: indexPath)
            }
        }
    }
}

// MARK: - ScrollView

extension NCMedia: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        if lastContentOffsetY == 0 || lastContentOffsetY + cellHeigth/2 <= scrollView.contentOffset.y  || lastContentOffsetY - cellHeigth/2 >= scrollView.contentOffset.y {

            mediaCommandTitle()
            lastContentOffsetY = scrollView.contentOffset.y
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        mediaCommandView?.collapseControlButtonView(true)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        if !decelerate {
            self.searchNewPhotoVideo()
            
            if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height)) {
                searchOldPhotoVideo()
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.searchNewPhotoVideo()
        
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
    @IBOutlet weak var moreButton: UIButton!
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
        moreButton.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), width: 50, height: 50, color: .white), for: .normal)
        title.text = ""
    }
    
    func toggleEmptyView(isEmpty: Bool) {
        if isEmpty {
            UIView.animate(withDuration: 0.3) {
                self.moreView.effect = UIBlurEffect(style: .dark)
                self.gradient.isHidden = true
                self.controlButtonView.isHidden = true
            }
        } else {
            UIView.animate(withDuration: 0.3) {
                self.moreView.effect = UIBlurEffect(style: .regular)
                self.gradient.isHidden = false
                self.controlButtonView.isHidden = false
            }
        }
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

// MARK: - Media Grid Layout

class NCGridMediaLayout: UICollectionViewFlowLayout {
    
    var marginLeftRight: CGFloat = 6
    var itemForLine: CGFloat = 3
    
    override init() {
        super.init()
        
        sectionHeadersPinToVisibleBounds = false
        
        minimumInteritemSpacing = 0
        minimumLineSpacing = marginLeftRight
        
        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 0, left: marginLeftRight, bottom: 0, right:  marginLeftRight)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                
                let itemWidth: CGFloat = (collectionView.frame.width - marginLeftRight * 2 - marginLeftRight * (itemForLine - 1)) / itemForLine
                let itemHeight: CGFloat = itemWidth
                
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

