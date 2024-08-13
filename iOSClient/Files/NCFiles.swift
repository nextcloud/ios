//
//  NCFiles.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/09/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

class NCFiles: NCCollectionViewCommon {
    internal var isRoot: Bool = true
    internal var fileNameBlink: String?
    internal var fileNameOpen: String?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NCBrandOptions.shared.brand
        layoutKey = NCGlobal.shared.layoutViewFiles
        enableSearchBar = true
        headerRichWorkspaceDisable = false
        headerMenuTransferView = true
        emptyImage = NCImageCache.images.folder
        emptyTitle = "_files_no_files_"
        emptyDescription = "_no_file_pull_down_"
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if isRoot {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil, queue: nil) { _ in

                self.navigationController?.popToRootViewController(animated: false)

                self.serverUrl = self.utilityFileSystem.getHomeServer(urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId)
                self.isSearchingMode = false
                self.isEditMode = false
                self.selectOcId.removeAll()

                self.layoutForView = NCManageDatabase.shared.getLayoutForView(account: self.appDelegate.account, key: self.layoutKey, serverUrl: self.serverUrl)
                if self.layoutForView?.layout == NCGlobal.shared.layoutList {
                    self.collectionView?.collectionViewLayout = self.listLayout
                } else if self.layoutForView?.layout == NCGlobal.shared.layoutGrid {
                    self.collectionView?.collectionViewLayout = self.gridLayout
                } else if self.layoutForView?.layout == NCGlobal.shared.layoutPhotoSquare || self.layoutForView?.layout == NCGlobal.shared.layoutPhotoRatio {
                    self.collectionView?.collectionViewLayout = self.mediaLayout
                }

                self.titleCurrentFolder = self.getNavigationTitle()
                self.setNavigationLeftItems()

                self.reloadDataSource()
                self.reloadDataSourceNetwork()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        if isRoot {
            serverUrl = utilityFileSystem.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
            titleCurrentFolder = getNavigationTitle()
        }
        super.viewWillAppear(animated)

        if dataSource.metadatas.isEmpty {
            reloadDataSource(withQueryDB: true)
        }
        reloadDataSourceNetwork(withQueryDB: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        fileNameBlink = nil
        fileNameOpen = nil
    }

    // MARK: - DataSource + NC Endpoint

    override func queryDB() {
        super.queryDB()

        var metadatas: [tableMetadata] = []
        if NCKeychain().getPersonalFilesOnly(account: self.appDelegate.account) {
            metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (ownerId == %@ || ownerId == '') AND mountType == ''", self.appDelegate.account, self.serverUrl, self.appDelegate.userId))
        } else {
            metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
        }
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
        if self.metadataFolder == nil {
            self.metadataFolder = NCManageDatabase.shared.getMetadataFolder(account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId, serverUrl: self.serverUrl)
        }

        self.richWorkspaceText = directory?.richWorkspace
        self.dataSource = NCDataSource(metadatas: metadatas, account: self.appDelegate.account, layoutForView: layoutForView, providers: self.providers, searchResults: self.searchResults)
    }

    override func reloadDataSource(withQueryDB: Bool = true) {
        super.reloadDataSource(withQueryDB: withQueryDB)

        if !self.dataSource.metadatas.isEmpty {
            self.blinkCell(fileName: self.fileNameBlink)
            self.openFile(fileName: self.fileNameOpen)
            self.fileNameBlink = nil
            self.fileNameOpen = nil
        }
    }

    override func reloadDataSourceNetwork(withQueryDB: Bool = false) {
        if UIApplication.shared.applicationState == .background {
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Files not reload datasource network with the application in background")
            return
        }
        guard !isSearchingMode else {
            return networkSearch()
        }

        func downloadMetadata(_ metadata: tableMetadata) -> Bool {

            let fileSize = utilityFileSystem.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView)
            guard fileSize > 0 else { return false }

            if let localFile = NCManageDatabase.shared.getResultsTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))?.first {
                if localFile.etag != metadata.etag {
                    return true
                }
            }

            return false
        }

        super.reloadDataSourceNetwork()

        networkReadFolder { tableDirectory, metadatas, metadatasDifferentCount, metadatasModified, error in
            DispatchQueue.global(qos: .userInteractive).async {
                if error == .success {
                    for metadata in metadatas ?? [] where !metadata.directory && downloadMetadata(metadata) {
                        if NCNetworking.shared.downloadQueue.operations.filter({ ($0 as? NCOperationDownload)?.metadata.ocId == metadata.ocId }).isEmpty {
                            NCNetworking.shared.downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: NCGlobal.shared.selectorDownloadFile))
                        }
                    }
                    self.richWorkspaceText = tableDirectory?.richWorkspace
                    if metadatasDifferentCount != 0 || metadatasModified != 0 {
                        self.reloadDataSource()
                    } else {
                        self.reloadDataSource(withQueryDB: withQueryDB)
                    }
                } else {
                    self.reloadDataSource(withQueryDB: withQueryDB)
                }
            }
        }
    }

    private func networkReadFolder(completion: @escaping(_ tableDirectory: tableDirectory?, _ metadatas: [tableMetadata]?, _ metadatasDifferentCount: Int, _ metadatasModified: Int, _ error: NKError) -> Void) {
        var tableDirectory: tableDirectory?

        NCNetworking.shared.readFile(serverUrlFileName: serverUrl, account: appDelegate.account) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
        } completion: { account, metadata, error in
            guard error == .success, let metadata else {
                return completion(nil, nil, 0, 0, error)
            }
            tableDirectory = NCManageDatabase.shared.setDirectory(serverUrl: self.serverUrl, richWorkspace: metadata.richWorkspace, account: account)
            // swiftlint:disable empty_string
            let forceReplaceMetadatas = tableDirectory?.etag == ""
            // swiftlint:enable empty_string

            if tableDirectory?.etag != metadata.etag || metadata.e2eEncrypted {
                NCNetworking.shared.readFolder(serverUrl: self.serverUrl,
                                               account: self.appDelegate.account,
                                               forceReplaceMetadatas: forceReplaceMetadatas) { task in
                    self.dataSourceTask = task
                    self.collectionView.reloadData()
                } completion: { account, metadataFolder, metadatas, metadatasDifferentCount, metadatasModified, error in
                    guard account == self.appDelegate.account, error == .success else {
                        return completion(tableDirectory, nil, 0, 0, error)
                    }
                    self.metadataFolder = metadataFolder
                    // E2EE
                    if let metadataFolder = metadataFolder,
                       metadataFolder.e2eEncrypted,
                       NCKeychain().isEndToEndEnabled(account: account),
                       !NCNetworkingE2EE().isInUpload(account: account, serverUrl: self.serverUrl) {
                        let lock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: self.serverUrl)
                        NCNetworkingE2EE().getMetadata(fileId: metadataFolder.ocId, e2eToken: lock?.e2eToken, account: account) { account, version, e2eMetadata, signature, _, error in
                            if account == self.appDelegate.account, error == .success, let e2eMetadata = e2eMetadata {
                                let error = NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: signature, serverUrl: self.serverUrl, account: account, urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId)
                                if error == .success {
                                    if version == "v1", NCGlobal.shared.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
                                        NextcloudKit.shared.nkCommonInstance.writeLog("[E2EE] Conversion v1 to v2")
                                        NCActivityIndicator.shared.start()
                                        Task {
                                            let serverUrl = metadataFolder.serverUrl + "/" + metadataFolder.fileName
                                            let error = await NCNetworkingE2EE().uploadMetadata(account: metadataFolder.account, serverUrl: serverUrl, userId: metadataFolder.userId, updateVersionV1V2: true)
                                            if error != .success {
                                                NCContentPresenter().showError(error: error)
                                            }
                                            NCActivityIndicator.shared.stop()
                                            self.reloadDataSource()
                                        }
                                    } else {
                                        self.reloadDataSource()
                                    }
                                } else {
                                    // Client Diagnostic
                                    NCManageDatabase.shared.addDiagnostic(account: account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)
                                    NCContentPresenter().showError(error: error)
                                }
                            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                                // no metadata found, send a new metadata
                                Task {
                                    let serverUrl = metadataFolder.serverUrl + "/" + metadataFolder.fileName
                                    let error = await NCNetworkingE2EE().uploadMetadata(account: metadataFolder.account, serverUrl: serverUrl, userId: metadataFolder.userId)
                                    if error != .success {
                                        NCContentPresenter().showError(error: error)
                                    }
                                }
                            } else {
                                NCContentPresenter().showError(error: NKError(errorCode: NCGlobal.shared.errorE2EEKeyDecodeMetadata, errorDescription: "_e2e_error_"))
                            }
                            completion(tableDirectory, metadatas, metadatasDifferentCount, metadatasModified, error)
                        }
                    } else {
                        completion(tableDirectory, metadatas, metadatasDifferentCount, metadatasModified, error)
                    }
                }
            } else {
                completion(tableDirectory, nil, 0, 0, NKError())
            }
        }
    }

    func blinkCell(fileName: String?) {
        if let fileName = fileName, let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", self.appDelegate.account, self.serverUrl, fileName)) {
            let (indexPath, _) = self.dataSource.getIndexPathMetadata(ocId: metadata.ocId)
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
        if let fileName = fileName, let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", self.appDelegate.account, self.serverUrl, fileName)) {
            let (indexPath, _) = self.dataSource.getIndexPathMetadata(ocId: metadata.ocId)
            if let indexPath = indexPath {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.collectionView(self.collectionView, didSelectItemAt: indexPath)
                }
            }
        }
    }

    // MARK: - NCAccountSettingsModelDelegate

    override func accountSettingsDidDismiss(tableAccount: tableAccount?) {
        if NCManageDatabase.shared.getAllAccount().isEmpty {
            appDelegate.openLogin(selector: NCGlobal.shared.introLogin, openLoginWeb: false)
        } else if let account = tableAccount?.account, account != appDelegate.account {
            appDelegate.changeAccount(account, userProfile: nil) { }
        } else if isRoot {
            titleCurrentFolder = getNavigationTitle()
            navigationItem.title = titleCurrentFolder
        }
    }
}
