// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift
import SwiftUI

class NCFiles: NCCollectionViewCommon {
    internal var lastOffsetY: CGFloat = 0
    internal var lastScrollTime: TimeInterval = 0
    internal var accumulatedScrollDown: CGFloat = 0

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
                    self.mainNavigationController?.menuPlusButton.backgroundColor = NCBrandColor.shared.getElement(account: account)
                    self.mainNavigationController?.menuPlusButton.tintColor = .white
                }
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            Task {
                await self.stopSyncMetadata()
                await self.searchOperationHandle.cancel()
            }
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
                        self.mainNavigationController?.menuPlusButton.backgroundColor = NCBrandColor.shared.getElement(account: account)
                        self.mainNavigationController?.menuPlusButton.tintColor = .white
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

        Task {
            await self.reloadDataSource()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task {
            // Plus Menu reload
            await self.mainNavigationController?.menuPlus?.create(session: session)

            // Server data
            if !isSearchingMode {
                await getServerData()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        Task {
            await stopSyncMetadata()
            await NCNetworking.shared.networkingTasks.cancel(identifier: "\(self.serverUrl)_NCFiles")
        }
    }

    // MARK: - DataSource

    override func reloadDataSource() async {
        guard !isSearchingMode else {
            await super.reloadDataSource()
            return
        }

        self.metadataFolder = await self.database.getMetadataFolderAsync(session: self.session, serverUrl: self.serverUrl)
        if let tblDirectory = await self.database.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.session.account, self.serverUrl)) {
            self.richWorkspaceText = tblDirectory.richWorkspace
        }
        if let metadataFolder {
            nkLog(info: "Inside metadata folder \(metadataFolder.fileName) with permissions: \(metadataFolder.permissions)")

            // disable + button if no create permission
            let color = NCBrandColor.shared.getElement(account: self.session.account)

            if let menuPlusButton = self.mainNavigationController?.menuPlusButton {
                menuPlusButton.isEnabled = metadataFolder.isCreatable
                menuPlusButton.backgroundColor = metadataFolder.isCreatable ? color : .lightGray
                menuPlusButton.tintColor = .white
            }
        }

        let metadatas = await self.database.getMetadatasAsyncDataSource(withServerUrl: self.serverUrl,
                                                                        withUserId: self.session.userId,
                                                                        withAccount: self.session.account,
                                                                        withLayout: self.layoutForView)

        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas,
                                                     layoutForView: layoutForView,
                                                     account: session.account)
        await super.reloadDataSource()

        cachingAsync(metadatas: metadatas)
    }

    override func getServerData(forced: Bool = false) async {
        defer {
            stopGUIGetServerData()
            startSyncMetadata(metadatas: self.dataSource.getMetadatas())
        }

        await networking.networkingTasks.cancel(identifier: "\(self.serverUrl)_NCFiles")

        guard !isSearchingMode else {
            await self.search()
            return
        }

        // Check whether the folder contains placeholder metadata.
        // When placeholders exist, force a remote folder read to refresh their data.
        let hasPlaceholder = await database.getMetadataFolderPlaceholderAsync(account: self.session.account, serverUrl: self.serverUrl)

        let effectiveForced = forced || hasPlaceholder
        let resultsReadFolder = await networkReadFolderAsync(serverUrl: self.serverUrl, forced: effectiveForced)
        guard resultsReadFolder.error == .success, resultsReadFolder.reloadRequired else {
            return
        }

        let metadatasForDownload: [tableMetadata] = resultsReadFolder.metadatas ?? self.dataSource.getMetadatas()
        Task.detached(priority: .utility) {
            for metadata in metadatasForDownload where !metadata.directory {
                if await self.downloadMetadata(metadata) {
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

    private func downloadMetadata(_ metadata: tableMetadata) async -> Bool {
        let fileSize = utilityFileSystem.fileProviderStorageSize(metadata.ocId,
                                                                 fileName: metadata.fileNameView,
                                                                 userId: metadata.userId,
                                                                 urlBase: metadata.urlBase)
        guard fileSize > 0 else {
            return false
        }

        if let tblLocalFile = await database.getTableLocalFileAsync(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            if tblLocalFile.etag != metadata.etag {
                return true
            }
        }
        return false
    }

    private func networkReadFolderAsync(serverUrl: String, forced: Bool) async -> (metadatas: [tableMetadata]?, error: NKError, reloadRequired: Bool) {
        var reloadRequired: Bool = false
        let account = session.account
        let resultsReadFile = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrl, account: account) { task in
            Task {
                await NCNetworking.shared.networkingTasks.track(identifier: "\(self.serverUrl)_NCFiles", task: task)
            }
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        }
        guard resultsReadFile.error == .success,
              let metadata = resultsReadFile.metadata else {
            return(nil, resultsReadFile.error, reloadRequired)
        }
        let e2eEncrypted = metadata.e2eEncrypted
        let ocId = metadata.ocId

        await self.database.updateDirectoryRichWorkspaceAsync(metadata.richWorkspace, account: account, serverUrl: serverUrl)
        let tableDirectory = await self.database.getTableDirectoryAsync(ocId: metadata.ocId)

        // Verify LivePhoto
        //
        reloadRequired = await networking.setLivePhoto(account: account)
        await NCManageDatabase.shared.deleteLivePhotoError()

        let shouldSkipUpdate: Bool = (
            !forced &&
            tableDirectory?.etag == metadata.etag &&
            !metadata.e2eEncrypted &&
            !self.dataSource.isEmpty()
        )

        if shouldSkipUpdate {
            return (nil, NKError(), reloadRequired)
        }

        startGUIGetServerData()

        let options = NKRequestOptions(timeout: 180)
        let resultsReadFolder = await NCNetworking.shared.readFolderAsync(
            serverUrl: serverUrl,
            account: account,
            options: options
        ) { task in
            Task {
                await NCNetworking.shared.networkingTasks.track(identifier: "\(self.serverUrl)_NCFiles", task: task)
            }
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        }

        guard resultsReadFolder.error == .success else {
            return(nil, resultsReadFolder.error, reloadRequired)
        }
        reloadRequired = true

        if let metadataFolder {
            self.metadataFolder = metadataFolder.detachedCopy()
            self.richWorkspaceText = metadataFolder.richWorkspace
        }

        guard e2eEncrypted,
              let metadatas = resultsReadFolder.metadatas,
              NCPreferences().isEndToEndEnabled(account: account),
              await !NCNetworkingE2EE().isInUpload(account: account, serverUrl: serverUrl) else {
            return(resultsReadFolder.metadatas, resultsReadFolder.error, reloadRequired)
        }

        //
        // E2EE section
        //
        let error = await sectionE2ee(ocId: ocId)
        if error != .success {
            navigationController?.popViewController(animated: false)

            // Client Diagnostic
            await self.database.addDiagnosticAsync(account: account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)
            await showErrorBanner(windowScene: windowScene, text: error.errorDescription, errorCode: error.errorCode)
        }

        return (metadatas, error, reloadRequired)
    }

    private func sectionE2ee(ocId: String) async -> NKError {
        var returnError = NKError()

        // Get Metadata
        let lock = await self.database.getE2ETokenLockAsync(account: session.account, serverUrl: serverUrl)
        var result = await NCNetworkingE2EE().getMetadata(fileId: ocId, e2eToken: lock?.e2eToken, account: session.account)

        if result.error != .success {
            // Metadata not found ? Try to resend it
            if result.error.errorCode == NCGlobal.shared.errorResourceNotFound {
                nkLog(tag: self.global.logTagE2EE, message: "E2ee metadata not found, resend.")
                await NCNetworkingE2EE().uploadMetadata(serverUrl: serverUrl, account: session.account)
                result = await NCNetworkingE2EE().getMetadata(fileId: ocId, e2eToken: lock?.e2eToken, account: session.account)
            } else {
                return result.error
            }
        }

        guard result.error == .success,
              let e2eMetadata = result.e2eMetadata,
              let version = result.version else {
            nkLog(tag: self.global.logTagE2EE, message: returnError.errorDescription)
            return result.error
        }

        // Decode metadata
        returnError = await NCEndToEndMetadata().decodeMetadata(e2eMetadata,
                                                                signature: result.signature,
                                                                serverUrl: serverUrl,
                                                                session: self.session)

        // Old protocolo V1 ? -> Conversion
        if returnError == .success {
            let capabilities = await NKCapabilities.shared.getCapabilities(for: self.session.account)
            if version == "v1", capabilities.e2EEApiVersion.hasPrefix("2.") {
                nkLog(tag: self.global.logTagE2EE, message: "E2ee Conversion v1 to v2.")
                returnError = await NCNetworkingE2EE().uploadMetadata(serverUrl: serverUrl, updateVersionV1V2: true, account: session.account)
            }
        // Checksums error ? (Desktop bug)
        } else if returnError.errorCode == global.errorE2EEKeyChecksums || returnError.errorCode == global.errorE2EEKeyChecksumsEmpty {
            let shouldContinue = await UIAlertController.showAlert(
                from: self,
                title: "_e2ee_checksum_error_title_",
                message: "_e2ee_checksum_error_message_",
                cancelAction: "_cancel_",
                cancelStyle: .cancel,
                continueAction: "_continue_",
                continueStyle: .destructive
            )
            if shouldContinue {
                nkLog(tag: self.global.logTagE2EE, message: "E2ee checksum unavailable - cpollo2onversion metadata requested from user.")
                returnError = await NCNetworkingE2EE().uploadMetadata(serverUrl: serverUrl, account: session.account)
            }
        }

        return returnError
    }

    func open(metadata: tableMetadata?) async {
        guard let metadata else {
            return
        }
        await didSelectMetadata(metadata, withOcIds: false, viewerTransitionSource: nil)
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

            UIApplication.shared.mainAppWindow?.rootViewController = navigationController
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
