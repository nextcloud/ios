//
//  NCMediaViewModel.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import NextcloudKit
import Combine

//enum SortType: String {
//    case modifiedDate = "date", creationDate = "creationDate", uploadDate = "uploadDate"
//}

@MainActor class NCMediaViewModel: ObservableObject {
    @Published private(set) var metadatas: [tableMetadata] = []
    @Published internal var selectedMetadatas: [tableMetadata] = []
    @Published internal var isInSelectMode = false

    private var account: String = ""
    private var lastContentOffsetY: CGFloat = 0
    private var mediaPath = ""
    private var livePhoto: Bool = false
    private var predicateDefault: NSPredicate?
    private var predicate: NSPredicate?
    private let appDelegate = UIApplication.shared.delegate as? AppDelegate

    @Published internal var filterClassTypeImage = false
    @Published internal var filterClassTypeVideo = false

//    @Published internal var sortType: SortType = SortType(rawValue: CCUtility.getMediaSortDate()) ?? .modifiedDate

    private var cancellables: Set<AnyCancellable> = []

    internal var needsLoadingMoreItems = true

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userChanged(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)

        Task {
            await loadNewMedia()
        }

        $filterClassTypeImage.sink { _ in self.loadMediaFromDB() }.store(in: &cancellables)
        $filterClassTypeVideo.sink { _ in self.loadMediaFromDB() }.store(in: &cancellables)
//        $sortType.sink { sortType in
//            CCUtility.setMediaSortDate(sortType.rawValue)
//            self.loadMediaFromDB()
//        }
//        .store(in: &cancellables)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
    }

    private func queryDB(isForced: Bool = false) {
        guard let appDelegate else { return }

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

        DispatchQueue.main.async {
            self.metadatas = NCManageDatabase.shared.getMetadatasMedia(predicate: predicate, livePhoto: self.livePhoto)

            switch CCUtility.getMediaSortDate() {
            case "date":
                self.metadatas = self.metadatas.sorted(by: {($0.date as Date) > ($1.date as Date)})
            case "creationDate":
                self.metadatas = self.metadatas.sorted(by: {($0.creationDate as Date) > ($1.creationDate as Date)})
            case "uploadDate":
                self.metadatas = self.metadatas.sorted(by: {($0.uploadDate as Date) > ($1.uploadDate as Date)})
            default:
                break
            }
        }
    }

    func loadMoreItems() {
        loadOldMedia()
        needsLoadingMoreItems = false
    }

    func onPullToRefresh() async {
        await loadNewMedia()
    }

    func onCellTapped(metadata: tableMetadata) {
        appDelegate?.activeServerUrl = metadata.serverUrl
    }

    func deleteSelectedMetadata() {
        let notLocked = selectedMetadatas.allSatisfy { !$0.lock }

        if notLocked {
            Task {
                var error = NKError()
                var ocId: [String] = []
                for metadata in selectedMetadatas where error == .success {
                    error = await NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: false)
                    if error == .success {
                        ocId.append(metadata.ocId)
                    }
                }
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "onlyLocalCache": false, "error": error])

                isInSelectMode = false
            }
        }
    }
}

// MARK: Notifications

extension NCMediaViewModel {
    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        loadMediaFromDB()

        if error != .success {
            NCContentPresenter.shared.showError(error: error)
        }
    }

    @objc func moveFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        loadMediaFromDB()

        if error != .success {
            NCContentPresenter.shared.showError(error: error)
        }
    }

    @objc func copyFile(_ notification: NSNotification) {
        moveFile(notification)
    }

    @objc func renameFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let account = userInfo["account"] as? String,
              account == appDelegate?.account
        else { return }

        self.loadMediaFromDB()
    }

    @objc func uploadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError,
              error == .success,
              let account = userInfo["account"] as? String,
              account == appDelegate?.account
        else { return }

        self.loadMediaFromDB()
    }

    @objc func userChanged(_ notification: NSNotification) {
        Task {
            await loadNewMedia()
        }
    }
}

// MARK: - Load media

extension NCMediaViewModel {
    func loadMediaFromDB() {
        guard let appDelegate, !appDelegate.account.isEmpty else { return }

        if account != appDelegate.account {
            self.metadatas = []
            account = appDelegate.account
        }

        self.queryDB(isForced: true)
    }

    private func loadOldMedia(value: Int = -30, limit: Int = 300) {
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

        let options = NKRequestOptions(timeout: 300, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.searchMedia(path: mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: CCUtility.getShowHiddenFiles(), options: options) { account, files, _, error in

            if error == .success && account == self.appDelegate?.account {
                if !files.isEmpty {
                    NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, _, metadatas in
                        let predicateDate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                        let predicateResult = NSCompoundPredicate(andPredicateWithSubpredicates: [predicateDate, self.predicateDefault!])
                        let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: predicateResult)
                        let metadatasChanged = NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
                        if metadatasChanged.metadatasUpdate.isEmpty {
                            self.reloadOldMedia(value: value, limit: limit, withElseReloadDataSource: true)
                        } else {
                            self.loadMediaFromDB()
                        }
                    }
                } else {
                    self.reloadOldMedia(value: value, limit: limit, withElseReloadDataSource: false)
                }
            } else if error != .success {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Media search old media error code \(error.errorCode) " + error.errorDescription)
            }
        }
    }

    private func reloadOldMedia(value: Int, limit: Int, withElseReloadDataSource: Bool) {
        if value == -30 {
            loadOldMedia(value: -90)
        } else if value == -90 {
            loadOldMedia(value: -180)
        } else if value == -180 {
            loadOldMedia(value: -999)
        } else if value == -999 && limit > 0 {
            loadOldMedia(value: -999, limit: 0)
        } else {
            if withElseReloadDataSource {
                loadMediaFromDB()
            }
        }
    }

    private func loadNewMedia() async {
        let limit: Int = 1000
        guard let lessDate = Calendar.current.date(byAdding: .second, value: 1, to: Date()) else { return }
        guard let greaterDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }

        let options = NKRequestOptions(timeout: 300, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.searchMedia(path: self.mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: CCUtility.getShowHiddenFiles(), options: options) { account, files, _, error in

                if error == .success && account == self.appDelegate?.account && !files.isEmpty {
                    NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, _, metadatas in
                        let predicate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                        let predicateResult = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, self.predicate!])
                        let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: predicateResult)
                        let updateMetadatas = NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
                        if !updateMetadatas.metadatasUpdate.isEmpty || !updateMetadatas.metadatasDelete.isEmpty {
                            self.loadMediaFromDB()
                        }
                    }
                } else if error == .success && files.isEmpty && self.metadatas.isEmpty {
                    self.loadOldMedia()
                } else if error != .success {
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media error code \(error.errorCode) " + error.errorDescription)
                }

                continuation.resume()
            }
        }
    }
}
