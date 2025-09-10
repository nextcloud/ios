// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift
import SwiftUI

class NCFiles: NCCollectionViewCommon {
    internal var fileNameBlink: String?
    internal var fileNameOpen: String?

    internal var lastOffsetY: CGFloat = 0
    internal var lastScrollTime: TimeInterval = 0
    internal var accumulatedScrollDown: CGFloat = 0

    internal var syncMetadatasTask: Task<Void, Never>?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NCBrandOptions.shared.brand
        layoutKey = NCGlobal.shared.layoutViewFiles
        enableSearchBar = true
        headerRichWorkspaceDisable = false
        emptyTitle = "_files_no_files_"
        emptyDescription = "_no_file_pull_down_"
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil, queue: nil) { notification in
            Task { @MainActor in
                if let userInfo = notification.userInfo,
                   let account = userInfo["account"] as? String,
                   self.controller?.account == account {
                    let color = NCBrandColor.shared.getElement(account: account)
                    self.mainNavigationController?.plusItem?.tintColor = color
                }
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.stopSyncMetadata()
        }

        if self.serverUrl.isEmpty {
            //
            // Set ServerURL when start (isEmpty)
            //
            self.serverUrl = utilityFileSystem.getHomeServer(session: session)
            self.titleCurrentFolder = getNavigationTitle()

            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil, queue: nil) { notification in
                Task { @MainActor in
                    if let userInfo = notification.userInfo,
                       let controller = userInfo["controller"] as? NCMainTabBarController {
                        guard controller == self.controller else {
                            return
                        }
                    }
                    if let userInfo = notification.userInfo,
                       let account = userInfo["account"] as? String {
                        let color = NCBrandColor.shared.getElement(account: account)
                        self.mainNavigationController?.plusItem?.tintColor = color
                    }

                    self.navigationController?.popToRootViewController(animated: false)
                    self.serverUrl = self.utilityFileSystem.getHomeServer(session: self.session)
                    self.isSearchingMode = false
                    self.isEditMode = false
                    self.fileSelect.removeAll()
                    self.layoutForView = self.database.getLayoutForView(account: self.session.account, key: self.layoutKey, serverUrl: self.serverUrl)

                    if self.isLayoutList {
                        self.collectionView?.collectionViewLayout = self.listLayout
                    } else if self.isLayoutGrid {
                        self.collectionView?.collectionViewLayout = self.gridLayout
                    } else if self.isLayoutPhoto {
                        self.collectionView?.collectionViewLayout = self.mediaLayout
                    }

                    self.titleCurrentFolder = self.getNavigationTitle()
                    self.navigationItem.title = self.titleCurrentFolder

                    await (self.navigationController as? NCMainNavigationController)?.setNavigationLeftItems()
                    await self.reloadDataSource()
                    await self.getServerData()
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        resetPlusButtonAlpha()
        Task {
            await self.reloadDataSource()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !self.dataSource.isEmpty() {
            self.blinkCell(fileName: self.fileNameBlink)
            self.openFile(fileName: self.fileNameOpen)
            self.fileNameBlink = nil
            self.fileNameOpen = nil
        }

        if !isSearchingMode {
            Task {
                await getServerData()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        stopSyncMetadata()
        Task {
            await NCNetworking.shared.networkingTasks.cancel(identifier: "\(self.serverUrl)_NCFiles")
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        fileNameBlink = nil
        fileNameOpen = nil
    }

    // MARK: - DataSource

    override func reloadDataSource() async {
        guard !isSearchingMode else {
            await super.reloadDataSource()
            return
        }

        let personalFilesOnly = NCPreferences().getPersonalFilesOnly(account: self.session.account)
        let predicate: NSPredicate = {
            if personalFilesOnly {
                return self.personalFilesOnlyPredicate
            } else {
                return self.defaultPredicate
            }
        }()

        self.metadataFolder = await self.database.getMetadataFolderAsync(session: self.session, serverUrl: self.serverUrl)
        if let tblDirectory = await self.database.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.session.account, self.serverUrl)) {
            self.richWorkspaceText = tblDirectory.richWorkspace
        }
        if let metadataFolder {
            nkLog(info: "Inside metadata folder \(metadataFolder.fileName) with permissions: \(metadataFolder.permissions)")

            // disable + button if no create permission
            let color = NCBrandColor.shared.getElement(account: self.session.account)

            self.mainNavigationController?.plusItem?.isEnabled = metadataFolder.isCreatable
            self.mainNavigationController?.plusItem?.tintColor = metadataFolder.isCreatable ? color : .lightGray

            // plusButton.isEnabled = metadataFolder.isCreatable
            // plusButton.backgroundColor = metadataFolder.isCreatable ? color : .lightGray
        }

        let metadatas = await self.database.getMetadatasAsync(predicate: predicate,
                                                              withLayout: self.layoutForView,
                                                              withAccount: self.session.account)

        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas,
                                                     layoutForView: layoutForView,
                                                     account: session.account)
        await super.reloadDataSource()

        cachingAsync(metadatas: metadatas)
    }

    override func getServerData(forced: Bool = false) async {
        defer {
            restoreDefaultTitle()
            startSyncMetadata(metadatas: self.dataSource.getMetadatas())
        }

        Task {
            await networking.networkingTasks.cancel(identifier: "\(self.serverUrl)_NCFiles")
        }

        guard !isSearchingMode else {
            return networkSearch()
        }

        func downloadMetadata(_ metadata: tableMetadata) async -> Bool {
            let fileSize = utilityFileSystem.fileProviderStorageSize(metadata.ocId,
                                                                     fileName: metadata.fileNameView,
                                                                     userId: metadata.userId,
                                                                     urlBase: metadata.urlBase)
            guard fileSize > 0 else { return false }

            if let tblLocalFile = await database.getTableLocalFileAsync(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                if tblLocalFile.etag != metadata.etag {
                    return true
                }
            }
            return false
        }

        let resultsReadFolder = await networkReadFolderAsync(serverUrl: self.serverUrl, forced: forced)
        guard resultsReadFolder.error == .success, resultsReadFolder.reloadRequired else {
            return
        }

        let metadatasForDownload: [tableMetadata] = resultsReadFolder.metadatas ?? self.dataSource.getMetadatas()
        Task.detached(priority: .utility) {
            for metadata in metadatasForDownload where !metadata.directory {
                if await downloadMetadata(metadata) {
                    if let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                                session: NCNetworking.shared.sessionDownload,
                                                                                                selector: NCGlobal.shared.selectorDownloadFile,
                                                                                                sceneIdentifier: self.controller?.sceneIdentifier) {
                        await NCNetworking.shared.downloadFile(metadata: metadata)
                    }
                }
            }
        }

        await self.reloadDataSource()
    }

    private func networkReadFolderAsync(serverUrl: String, forced: Bool) async -> (metadatas: [tableMetadata]?, error: NKError, reloadRequired: Bool) {
        let resultsReadFile = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrl, account: session.account) { task in
            Task {
                await NCNetworking.shared.networkingTasks.track(identifier: "\(self.serverUrl)_NCFiles", task: task)
            }
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        }
        guard resultsReadFile.error == .success, let metadata = resultsReadFile.metadata else {
            return (nil, resultsReadFile.error, false)
        }
        let e2eEncrypted = metadata.e2eEncrypted
        let ocId = metadata.ocId

        await self.database.updateDirectoryRichWorkspaceAsync(metadata.richWorkspace, account: resultsReadFile.account, serverUrl: serverUrl)
        let tableDirectory = await self.database.getTableDirectoryAsync(ocId: metadata.ocId)

        let shouldSkipUpdate: Bool = (
            !forced &&
            tableDirectory?.etag == metadata.etag &&
            !metadata.e2eEncrypted &&
            !self.dataSource.isEmpty()
        )

        if shouldSkipUpdate {
            return (nil, NKError(), false)
        }

        showLoadingTitle()

        let options = NKRequestOptions(timeout: 180)
        let (account, metadataFolder, metadatas, error) = await NCNetworking.shared.readFolderAsync(serverUrl: serverUrl,
                                                                                                    account: session.account,
                                                                                                    options: options) { task in
            Task {
                await NCNetworking.shared.networkingTasks.track(identifier: "\(self.serverUrl)_NCFiles", task: task)
            }
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        }

        guard error == .success else {
            return (nil, error, false)
        }

        if let metadataFolder {
            self.metadataFolder = metadataFolder.detachedCopy()
            self.richWorkspaceText = metadataFolder.richWorkspace
        }

        //
        // E2EE section
        //

        guard e2eEncrypted,
              let metadatas,
              !metadatas.isEmpty,
              NCPreferences().isEndToEndEnabled(account: account),
              await !NCNetworkingE2EE().isInUpload(account: account, serverUrl: serverUrl) else {
            return (metadatas, error, true)
        }

        let lock = await self.database.getE2ETokenLockAsync(account: account, serverUrl: serverUrl)
        if let e2eToken = lock?.e2eToken {
            nkLog(tag: self.global.logTagE2EE, message: "Tocken: \(e2eToken)", minimumLogLevel: .verbose)
        }

        let results = await NCNetworkingE2EE().getMetadata(fileId: ocId, e2eToken: lock?.e2eToken, account: account)

        nkLog(tag: self.global.logTagE2EE, message: "Get metadata with error: \(results.error.errorCode)")
        nkLog(tag: self.global.logTagE2EE, message: "Get metadata with metadata: \(results.e2eMetadata ?? ""), signature: \(results.signature ?? ""), version \(results.version ?? "")", minimumLogLevel: .verbose)

        guard results.error == .success,
              let e2eMetadata = results.e2eMetadata,
              let version = results.version else {

            // No metadata fount, re-send it
            if results.error.errorCode == NCGlobal.shared.errorResourceNotFound {
                NCContentPresenter().showInfo(description: "Metadata not found")
                let error = await NCNetworkingE2EE().uploadMetadata(serverUrl: serverUrl, account: account)
                if error != .success {
                    NCContentPresenter().showError(error: error)
                }
            } else {
                // show error
                NCContentPresenter().showError(error: results.error)
            }

            return (metadatas, error, true)
        }

        let errorDecodeMetadata = await NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: results.signature, serverUrl: serverUrl, session: self.session)
        nkLog(debug: "Decode e2ee metadata with error: \(errorDecodeMetadata.errorCode)")

        if errorDecodeMetadata == .success {
            let capabilities = await NKCapabilities.shared.getCapabilities(for: self.session.account)
            if version == "v1", capabilities.e2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
                NCContentPresenter().showInfo(description: "Conversion metadata v1 to v2 required, please wait...")
                nkLog(tag: self.global.logTagE2EE, message: "Conversion v1 to v2")
                NCActivityIndicator.shared.start()

                let error = await NCNetworkingE2EE().uploadMetadata(serverUrl: serverUrl, updateVersionV1V2: true, account: account)
                if error != .success {
                    NCContentPresenter().showError(error: error)
                }
                NCActivityIndicator.shared.stop()
            }
        } else {
            // Client Diagnostic
            await self.database.addDiagnosticAsync(account: account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)
            NCContentPresenter().showError(error: error)
        }

        return (metadatas, error, true)
    }

    func blinkCell(fileName: String?) {
        if let fileName = fileName, let metadata = database.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", session.account, self.serverUrl, fileName)) {
            let indexPath = self.dataSource.getIndexPathMetadata(ocId: metadata.ocId)
            if let indexPath = indexPath {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UIView.animate(withDuration: 0.3) {
                        self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
                    } completion: { _ in
                        if let cell = self.collectionView.cellForItem(at: indexPath) {
                            cell.backgroundColor = .darkGray
                            UIView.animate(withDuration: 2) {
                                cell.backgroundColor = .clear
                            }
                        }
                    }
                }
            }
        }
    }

    func openFile(fileName: String?) {
        if let fileName = fileName, let metadata = database.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", session.account, self.serverUrl, fileName)) {
            let indexPath = self.dataSource.getIndexPathMetadata(ocId: metadata.ocId)
            if let indexPath = indexPath {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.collectionView(self.collectionView, didSelectItemAt: indexPath)
                }
            }
        }
    }

    override func resetPlusButtonAlpha(animated: Bool = true) {
        guard let menuToolbar = self.mainNavigationController?.menuToolbar else {
            return
        }
        let update = {
            menuToolbar.alpha = 1.0
        }
        accumulatedScrollDown = 0

        if animated {
            UIView.animate(withDuration: 0.3, animations: update)
        } else {
            update()
        }
    }

    // MARK: - NCAccountSettingsModelDelegate

    override func accountSettingsDidDismiss(tblAccount: tableAccount?, controller: NCMainTabBarController?) {
        let currentAccount = session.account

        if database.getAllTableAccount().isEmpty {
            let navigationController: UINavigationController?

            if NCBrandOptions.shared.disable_intro, let viewController = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLogin") as? NCLogin {
                navigationController = UINavigationController(rootViewController: viewController)
            } else {
                navigationController = UIStoryboard(name: "NCIntro", bundle: nil).instantiateInitialViewController() as? UINavigationController
            }

            UIApplication.shared.firstWindow?.rootViewController = navigationController
        } else if let account = tblAccount?.account, account != currentAccount {
            Task {
                await NCAccount().changeAccount(account, userProfile: nil, controller: controller)
            }
        } else if self.serverUrl == self.utilityFileSystem.getHomeServer(session: self.session) {
            self.titleCurrentFolder = getNavigationTitle()
            navigationItem.title = self.titleCurrentFolder
        }

        Task {
            await (self.navigationController as? NCMainNavigationController)?.setNavigationLeftItems()
        }
    }
}
