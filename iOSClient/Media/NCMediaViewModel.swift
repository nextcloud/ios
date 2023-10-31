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

@MainActor class NCMediaViewModel: ObservableObject {
    @Published private(set) internal var metadatas: [tableMetadata] = []

    private var account: String = ""
    private var lastContentOffsetY: CGFloat = 0
    private var mediaPath = ""
    private var livePhoto: Bool = false
    private var predicateDefault: NSPredicate?
    private var predicate: NSPredicate?
    internal let appDelegate = UIApplication.shared.delegate as? AppDelegate

    private var cancellables: Set<AnyCancellable> = []

    @Published internal var needsLoadingMoreItems = true
    @Published internal var filter = Filter.all

    private let cache = NCImageCache.shared

    private var newAndOldMediaAlreadyLoaded = false

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userChanged(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)

        metadatas = cache.metadatas

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

                self.cancelSelection()
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

    /*
    private func queryDB(isForced: Bool = false, showPhotos: Bool = true, showVideos: Bool = true) {
        guard let appDelegate else { return }

        livePhoto = NCKeychain().livePhoto

        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
            self.mediaPath = activeAccount.mediaPath
        }

        let startServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId) + mediaPath

        predicateDefault = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)

        if showPhotos, showVideos {
            predicate = predicateDefault
        } else if showPhotos {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else if showVideos {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        }

        guard let predicate = predicate else { return }

        DispatchQueue.main.async {
            self.metadatas = NCManageDatabase.shared.getMetadatasMedia(predicate: predicate, livePhoto: self.livePhoto)

            switch NCKeychain().mediaSortDate {
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
    */

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

    func deleteMetadata(metadatas: [tableMetadata]) {
        let notLocked = metadatas.allSatisfy { !$0.lock }

        if notLocked {
            delete(metadatas: metadatas)
        }
    }

    func copyOrMoveMetadataInApp(metadatas: [tableMetadata]) {
        NCActionCenter.shared.openSelectView(items: metadatas, indexPath: [])
//        cancelSelection()
    }

    func copyMetadata(metadatas: [tableMetadata]) {
        copy(metadatas: metadatas)
//        cancelSelection()
    }

    func addToFavorites(metadata: tableMetadata) {
        NCNetworking.shared.favoriteMetadata(metadata) { error in
            if error != .success {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    func openIn(metadata: tableMetadata) {
        if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": NCGlobal.shared.selectorOpenIn, "error": NKError(), "account": metadata.account])
        } else {
//            hud.show(in: viewController.view)
            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorOpenIn, notificationCenterProgressTask: false)
//            { request in
//                downloadRequest = request
//            } progressHandler: { progress in
//                hud.progress = Float(progress.fractionCompleted)
//            } completion:
            { afError, error in
                if error == .success || afError?.isExplicitlyCancelledError ?? false {
//                    hud.dismiss()
                } else {
//                    hud.indicatorView = JGProgressHUDErrorIndicatorView()
//                    hud.textLabel.text = error.description
//                    hud.dismiss(afterDelay: NCGlobal.shared.dismissAfterSecond)
                }
            }
        }
    }

    func saveToPhotos(metadata: tableMetadata) {
        if let livePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            guard let appDelegate else { return }
            appDelegate.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: metadata, metadataMOV: livePhoto))
        } else if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
            NCActionCenter.shared.saveAlbum(metadata: metadata)
        } else {
            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum, notificationCenterProgressTask: false) { request in
//                downloadRequest = request
            } progressHandler: { progress in
//                hud.progress = Float(progress.fractionCompleted)
            } completion: { afError, error in
//                if error == .success || afError?.isExplicitlyCancelledError ?? false {
//                    hud.dismiss()
//                } else {
//                    hud.indicatorView = JGProgressHUDErrorIndicatorView()
//                    hud.textLabel.text = error.description
//                    hud.dismiss(afterDelay: NCGlobal.shared.dismissAfterSecond)
//                }
            }
        }
    }

    func viewInFolder(metadata: tableMetadata) {
        NCActionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileNameBlink: metadata.fileName, fileNameOpen: nil)
    }

    func modify(metadata: tableMetadata) {
        if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": NCGlobal.shared.selectorLoadFileQuickLook, "error": NKError(), "account": metadata.account])
        } else {
//            hud.show(in: viewController.view)
            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook, notificationCenterProgressTask: false) { request in
//                downloadRequest = request
            } progressHandler: { progress in
//                hud.progress = Float(progress.fractionCompleted)
            } completion: { afError, error in
//                if error == .success || afError?.isExplicitlyCancelledError ?? false {
//                    hud.dismiss()
//                } else {
//                    hud.indicatorView = JGProgressHUDErrorIndicatorView()
//                    hud.textLabel.text = error.description
//                    hud.dismiss(afterDelay: NCGlobal.shared.dismissAfterSecond)
//                }
            }
        }
    }

    func getMetadataFromUrl(_ urlString: String) -> tableMetadata? {
        guard let url = URL(string: urlString), let appDelegate else { return nil }

        let fileName = url.lastPathComponent
        let metadata = NCManageDatabase.shared.createMetadata(account: appDelegate.account, user: appDelegate.user, userId: appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: "", urlBase: appDelegate.urlBase, url: urlString, contentType: "")

        NCManageDatabase.shared.addMetadata(metadata)

        return metadata
    }

    func delete(metadatas: tableMetadata...) {
        delete(metadatas: metadatas)
    }

    func delete(metadatas: [tableMetadata]) {
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

//            isInSelectMode = false
        }
    }

    func copy(metadatas: tableMetadata...) {
        copy(metadatas: metadatas)
    }

    func copy(metadatas: [tableMetadata]) {
        NCActionCenter.shared.copyPasteboard(pasteboardOcIds: metadatas.compactMap({ $0.ocId }))
    }

    private func cancelSelection() {
//        self.isInSelectMode = false
//        self.selectedMetadatas.removeAll()
    }
}

// MARK: Notifications

extension NCMediaViewModel {
    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        loadMediaFromDB()

        if error != .success {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func moveFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        loadMediaFromDB()

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
            self.metadatas = []
            account = appDelegate.account
        }

        guard let accountTable = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else { return }
        let startServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: accountTable.urlBase, userId: accountTable.userId) + accountTable.mediaPath

        predicateDefault = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND NOT (session CONTAINS[c] 'upload')", account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)

        if showPhotos, showVideos {
            predicate = predicateDefault
        } else if showPhotos {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else if showVideos {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        }

        DispatchQueue.global(qos: .background).async {
            self.cache.getMediaMetadatas(account: self.account, predicate: self.predicate)

            DispatchQueue.main.async {
                self.metadatas = self.cache.metadatas
            }
        }
    }

    private func loadOldMedia(value: Int = -30, limit: Int = 300) {
        var lessDate = Date()
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

            DispatchQueue.main.async {
                self.needsLoadingMoreItems = false
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
            NextcloudKit.shared.searchMedia(path: self.mediaPath, lessDate: lessDate, greaterDate: greaterDate, elementDate: "d:getlastmodified/", limit: limit, showHiddenFiles: NCKeychain().showHiddenFiles, options: options) { account, files, _, error in

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
