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
    @Published var isLoading = true
//    @Published var hasNewMedia = false
    @Published var hasOldMedia = false
    @Published var triggerLoadMedia = false

    var topMostVisibleMetadata: tableMetadata?
    var bottomMostVisibleMetadata: tableMetadata?

    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    private let cache = NCImageCache.shared

    private var account: String = ""
    private var cancellables: Set<AnyCancellable> = []
    private var timerSearchMedia: Timer?
    private var timeIntervalSearchMedia: TimeInterval = 2.0

    private var showOnlyImages = false
    private var showOnlyVideos = false

    private var isLoadingMedia = false {
        didSet {
            updateLoading()
        }
    }

    private var isLoadingProcessing = false {
        didSet {
            updateLoading()
        }
    }

    init() {
        guard !appDelegate.account.isEmpty else { return }

        if account != appDelegate.account {
            DispatchQueue.main.async { self.metadatas = [] }
            account = appDelegate.account
        }

        guard let accountTable = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else { return }
        let startServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: accountTable.urlBase, userId: accountTable.userId) + accountTable.mediaPath

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userChanged(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)

        if let metadatas = self.cache.initialMetadatas {
            DispatchQueue.main.async { self.metadatas = Array(metadatas.map { tableMetadata.init(value: $0) }) }
        }

        $filter
            .dropFirst()
            .sink { filter in
                switch filter {
                case .all:
                    self.showOnlyImages = false
                    self.showOnlyVideos = false
                case .onlyPhotos:
                    self.showOnlyImages = true
                    self.showOnlyVideos = false
                case .onlyVideos:
                    self.showOnlyImages = false
                    self.showOnlyVideos = true
                }

                self.loadMediaFromDB()
            }
            .store(in: &cancellables)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)
    }

    func deleteMetadata(metadatas: [tableMetadata]) {
        let notLocked = metadatas.allSatisfy { !$0.lock }

        if notLocked {
            delete(metadatas: metadatas)
        }
    }

    func copyOrMoveMetadataInApp(metadatas: [tableMetadata]) {
        isLoadingProcessing = true

        NCActionCenter.shared.openSelectView(items: metadatas, indexPath: [], didCancel: {
            self.isLoadingProcessing = false
        })
    }

    func copyMetadata(metadatas: [tableMetadata]) {
        copy(metadatas: metadatas)
    }

    func onCellTapped(metadata: tableMetadata) {
        appDelegate.activeServerUrl = metadata.serverUrl
    }

    func startLoadingNewMediaTimer() {
        timerSearchMedia?.invalidate()
        timerSearchMedia = Timer.scheduledTimer(timeInterval: timeIntervalSearchMedia, target: self, selector: #selector(notifyLoadNewMedia), userInfo: nil, repeats: false)
    }

    @objc func notifyLoadNewMedia() {
        triggerLoadMedia = true
    }

    func addToFavorites(metadata: tableMetadata) {
        NCNetworking.shared.favoriteMetadata(metadata) { error in
            if error != .success {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    func openIn(metadata: tableMetadata) {
        isLoadingProcessing = true

        if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": NCGlobal.shared.selectorOpenIn, "error": NKError(), "account": metadata.account])
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorOpenIn, notificationCenterProgressTask: false) { _, _ in
                self.isLoadingProcessing = false
            }
        }
    }

    func saveToPhotos(metadata: tableMetadata) {
        isLoadingProcessing = true

        if let livePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            NCNetworking.shared.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: metadata, metadataMOV: livePhoto))
        } else if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
            NCActionCenter.shared.saveAlbum(metadata: metadata)
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum, notificationCenterProgressTask: false) { _, _ in
                self.isLoadingProcessing = false
            }
        }
    }

    func viewInFolder(metadata: tableMetadata) {
        NCActionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileNameBlink: metadata.fileName, fileNameOpen: nil)
    }

    func modify(metadata: tableMetadata) {
        isLoadingProcessing = true

        if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": NCGlobal.shared.selectorLoadFileQuickLook, "error": NKError(), "account": metadata.account])
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook, notificationCenterProgressTask: false) { _, _ in
                self.isLoadingProcessing = false
            }
        }
    }

    func getMetadataFromUrl(_ urlString: String) -> tableMetadata? {
        guard let url = URL(string: urlString) else { return nil }

        let fileName = url.lastPathComponent
        let metadata = NCManageDatabase.shared.createMetadata(account: appDelegate.account, user: appDelegate.user, userId: appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: "", urlBase: appDelegate.urlBase, url: urlString, contentType: "")

        NCManageDatabase.shared.addMetadata(metadata)

        return metadata
    }

    func delete(metadatas: tableMetadata...) {
        delete(metadatas: metadatas)
    }

    func delete(metadatas: [tableMetadata]) {
        isLoadingProcessing = true

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

    func copy(metadatas: tableMetadata...) {
        copy(metadatas: metadatas)
    }

    func copy(metadatas: [tableMetadata]) {
        isLoadingProcessing = true

        NCActionCenter.shared.copyToPasteboard(pasteboardOcIds: metadatas.compactMap({ $0.ocId })) {
            self.isLoadingProcessing = false
        }
    }

    private func updateLoading() {
        isLoading = isLoadingMedia || isLoadingProcessing
    }

    private func getPredicate(showAll: Bool = false) -> NSPredicate {

        let startServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId) + mediaPath

        let showAll = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)

        if predicatedefault { return showAll }

        if showOnlyImages {
            return NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else if showOnlyVideos {
            return NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        } else {
            return showAll
        }
    }
}

// MARK: Notifications

extension NCMediaViewModel {
    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        loadMediaFromDB()

        isLoadingProcessing = false

        if error != .success {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func moveFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        loadMediaFromDB()

        isLoadingProcessing = false

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
              account == appDelegate.account
        else { return }

        self.loadMediaFromDB()
    }

    @objc func uploadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError,
              error == .success,
              let account = userInfo["account"] as? String,
              account == appDelegate.account
        else { return }

        self.loadMediaFromDB()
    }

    @objc func userChanged(_ notification: NSNotification) {
        if let metadatas = self.cache.initialMetadatas {
            DispatchQueue.main.async { self.metadatas = Array(metadatas.map { tableMetadata.init(value: $0) }) }
        }
    }
}

// MARK: - Load media

extension NCMediaViewModel {
    func searchMedia(from fromDate: Date?, to toDate: Date?, isScrolledToTop: Bool, isScrolledToBottom: Bool) {
        var finalFutureDate: Date
        var finalPastDate: Date

        if isScrolledToTop {
            finalFutureDate = Date.distantFuture
        } else {
            if let date = toDate {
                finalFutureDate = Calendar.current.date(byAdding: .second, value: 1, to: date)!
            } else {
                finalFutureDate = Date.distantFuture
            }
        }

        if isScrolledToBottom {
            finalPastDate = Date.distantPast
        } else {
            if let date = fromDate {
                finalPastDate = Calendar.current.date(byAdding: .second, value: -1, to: date)!
            } else {
                finalPastDate = Date.distantPast
            }
        }

        print("Searching for media...")
        print("From: \(NCUtility().getTitleFromDate(finalPastDate))")
        print("To: \(NCUtility().getTitleFromDate(finalFutureDate))")

        isLoadingMedia = true
        hasOldMedia = true

        Task {
            let results = await updateMedia(account: appDelegate.account, lessDate: finalFutureDate, greaterDate: finalPastDate, predicate: self.getPredicate(true))
            isLoadingMedia = false

            print("Media results changed items: \(results.changedItems)")

            if results.error != .success {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Media search new media error code \(results.error.errorCode) " + results.error.errorDescription)
            }

            DispatchQueue.main.async {
                if results.error == .success, results.lessDate == Date.distantFuture, results.greaterDate == Date.distantPast, results.changedItems == 0, results.metadatas.isEmpty {
                    self.metadatas.removeAll()
                    self.loadMediaFromDB()
                }
            }

            if results.changedItems > 0 {
                self.loadMediaFromDB()
            } else {
                if finalPastDate == Date.distantPast {
                    hasOldMedia = false
                }
            }
        }
    }

    private func updateMedia(account: String, lessDate: Date, greaterDate: Date, limit: Int = 1000, timeout: TimeInterval = 60, predicate: NSPredicate) async -> MediaResult {
        guard let mediaPath = NCManageDatabase.shared.getActiveAccount()?.mediaPath else {
            return MediaResult(account: account, lessDate: lessDate, greaterDate: greaterDate, metadatas: [], changedItems: 0, error: NKError())
        }

        let options = NKRequestOptions(timeout: timeout, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let results = await NextcloudKit.shared.searchMedia(path: mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: NCKeychain().showHiddenFiles, includeHiddenFiles: [], options: options)

        return await withCheckedContinuation { continuation in
            if results.account == account, results.error == .success {
                NCManageDatabase.shared.convertFilesToMetadatas(results.files, useMetadataFolder: false) { _, _, metadatas in
                    let predicate = NSPredicate(format: "date > %@ AND date < %@", greaterDate as NSDate, lessDate as NSDate)
                    let result = NCManageDatabase.shared.updateMetadatas(metadatas, predicate: predicate)

                    if result.metadatasChangedCount != 0 || result.metadatasChanged {
                        continuation.resume(returning: MediaResult(account: account, lessDate: lessDate, greaterDate: greaterDate, metadatas: metadatas, changedItems: result.metadatasChangedCount, error: results.error))
                    } else {
                        continuation.resume(returning: MediaResult(account: account, lessDate: lessDate, greaterDate: greaterDate, metadatas: [], changedItems: 0, error: results.error))
                    }
                }
            }
        }
    }

    func loadMediaFromDB(showPhotos: Bool = true, showVideos: Bool = true) {
        guard !appDelegate.account.isEmpty else { return }

        if account != appDelegate.account {
            DispatchQueue.main.async { self.metadatas = [] }
            account = appDelegate.account
        }

        guard let accountTable = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else { return }

        if let metadatas = self.cache.getMediaMetadatas(account: self.account, predicate: self.getPredicate()) {
            // Create reference to current thread
            let metadatasRef = NCManageDatabase.shared.getThreadSafeReference(ofRealmObject: metadatas)

            DispatchQueue.main.async {
                // Check if reference is safe to be read on new thread
                if let metadatas = NCManageDatabase.shared.resolveThreadSafeReference(of: metadatasRef) {

                    // TODO: Remove copying of whole array and use Realm Results<> instead. This will lead to pointer instead of making a whole new array and will be faster.
                    self.metadatas = Array(metadatas.map { tableMetadata.init(value: $0) })
                }
            }
        }
    }
}

extension NCMediaViewModel: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], indexPath: [IndexPath], overwrite: Bool, copy: Bool, move: Bool) {
        guard let serverUrl else { return }

        let home = NCUtilityFileSystem().getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        let path = serverUrl.replacingOccurrences(of: home, with: "")
        NCManageDatabase.shared.setAccountMediaPath(path, account: appDelegate.account)

        self.loadMediaFromDB()
    }
}

enum Filter {
    case onlyPhotos, onlyVideos, all
}

private struct MediaResult {
    let account: String, lessDate: Date?, greaterDate: Date?, metadatas: [tableMetadata], changedItems: Int, error: NKError
}
