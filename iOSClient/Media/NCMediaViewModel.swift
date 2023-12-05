//
//  NCMediaViewModel.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import NextcloudKit
import Combine
import LRUCache
import RealmSwift

@MainActor class NCMediaViewModel: ObservableObject {
    @Published var metadatas: [tableMetadata] = []
    @Published var filter = Filter.all
    @Published var isLoadingMetadata = true
    @Published var hasNewMedia = false
    @Published var hasOldMedia = true

    internal let appDelegate = UIApplication.shared.delegate as? AppDelegate

    private let cache = NCImageCache.shared

    private var account: String = ""
    private var lastContentOffsetY: CGFloat = 0
    private var mediaPath = ""
    private var livePhoto: Bool = false
    private var predicateDefault: NSPredicate?
    private var predicate: NSPredicate?
    private var cancellables: Set<AnyCancellable> = []
    private var timerSearchNewMedia: Timer?
    private var timeIntervalSearchNewMedia: TimeInterval = 10.0

    private var isLoadingNewMetadata = false {
        didSet {
            updateLoadingMedia()
        }
    }

    private var isLoadingOldMetadata = false {
        didSet {
            updateLoadingMedia()
        }
    }

    private var isLoadingProcessingMetadata = false {
        didSet {
            updateLoadingMedia()
        }
    }

    init() {
        guard let appDelegate, !appDelegate.account.isEmpty else { return }

        if account != appDelegate.account {
            DispatchQueue.main.async { self.metadatas = [] }
            account = appDelegate.account
        }

        guard let accountTable = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else { return }
        let startServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: accountTable.urlBase, userId: accountTable.userId) + accountTable.mediaPath

        predicateDefault = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND NOT (session CONTAINS[c] 'upload')", account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userChanged(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)

        if let metadatas = self.cache.initialMetadatas() {
            DispatchQueue.main.async { self.metadatas = Array(metadatas.map { tableMetadata.init(value: $0) }) }
        }

        Task {
            await loadNewMedia()
        }

        $filter
            .dropFirst()
            .sink { filter in
                switch filter {
                case .all:
                    self.loadMediaFromDB(showPhotos: true, showVideos: true)
                case .onlyPhotos:
                    self.loadMediaFromDB(showPhotos: true, showVideos: false)
                case .onlyVideos:
                    self.loadMediaFromDB(showPhotos: false, showVideos: true)
                }
            }
            .store(in: &cancellables)

        //        timerSearchNewMedia?.invalidate()
        timerSearchNewMedia = Timer.scheduledTimer(timeInterval: 20.0, target: self, selector: #selector(onRefresh), userInfo: nil, repeats: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)
    }

    public func loadMoreItems() {
        loadOldMedia()
    }

    public func deleteMetadata(metadatas: [tableMetadata]) {
        let notLocked = metadatas.allSatisfy { !$0.lock }

        if notLocked {
            delete(metadatas: metadatas)
        }
    }

    public func copyOrMoveMetadataInApp(metadatas: [tableMetadata]) {
        isLoadingProcessingMetadata = true

        NCActionCenter.shared.openSelectView(items: metadatas, indexPath: [], didCancel: {
            self.isLoadingProcessingMetadata = false
        })
    }

    public func copyMetadata(metadatas: [tableMetadata]) {
        copy(metadatas: metadatas)
    }

    public func onCellTapped(metadata: tableMetadata) {
        appDelegate?.activeServerUrl = metadata.serverUrl
    }

    @objc public func onRefresh() {
        Task {
            await loadNewMedia()
        }
    }

    public func addToFavorites(metadata: tableMetadata) {
        NCNetworking.shared.favoriteMetadata(metadata) { error in
            if error != .success {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    public func openIn(metadata: tableMetadata) {
        isLoadingProcessingMetadata = true

        if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": NCGlobal.shared.selectorOpenIn, "error": NKError(), "account": metadata.account])
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorOpenIn, notificationCenterProgressTask: false) { _, _ in
                self.isLoadingProcessingMetadata = false
            }
        }
    }

    public func saveToPhotos(metadata: tableMetadata) {
        isLoadingProcessingMetadata = true

        if let livePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            guard let appDelegate else { return }
            appDelegate.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: metadata, metadataMOV: livePhoto))
        } else if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
            NCActionCenter.shared.saveAlbum(metadata: metadata)
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum, notificationCenterProgressTask: false) { _, _ in
                self.isLoadingProcessingMetadata = false
            }
        }
    }

    public func viewInFolder(metadata: tableMetadata) {
        NCActionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileNameBlink: metadata.fileName, fileNameOpen: nil)
    }

    public func modify(metadata: tableMetadata) {
        isLoadingProcessingMetadata = true

        if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": NCGlobal.shared.selectorLoadFileQuickLook, "error": NKError(), "account": metadata.account])
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook, notificationCenterProgressTask: false) { _, _ in
                self.isLoadingProcessingMetadata = false
            }
        }
    }

    public func getMetadataFromUrl(_ urlString: String) -> tableMetadata? {
        guard let url = URL(string: urlString), let appDelegate else { return nil }

        let fileName = url.lastPathComponent
        let metadata = NCManageDatabase.shared.createMetadata(account: appDelegate.account, user: appDelegate.user, userId: appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: "", urlBase: appDelegate.urlBase, url: urlString, contentType: "")

        NCManageDatabase.shared.addMetadata(metadata)

        return metadata
    }

    public func delete(metadatas: tableMetadata...) {
        delete(metadatas: metadatas)
    }

    public func delete(metadatas: [tableMetadata]) {
        isLoadingProcessingMetadata = true

        Task {
            var error = NKError()
            var ocId: [String] = []
            for metadata in metadatas where error == .success {
                error = await NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: false)
                if error == .success {
                    ocId.append(metadata.ocId)
                }
            }

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "onlyLocalCache": false, "error": error])
        }
    }

    public func copy(metadatas: tableMetadata...) {
        copy(metadatas: metadatas)
    }

    public func copy(metadatas: [tableMetadata]) {
        isLoadingProcessingMetadata = true

        NCActionCenter.shared.copyToPasteboard(pasteboardOcIds: metadatas.compactMap({ $0.ocId })) {
            self.isLoadingProcessingMetadata = false
        }
    }

    private func updateLoadingMedia() {
        isLoadingMetadata = isLoadingNewMetadata || isLoadingOldMetadata || isLoadingProcessingMetadata
    }
}

// MARK: Notifications

extension NCMediaViewModel {
    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        loadMediaFromDB()

        isLoadingProcessingMetadata = false

        if error != .success {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func moveFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        loadMediaFromDB()

        isLoadingProcessingMetadata = false

        if error != .success {
            NCContentPresenter().showError(error: error)
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
        self.loadMediaFromDB()

        Task {
            await loadNewMedia()
        }
    }
}

// MARK: - Load media

extension NCMediaViewModel {
    func loadMediaFromDB(showPhotos: Bool = true, showVideos: Bool = true) {
        guard let appDelegate, !appDelegate.account.isEmpty else { return }

        if account != appDelegate.account {
            DispatchQueue.main.async { self.metadatas = [] }
            account = appDelegate.account
        }

        guard let accountTable = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else { return }
        let startServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: accountTable.urlBase, userId: accountTable.userId) + accountTable.mediaPath

        if showPhotos, showVideos {
            predicate = predicateDefault
        } else if showPhotos {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else if showVideos {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        }

        DispatchQueue.global(qos: .background).async {
            if let metadatas = self.cache.getMediaMetadatas(account: self.account, predicate: self.predicate) {
                DispatchQueue.main.async { self.metadatas = Array(metadatas.map { tableMetadata.init(value: $0) }) }
            }
        }
    }

    private func loadOldMedia(value: Int = -30, limit: Int = 300) {
        if isLoadingOldMetadata { return }

        var lessDate = Date()

        DispatchQueue.main.async {
            self.isLoadingOldMetadata = true
        }

        if let predicateDefault {
            if let metadata = NCManageDatabase.shared.getMetadata(predicate: predicateDefault, sorted: "date", ascending: true) {
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

        NextcloudKit.shared.searchMedia(path: mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: NCKeychain().showHiddenFiles, options: options) { account, files, _, error in

            if error == .success && account == self.appDelegate?.account {
                if !files.isEmpty {
                    NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, _, metadatas in
                        let predicateDate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicateDate, self.predicateDefault!])
                        //                        let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: predicateResult)
                        let result = NCManageDatabase.shared.updateMetadatas(metadatas, predicate: predicate)
                        if result.metadatasChangedCount == 0 {
                            self.reloadOldMedia(value: value, limit: limit, withElseReloadDataSource: true)
                        } else {
                            self.loadMediaFromDB()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.hasOldMedia = false
                    }
                    self.reloadOldMedia(value: value, limit: limit, withElseReloadDataSource: false)
                }
            } else if error != .success {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Media search old media error code \(error.errorCode) " + error.errorDescription)
            }

            DispatchQueue.main.async {
                self.isLoadingOldMetadata = false
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

    private func updateMedia(account: String, lessDate: Date, greaterDate: Date, limit: Int = 200, timeout: TimeInterval = 60, predicateDB: NSPredicate) async -> MediaResult {

        guard let mediaPath = NCManageDatabase.shared.getActiveAccount()?.mediaPath else {
            return MediaResult(account: account, lessDate: lessDate, greaterDate: greaterDate, metadatas: [], changedItems: 0, error: NKError())
        }
        let options = NKRequestOptions(timeout: timeout, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let results = await NextcloudKit.shared.searchMedia(path: mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: NCKeychain().showHiddenFiles, includeHiddenFiles: [], options: options)

        if results.account == account, results.error == .success {
            return await withCheckedContinuation { continuation in
                NCManageDatabase.shared.convertFilesToMetadatas(results.files, useMetadataFolder: false) { _, _, metadatas in
                    let predicate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                    let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, (self.predicate ?? self.predicateDefault!)])
                    //            let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: compoundPredicate)
                    let result = NCManageDatabase.shared.updateMetadatas(metadatas, predicate: compoundPredicate)
                    if result.metadatasChangedCount != 0 || result.metadatasChanged {
                        continuation.resume(returning: MediaResult(account: account, lessDate: lessDate, greaterDate: greaterDate, metadatas: metadatas, changedItems: result.metadatasChangedCount, error: results.error))
                    }
                }
            }
        }
        return MediaResult(account: account, lessDate: lessDate, greaterDate: greaterDate, metadatas: [], changedItems: 0, error: results.error)
    }

    private func loadNewMedia() async {
        let limit: Int = 1000
        guard let lessDate = Calendar.current.date(byAdding: .second, value: 1, to: Date()) else { return }
        guard let greaterDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }

        //        let options = NKRequestOptions(timeout: 300, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        //        DispatchQueue.main.async {
        isLoadingNewMetadata = true
        //        }

        let result = await updateMedia(account: account, lessDate: lessDate, greaterDate: greaterDate, predicateDB: (self.predicate ?? self.predicateDefault!))

        isLoadingNewMetadata = false

        if result.changedItems > 0 {
            loadMediaFromDB()
            hasNewMedia = true
        }
        //        return await withCheckedContinuation { continuation in
        //            NextcloudKit.shared.searchMedia(path: self.mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: NCKeychain().showHiddenFiles, options: options) { account, files, _, error in
        //
        //                if error == .success && account == self.appDelegate?.account && !files.isEmpty {
        //                    NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, _, metadatas in
        //                        let predicate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
        //                        let predicateResult = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, (self.predicate ?? self.predicateDefault!)])
        //                        let metadatasResult = NCManageDatabase.shared.getMetadatas(predicate: predicateResult)
        //                        let updateMetadatas = NCManageDatabase.shared.updateMetadatas(metadatas, metadatasResult: metadatasResult, addCompareLivePhoto: false)
        //                        if !updateMetadatas.metadatasUpdate.isEmpty || !updateMetadatas.metadatasDelete.isEmpty {
        //                            DispatchQueue.main.async {
        //                                self.loadMediaFromDB()
        //                                self.hasNewMedia = true
        //                            }
        //                        }
        //                    }
        //                } else if error == .success && files.isEmpty && self.metadatas.isEmpty {
        //                    self.loadOldMedia()
        //                } else if error != .success {
        //                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media error code \(error.errorCode) " + error.errorDescription)
        //                }
        //
        //                DispatchQueue.main.async {
        //                    self.isLoadingNewMetadata = false
        //                }
        //
        //                continuation.resume()
        //            }
        //        }
    }
}

extension NCMediaViewModel: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], indexPath: [IndexPath], overwrite: Bool, copy: Bool, move: Bool) {
        guard let serverUrl, let appDelegate else { return }

        let home = NCUtilityFileSystem().getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        let path = serverUrl.replacingOccurrences(of: home, with: "")
        NCManageDatabase.shared.setAccountMediaPath(path, account: appDelegate.account)

        self.loadMediaFromDB()

        Task {
            await loadNewMedia()
        }
    }
}

enum Filter {
    case onlyPhotos, onlyVideos, all
}

private struct MediaResult {
    let account: String, lessDate: Date?, greaterDate: Date?, metadatas: [tableMetadata], changedItems: Int, error: NKError
}
