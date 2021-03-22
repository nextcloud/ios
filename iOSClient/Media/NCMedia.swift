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

class NCMedia: UIViewController, NCEmptyDataSetDelegate, NCSelectDelegate {
    
    @IBOutlet weak var collectionView : UICollectionView!
    
    private var emptyDataSet: NCEmptyDataSet?
    private var mediaCommandView: NCMediaCommandView?
    private var gridLayout: NCGridMediaLayout!

    internal let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    public var metadatas: [tableMetadata] = []
    private var metadataTouch: tableMetadata?
    private var account: String = ""

    private var predicateDefault: NSPredicate?
    private var predicate: NSPredicate?

    internal var isEditMode = false
    internal var selectOcId: [String] = []
    
    internal var filterTypeFileImage = false
    internal var filterTypeFileVideo = false
            
    private let maxImageGrid: CGFloat = 7
    private var cellHeigth: CGFloat = 0

    private var oldInProgress = false
    private var newInProgress = false
    
    private var lastContentOffsetY: CGFloat = 0
    private var mediaPath = ""
    private var livePhoto: Bool = false
    
    private var timeIntervalSearchNewMedia: TimeInterval = 3.0
    private var timerSearchNewMedia: Timer?
        
    struct cacheImages {
        static var cellLivePhotoImage = UIImage()
        static var cellPlayImage = UIImage()
    }

    // MARK: - View Life Cycle
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        appDelegate.activeMedia = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationWillEnterForeground), object: nil)
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
        
        // Empty
        emptyDataSet = NCEmptyDataSet.init(view: collectionView, offset: 0, delegate: self)
      
        // Notification
        NotificationCenter.default.addObserver(self, selector: #selector(initializeMain), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitializeMain), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
            
        mediaCommandView = Bundle.main.loadNibNamed("NCMediaCommandView", owner: self, options: nil)?.first as? NCMediaCommandView
        self.view.addSubview(mediaCommandView!)
        mediaCommandView?.mediaView = self
        mediaCommandView?.zoomInButton.isEnabled = !(gridLayout.itemForLine == 1)
        mediaCommandView?.zoomOutButton.isEnabled = !(gridLayout.itemForLine == maxImageGrid - 1)
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
        appDelegate.activeViewController = self
        
        // hide nagigation controller
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        self.reloadDataSourceWithCompletion { (_) in
            self.timerSearchNewMedia?.invalidate()
            self.timerSearchNewMedia = Timer.scheduledTimer(timeInterval: self.timeIntervalSearchNewMedia, target: self, selector: #selector(self.searchNewMediaTimer), userInfo: nil, repeats: false)
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
    
    @objc func initializeMain() {
        
        self.reloadDataSourceWithCompletion { (_) in
            self.timerSearchNewMedia?.invalidate()
            self.timerSearchNewMedia = Timer.scheduledTimer(timeInterval: self.timeIntervalSearchNewMedia, target: self, selector: #selector(self.searchNewMediaTimer), userInfo: nil, repeats: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.mediaCommandTitle()
            }
        }
    }
    
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
            if(self.gridLayout.itemForLine + 1 < self.maxImageGrid) {
                self.gridLayout.itemForLine += 1
                self.mediaCommandView?.zoomInButton.isEnabled = true
            }
            if(self.gridLayout.itemForLine == self.maxImageGrid - 1) {
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
        toggleMenu()
    }
    
    // MARK: Select Path
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], buttonType: String, overwrite: Bool) {
        if serverUrl != nil {
            let path = CCUtility.returnPathfromServerUrl(serverUrl, urlBase: appDelegate.urlBase, account: appDelegate.account) ?? ""
            NCManageDatabase.shared.setAccountMediaPath(path, account: appDelegate.account)
            reloadDataSourceWithCompletion { (_) in
                self.searchNewMedia()
            }
        }
    }
    
    //MARK: - NotificationCenter

    @objc func changeTheming() {
        view.backgroundColor = NCBrandColor.shared.backgroundView
        collectionView.backgroundColor = NCBrandColor.shared.backgroundView
        collectionView.reloadData()
        
        cacheImages.cellLivePhotoImage = NCUtility.shared.loadImage(named: "livephoto", color: .white)
        cacheImages.cellPlayImage = UIImage.init(named: "play")!.image(color: .white, size: 50)
    }

    @objc func deleteFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String {
          
                let indexes = self.metadatas.indices.filter { self.metadatas[$0].ocId == ocId }
                let metadatas = self.metadatas.filter { $0.ocId != ocId }
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
    
    @objc func moveFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                
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
    
    @objc func renameFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                
                if metadata.account == appDelegate.account {
                    self.reloadDataSource()
                }
            }
        }
    }
        
    // MARK: - Empty
    
    func emptyDataSetView(_ view: NCEmptyView) {
        
        view.emptyImage.image = UIImage.init(named: "media")?.image(color: .gray, size: UIScreen.main.bounds.width)
        if oldInProgress || newInProgress {
            view.emptyTitle.text = NSLocalizedString("_search_in_progress_", comment: "")
        } else {
            view.emptyTitle.text = NSLocalizedString("_tutorial_photo_view_", comment: "")
        }
        view.emptyDescription.text = ""
    }
}

// MARK: - Collection View

extension NCMedia: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let metadata = metadatas[indexPath.row]
        metadataTouch = metadata
        
        if isEditMode {
            if let index = selectOcId.firstIndex(of: metadata.ocId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(metadata.ocId)
            }
            if indexPath.section <  collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section) {
                collectionView.reloadItems(at: [indexPath])
            }
            
        } else {
            
            appDelegate.activeServerUrl = metadataTouch!.serverUrl
            NCViewer.shared.view(viewController: self, metadata: metadataTouch!, metadatas: metadatas)
        }
    }
    
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        let metadata = metadatas[indexPath.row]
        let identifier = indexPath as NSCopying

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            
            return NCViewerProviderContextMenu(metadata: metadata)
            
        }, actionProvider: { suggestedActions in
            
            return NCFunctionCenter.shared.contextMenuConfiguration(metadata: metadata, viewController: self, enableDeleteLocal: false, enableViewInFolder: true)
        })
    }
    
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion {

            if let indexPath = configuration.identifier as? IndexPath {
                self.collectionView(collectionView, didSelectItemAt: indexPath)
            }
        }
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
        emptyDataSet?.numberOfItemsInSection(metadatas.count, section: section)
        return metadatas.count
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.row < self.metadatas.count {
            let metadata = self.metadatas[indexPath.row]
            NCOperationQueue.shared.downloadThumbnail(metadata: metadata, urlBase: self.appDelegate.urlBase, view: self.collectionView as Any, indexPath: indexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !collectionView.indexPathsForVisibleItems.contains(indexPath) && indexPath.row < metadatas.count {
            let metadata = metadatas[indexPath.row]
            NCOperationQueue.shared.cancelDownloadThumbnail(metadata: metadata)
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.section < collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section) && indexPath.row < metadatas.count {
        
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridMediaCell
            let metadata = metadatas[indexPath.row]
            
            self.cellHeigth = cell.frame.size.height

            if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                cell.imageItem.backgroundColor = nil
                cell.imageItem.image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            } else if(!metadata.hasPreview) {
                cell.imageItem.backgroundColor = nil
                if metadata.iconName.count > 0 {
                    cell.imageItem.image = UIImage.init(named: metadata.iconName)
                } else {
                    cell.imageItem.image = NCBrandColor.cacheImages.file
                }
            }
            cell.date = metadata.date as Date

            if metadata.typeFile == NCGlobal.shared.metadataTypeFileVideo || metadata.typeFile == NCGlobal.shared.metadataTypeFileAudio {
                cell.imageStatus.image = cacheImages.cellPlayImage
            } else if metadata.livePhoto && livePhoto {
                cell.imageStatus.image = cacheImages.cellLivePhotoImage
            }
            
            if isEditMode {
                cell.selectMode(true)
                if selectOcId.contains(metadata.ocId) {
                    cell.selected(true)
                } else {
                    cell.selected(false)
                }
            } else {
                cell.selectMode(false)
            }
            
            return cell
            
        } else {
            
            return collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridMediaCell
        }
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
        
        if appDelegate.account == "" { return }
        
        if account != appDelegate.account {
            self.metadatas = []
            account = appDelegate.account
            collectionView?.reloadData()
        }
        
        livePhoto = CCUtility.getLivePhoto()
        
        if let tableAccount = NCManageDatabase.shared.getAccountActive() {
            self.mediaPath = tableAccount.mediaPath
        }
        let startServerUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account) + mediaPath
        
        predicateDefault = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (typeFile == %@ OR typeFile == %@) AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NCGlobal.shared.metadataTypeFileImage, NCGlobal.shared.metadataTypeFileVideo)
        
        if filterTypeFileImage {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND typeFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NCGlobal.shared.metadataTypeFileVideo)
        } else if filterTypeFileVideo {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND typeFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NCGlobal.shared.metadataTypeFileImage)
        } else {
            predicate = predicateDefault
        }
        
        guard var predicateForGetMetadatasMedia = predicate else { return }
        
        if livePhoto {
            let predicateLivePhoto = NSPredicate(format: "!(ext == 'mov' AND livePhoto == true)")
            predicateForGetMetadatasMedia = NSCompoundPredicate.init(andPredicateWithSubpredicates:[predicateForGetMetadatasMedia, predicateLivePhoto])
        }
              
        DispatchQueue.global().async {
            self.metadatas = NCManageDatabase.shared.getMetadatasMedia(predicate: predicateForGetMetadatasMedia, sort: CCUtility.getMediaSortDate())
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
    
    private func searchOldMedia(value: Int = -30, limit: Int = 300) {
        
        if oldInProgress { return }
        else { oldInProgress = true }
        collectionView.reloadData()

        var lessDate = Date()
        if predicateDefault != nil {
            if let metadata = NCManageDatabase.shared.getMetadata(predicate: predicateDefault!, sorted: "date", ascending: true) {
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
        NCUtility.shared.startActivityIndicator(backgroundView: self.view, blurEffect: false, bottom: height + 100)

        NCCommunication.shared.searchMedia(path: mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: CCUtility.getShowHiddenFiles(), timeout: 120) { (account, files, errorCode, errorDescription) in
            
            self.oldInProgress = false
            NCUtility.shared.stopActivityIndicator()
            self.collectionView.reloadData()

            if errorCode == 0 && account == self.appDelegate.account {
                if files.count > 0 {
                    NCManageDatabase.shared.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: false, account: self.appDelegate.account) { (_, _, metadatas) in
                        
                        let predicateDate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                        let predicateResult = NSCompoundPredicate.init(andPredicateWithSubpredicates:[predicateDate, self.predicateDefault!])
                        let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: predicateResult)
                        let metadatasChanged = NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
                        
                        if metadatasChanged.metadatasUpdate.count == 0 {
                            
                            self.researchOldMedia(value: value, limit: limit, withElseReloadDataSource: true)
                            
                        } else {
                            
                            self.reloadDataSource()
                        }
                    }

                } else {
                    
                    self.researchOldMedia(value: value, limit: limit, withElseReloadDataSource: false)
                }
            }
        }
    }
    
    private func researchOldMedia(value: Int , limit: Int, withElseReloadDataSource: Bool) {
        
        if value == -30 {
            searchOldMedia(value: -90)
        } else if value == -90 {
            searchOldMedia(value: -180)
        } else if value == -180 {
            searchOldMedia(value: -999)
        } else if value == -999 && limit > 0 {
            searchOldMedia(value: -999, limit: 0)
        } else {
            if withElseReloadDataSource {
                reloadDataSource()
            }
        }
    }
    
    @objc func searchNewMediaTimer() {
        self.searchNewMedia()
    }
    
    @objc func searchNewMedia(limit: Int = 300) {
        
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
                    NCManageDatabase.shared.convertNCCommunicationFilesToMetadatas(files, useMetadataFolder: false, account: account) { (_, _, metadatas) in
                        let predicate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                        let predicateResult = NSCompoundPredicate.init(andPredicateWithSubpredicates:[predicate, self.predicate!])
                        let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: predicateResult)
                        let updateMetadatas = NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
                        if updateMetadatas.metadatasUpdate.count > 0 {
                            self.reloadDataSource()
                        }
                    }
                } else if errorCode == 0 && files.count == 0 && limit > 0 {
                    self.searchNewMedia(limit: 0)
                } else if errorCode == 0 && files.count == 0 && self.metadatas.count == 0 {
                    self.searchOldMedia()
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
            timerSearchNewMedia?.invalidate()
            timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchNewMediaTimer), userInfo: nil, repeats: false)
            
            if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height)) {
                searchOldMedia()
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchNewMediaTimer), userInfo: nil, repeats: false)
        
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height)) {
            searchOldMedia()
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
        moreButton.setImage(UIImage.init(named: "more")!.image(color: .white, size: 25), for: .normal)
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

