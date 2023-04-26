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

import UIKit
import NextcloudKit

class NCMedia: UIViewController, NCEmptyDataSetDelegate, NCSelectDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    private var emptyDataSet: NCEmptyDataSet?
    private var mediaCommandView: NCMediaCommandView?
    private var gridLayout: NCGridMediaLayout!

    internal let appDelegate = UIApplication.shared.delegate as! AppDelegate

    public var metadatas: [tableMetadata] = []
    private var account: String = ""

    private var predicateDefault: NSPredicate?
    private var predicate: NSPredicate?

    internal var isEditMode = false
    internal var selectOcId: [String] = []

    internal var filterClassTypeImage = false
    internal var filterClassTypeVideo = false

    private let maxImageGrid: CGFloat = 7
    private var cellHeigth: CGFloat = 0

    private var oldInProgress = false
    private var newInProgress = false

    private var lastContentOffsetY: CGFloat = 0
    private var mediaPath = ""
    private var livePhoto: Bool = false

    private var timeIntervalSearchNewMedia: TimeInterval = 3.0
    private var timerSearchNewMedia: Timer?

    private let insetsTop: CGFloat = 75

    struct cacheImages {
        static var cellLivePhotoImage = UIImage()
        static var cellPlayImage = UIImage()
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        collectionView.register(UINib(nibName: "NCGridMediaCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")

        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: insetsTop, left: 0, bottom: 50, right: 0)
        collectionView.backgroundColor = .systemBackground

        gridLayout = NCGridMediaLayout()
        gridLayout.itemForLine = CGFloat(min(CCUtility.getMediaWidthImage(), 5))
        gridLayout.sectionHeadersPinToVisibleBounds = true

        collectionView.collectionViewLayout = gridLayout

        // Empty
        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: 0, delegate: self)

        // Notification
        NotificationCenter.default.addObserver(self, selector: #selector(initialize), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)

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

        cacheImages.cellLivePhotoImage = NCUtility.shared.loadImage(named: "livephoto", color: .white)
        cacheImages.cellPlayImage = NCUtility.shared.loadImage(named: "play.fill", color: .white)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDelegate.activeViewController = self

        navigationController?.setMediaAppreance()

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        self.reloadDataSourceWithCompletion { _ in
            self.timerSearchNewMedia?.invalidate()
            self.timerSearchNewMedia = Timer.scheduledTimer(timeInterval: self.timeIntervalSearchNewMedia, target: self, selector: #selector(self.searchNewMediaTimer), userInfo: nil, repeats: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        mediaCommandTitle()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        self.collectionView?.collectionViewLayout.invalidateLayout()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - NotificationCenter

    @objc func initialize() {

        self.reloadDataSourceWithCompletion { _ in
            self.timerSearchNewMedia?.invalidate()
            self.timerSearchNewMedia = Timer.scheduledTimer(timeInterval: self.timeIntervalSearchNewMedia, target: self, selector: #selector(self.searchNewMediaTimer), userInfo: nil, repeats: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.mediaCommandTitle()
            }
        }
    }

    @objc func deleteFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String
        else { return }

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

    @objc func moveFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        self.reloadDataSourceWithCompletion { _ in }
    }

    @objc func renameFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        self.reloadDataSourceWithCompletion { _ in }
    }

    @objc func uploadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError,
              error == .success,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        self.reloadDataSourceWithCompletion { _ in }
    }

    // MARK: - Command

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
            if self.gridLayout.itemForLine + 1 < self.maxImageGrid {
                self.gridLayout.itemForLine += 1
                self.mediaCommandView?.zoomInButton.isEnabled = true
            }
            if self.gridLayout.itemForLine == self.maxImageGrid - 1 {
                self.mediaCommandView?.zoomOutButton.isEnabled = false
            }

            self.collectionView.collectionViewLayout.invalidateLayout()
            CCUtility.setMediaWidthImage(Int(self.gridLayout.itemForLine))
        })
    }

    @objc func zoomInGrid() {

        UIView.animate(withDuration: 0.0, animations: {
            if self.gridLayout.itemForLine - 1 > 0 {
                self.gridLayout.itemForLine -= 1
                self.mediaCommandView?.zoomOutButton.isEnabled = true
            }
            if self.gridLayout.itemForLine == 1 {
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

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {

        guard let serverUrl = serverUrl else { return }
        let path = CCUtility.returnPathfromServerUrl(serverUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId, account: appDelegate.account) ?? ""
            NCManageDatabase.shared.setAccountMediaPath(path, account: appDelegate.account)
        reloadDataSourceWithCompletion { _ in
            self.searchNewMedia()
        }
    }

    // MARK: - Empty

    func emptyDataSetView(_ view: NCEmptyView) {

        view.emptyImage.image = UIImage(named: "media")?.image(color: .gray, size: UIScreen.main.bounds.width)
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
            // ACTIVE SERVERURL
            appDelegate.activeServerUrl = metadata.serverUrl
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridMediaCell
            NCViewer.shared.view(viewController: self, metadata: metadata, metadatas: metadatas, imageIcon: cell?.imageItem.image)
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        guard let cell = collectionView.cellForItem(at: indexPath) as? NCGridMediaCell else { return nil }
        let metadata = metadatas[indexPath.row]
        let identifier = indexPath as NSCopying
        let image = cell.imageItem.image

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return NCViewerProviderContextMenu(metadata: metadata, image: image)
        }, actionProvider: { _ in
            return NCContextMenu().viewMenu(ocId: metadata.ocId, viewController: self, image: image)
        })
    }

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
        // print("[LOG] n. " + String(indexPaths.count))
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
        guard let cell = (cell as? NCGridMediaCell), indexPath.row < self.metadatas.count else { return }
        let metadata = self.metadatas[indexPath.row]
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            cell.imageItem.backgroundColor = nil
            cell.imageItem.image = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
        } else {
            NCOperationQueue.shared.downloadThumbnail(metadata: metadata, placeholder: false, cell: cell, view: collectionView)
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

            cell.date = metadata.date as Date
            cell.fileObjectId = metadata.ocId
            cell.fileUser = metadata.ownerId

            if metadata.classFile == NKCommon.TypeClassFile.video.rawValue || metadata.classFile == NKCommon.TypeClassFile.audio.rawValue {
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

extension NCMedia {

    // MARK: - Datasource

    @objc func reloadDataSourceWithCompletion(_ completion: @escaping (_ metadatas: [tableMetadata]) -> Void) {
        guard !appDelegate.account.isEmpty else { return }

        if account != appDelegate.account {
            self.metadatas = []
            account = appDelegate.account
            collectionView?.reloadData()
        }

        livePhoto = CCUtility.getLivePhoto()

        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
            self.mediaPath = activeAccount.mediaPath
        }
        let startServerUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId) + mediaPath

        predicateDefault = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)

        if filterClassTypeImage {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        } else if filterClassTypeVideo {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else {
            predicate = predicateDefault
        }

        guard let predicate = predicate else { return }
        DispatchQueue.global().async {
            self.metadatas = NCManageDatabase.shared.getMetadatasMedia(predicate: predicate, livePhoto: self.livePhoto)
            switch CCUtility.getMediaSortDate() {
            case "date":
                self.metadatas = self.metadatas.sorted(by: {($0.date as Date) > ($1.date as Date)} )
            case "creationDate":
                self.metadatas = self.metadatas.sorted(by: {($0.creationDate as Date) > ($1.creationDate as Date)} )
            case "uploadDate":
                self.metadatas = self.metadatas.sorted(by: {($0.uploadDate as Date) > ($1.uploadDate as Date)} )
            default:
                break
            }
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
            if !self.filterClassTypeImage && !self.filterClassTypeVideo {
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

    // MARK: - Search media

    private func searchOldMedia(value: Int = -30, limit: Int = 300) {

        if oldInProgress { return } else { oldInProgress = true }
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
            greaterDate = Calendar.current.date(byAdding: .day, value: value, to: lessDate)!
        }

        var bottom: CGFloat = 0
        if let mainTabBar = self.tabBarController?.tabBar as? NCMainTabBar {
            bottom = -mainTabBar.getHight()
        }
        NCActivityIndicator.shared.start(backgroundView: self.view, bottom: bottom-5, style: .medium)

        let options = NKRequestOptions(timeout: 300)
        
        NextcloudKit.shared.searchMedia(path: mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: CCUtility.getShowHiddenFiles(), options: options) { account, files, data, error in

            self.oldInProgress = false
            NCActivityIndicator.shared.stop()
            self.collectionView.reloadData()

            if error == .success && account == self.appDelegate.account {
                if files.count > 0 {
                    NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, _, metadatas in
                        let predicateDate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                        let predicateResult = NSCompoundPredicate(andPredicateWithSubpredicates: [predicateDate, self.predicateDefault!])
                        let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: predicateResult)
                        let metadatasChanged = NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
                        if metadatasChanged.metadatasUpdate.count == 0 {
                            self.researchOldMedia(value: value, limit: limit, withElseReloadDataSource: true)
                        } else {
                            self.reloadDataSourceWithCompletion { _ in }
                        }
                    }
                } else {
                    self.researchOldMedia(value: value, limit: limit, withElseReloadDataSource: false)
                }
            } else if error != .success {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Media search old media error code \(error.errorCode) " + error.errorDescription)
            }
        }
    }

    private func researchOldMedia(value: Int, limit: Int, withElseReloadDataSource: Bool) {

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
                self.reloadDataSourceWithCompletion { _ in }
            }
        }
    }

    @objc func searchNewMediaTimer() {

        self.searchNewMedia()
    }

    @objc func searchNewMedia() {

        if newInProgress { return } else {
            newInProgress = true
            mediaCommandView?.activityIndicator.startAnimating()
        }

        var limit: Int = 1000
        guard var lessDate = Calendar.current.date(byAdding: .second, value: 1, to: Date()) else { return }
        guard var greaterDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }

        if let visibleCells = self.collectionView?.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).compactMap({ self.collectionView?.cellForItem(at: $0) }) {
            if let cell = visibleCells.first as? NCGridMediaCell {
                if cell.date != nil {
                    if cell.date != self.metadatas.first?.date as Date? {
                        lessDate = Calendar.current.date(byAdding: .second, value: 1, to: cell.date!)!
                        limit = 0
                    }
                }
            }
            if let cell = visibleCells.last as? NCGridMediaCell {
                if cell.date != nil {
                    greaterDate = Calendar.current.date(byAdding: .second, value: -1, to: cell.date!)!
                }
            }
        }

        reloadDataThenPerform {

            let options = NKRequestOptions(timeout: 300)
            
            NextcloudKit.shared.searchMedia(path: self.mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: CCUtility.getShowHiddenFiles(), options: options) { account, files, data, error in

                self.newInProgress = false
                self.mediaCommandView?.activityIndicator.stopAnimating()

                if error == .success && account == self.appDelegate.account && files.count > 0 {
                    NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, _, metadatas in
                        let predicate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                        let predicateResult = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, self.predicate!])
                        let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: predicateResult)
                        let updateMetadatas = NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
                        if updateMetadatas.metadatasUpdate.count > 0 || updateMetadatas.metadatasDelete.count > 0 {
                            self.reloadDataSourceWithCompletion { _ in }
                        }
                    }
                } else if error == .success && files.count == 0 && self.metadatas.count == 0 {
                    self.searchOldMedia()
                } else if error != .success {
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media error code \(error.errorCode) " + error.errorDescription)
                }
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

            if scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height) {
                searchOldMedia()
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {

        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchNewMedia, target: self, selector: #selector(searchNewMediaTimer), userInfo: nil, repeats: false)

        if scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height) {
            searchOldMedia()
        }
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {

        let y = view.safeAreaInsets.top
        scrollView.contentOffset.y = -(insetsTop + y)
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
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    var mediaView: NCMedia?
    private let gradient: CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        moreView.layer.cornerRadius = 20
        moreView.layer.masksToBounds = true
        controlButtonView.layer.cornerRadius = 20
        controlButtonView.layer.masksToBounds = true
        controlButtonView.effect = UIBlurEffect(style: .dark)
        gradient.frame = bounds
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        gradient.colors = [UIColor.black.withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled ? 0.8 : 0.4).cgColor, UIColor.clear.cgColor]
        layer.insertSublayer(gradient, at: 0)
        moreButton.setImage(UIImage(named: "more")!.image(color: .white, size: 25), for: .normal)
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
                self.moreView.effect = UIBlurEffect(style: .dark)
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
        if collapse {
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

    var marginLeftRight: CGFloat = 2
    var itemForLine: CGFloat = 3

    override init() {
        super.init()

        sectionHeadersPinToVisibleBounds = false

        minimumInteritemSpacing = 0
        minimumLineSpacing = marginLeftRight

        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 0, left: marginLeftRight, bottom: 0, right: marginLeftRight)
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
