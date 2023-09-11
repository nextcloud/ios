//
//  NCMediaViewModel.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import NextcloudKit

@MainActor class NCMediaViewModel: ObservableObject {
    @Published var metadatas: [tableMetadata] = []

    private var account: String = ""
    private var lastContentOffsetY: CGFloat = 0
    private var mediaPath = ""
    private var livePhoto: Bool = false
    private var predicateDefault: NSPredicate?
    private var predicate: NSPredicate?
    private let appDelegate = UIApplication.shared.delegate as? AppDelegate
    internal var filterClassTypeImage = false
    internal var filterClassTypeVideo = false

    init() {
        reloadDataSourceWithCompletion { _ in }

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
    }

    @objc func reloadDataSourceWithCompletion(_ completion: @escaping (_ metadatas: [tableMetadata]) -> Void) {
        guard let appDelegate, !appDelegate.account.isEmpty else { return }

        if account != appDelegate.account {
            self.metadatas = []
            account = appDelegate.account
        }

        self.queryDB(isForced: true)
    }

    func queryDB(isForced: Bool = false) {
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

        metadatas = NCManageDatabase.shared.getMetadatasMedia(predicate: predicate, livePhoto: self.livePhoto)

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

// MARK: Notifications

extension NCMediaViewModel {
    @objc func deleteFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }
        let onlyLocalCache: Bool = userInfo["onlyLocalCache"] as? Bool ?? false

        self.queryDB(isForced: true)

        if error == .success, let indexPath = userInfo["indexPath"] as? [IndexPath], !indexPath.isEmpty, !onlyLocalCache {
            //            collectionView?.performBatchUpdates({
            //                collectionView?.deleteItems(at: indexPath)
            //            }, completion: { _ in
            //                self.collectionView?.reloadData()
            //            })
        } else {
            if error != .success {
                NCContentPresenter.shared.showError(error: error)
            }
            //            self.collectionView?.reloadData()
        }

        //        if let hud = userInfo["hud"] as? JGProgressHUD {
        //            hud.dismiss()
        //        }
    }

    @objc func moveFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary? else { return }

        //        if let hud = userInfo["hud"] as? JGProgressHUD {
        //            hud.dismiss()
        //        }
    }

    @objc func copyFile(_ notification: NSNotification) {

        moveFile(notification)
    }

    @objc func renameFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let account = userInfo["account"] as? String,
              account == appDelegate?.account
        else { return }

        self.reloadDataSourceWithCompletion { _ in }
    }

    @objc func uploadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError,
              error == .success,
              let account = userInfo["account"] as? String,
              account == appDelegate?.account
        else { return }

        self.reloadDataSourceWithCompletion { _ in }
    }
}
