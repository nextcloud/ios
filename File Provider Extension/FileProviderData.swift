//
//  FileProviderData.swift
//  Files
//
//  Created by Marino Faggiana on 27/05/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

class fileProviderData: NSObject {
    static let shared: fileProviderData = {
        let instance = fileProviderData()
        return instance
    }()

    var providerDomain: NSFileProviderDomain?
    var fileProviderManager: NSFileProviderManager = NSFileProviderManager.default
    let utilityFileSystem = NCUtilityFileSystem()
    var listFavoriteIdentifierRank: [String: NSNumber] = [:]
    var fileProviderSignalDeleteContainerItemIdentifier: [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier] = [:]
    var fileProviderSignalUpdateContainerItem: [NSFileProviderItemIdentifier: FileProviderItem] = [:]
    var fileProviderSignalDeleteWorkingSetItemIdentifier: [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier] = [:]
    var fileProviderSignalUpdateWorkingSetItem: [NSFileProviderItemIdentifier: FileProviderItem] = [:]
    var account: String = ""

    enum FileProviderError: Error {
        case downloadError
        case uploadError
    }

    enum TypeSignal: String {
        case delete
        case update
        case workingSet
    }

    struct UploadMetadata {
        var id: String
        var metadata: tableMetadata
        var task: URLSessionUploadTask?
    }

    var uploadMetadata: [UploadMetadata] = []

    // MARK: - 

    func setupAccount(providerDomain: NSFileProviderDomain?, providerExtension: NSFileProviderExtension) -> tableAccount? {
        self.providerDomain = providerDomain
        if let providerDomain, let fileProviderManager = NSFileProviderManager(for: providerDomain) {
            self.fileProviderManager = fileProviderManager
        }

        // LOG
        NextcloudKit.shared.nkCommonInstance.pathLog = utilityFileSystem.directoryGroup
        let levelLog = NCKeychain().logLevel
        NextcloudKit.shared.nkCommonInstance.levelLog = levelLog
        let version = NSString(format: NCBrandOptions.shared.textCopyrightNextcloudiOS as NSString, NCUtility().getVersionApp()) as String
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start File Provider session with level \(levelLog) " + version + " (File Provider Extension)")

        // NO DOMAIN -> Set default account
        if providerDomain == nil {
            guard let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount() else { return nil }
            self.account = activeTableAccount.account

            NCDomain.shared.appendDomain(account: activeTableAccount.account,
                                         urlBase: activeTableAccount.urlBase,
                                         user: activeTableAccount.user,
                                         userId: activeTableAccount.userId,
                                         sceneIdentifier: "")

            NextcloudKit.shared.setup(delegate: NCNetworking.shared)
            NextcloudKit.shared.appendAccount(activeTableAccount.account,
                                              urlBase: activeTableAccount.urlBase,
                                              user: activeTableAccount.user,
                                              userId: activeTableAccount.userId,
                                              password: NCKeychain().getPassword(account: activeTableAccount.account),
                                              userAgent: userAgent,
                                              nextcloudVersion: NCGlobal.shared.capabilityServerVersionMajor,
                                              groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
            NCNetworking.shared.delegate = providerExtension as? NCNetworkingDelegate

            return tableAccount.init(value: activeTableAccount)
        }

        // DOMAIN
        let accounts = NCManageDatabase.shared.getAllAccount()
        if accounts.isEmpty { return nil }

        /*
        for activeAccount in accounts {
            guard let url = NSURL(string: activeAccount.urlBase) else { continue }
            guard let host = url.host else { continue }
            let accountDomain = activeAccount.userId + " (" + host + ")"
            if accountDomain == domain!.identifier.rawValue {
                account = activeAccount.account
                user = activeAccount.user
                userId = activeAccount.userId
                accountUrlBase = activeAccount.urlBase
                homeServerUrl = utilityFileSystem.getHomeServer(urlBase: activeAccount.urlBase, userId: activeAccount.userId)

                NCManageDatabase.shared.setCapabilities(account: account)
                NextcloudKit.shared.appendAccount(activeAccount.account,
                                                  urlBase: activeAccount.urlBase,
                                                  user: activeAccount.user,
                                                  userId: activeAccount.userId,
                                                  password: NCKeychain().getPassword(account: activeAccount.account),
                                                  userAgent: userAgent,
                                                  nextcloudVersion: NCGlobal.shared.capabilityServerVersionMajor,
                                                  groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
                NCNetworking.shared.delegate = providerExtension as? NCNetworkingDelegate

                return tableAccount.init(value: activeAccount)
            }
        }
        */
        return nil
    }

    // MARK: -

    @discardableResult
    func signalEnumerator(ocId: String, type: TypeSignal) -> FileProviderItem? {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
              let parentItemIdentifier = fileProviderUtility().getParentItemIdentifier(metadata: metadata) else { return nil }
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)

        if type == .delete {
            fileProviderData.shared.fileProviderSignalDeleteContainerItemIdentifier[item.itemIdentifier] = item.itemIdentifier
            fileProviderData.shared.fileProviderSignalDeleteWorkingSetItemIdentifier[item.itemIdentifier] = item.itemIdentifier
        }
        if type == .update {
            fileProviderData.shared.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
            fileProviderData.shared.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }
        if type == .workingSet {
            fileProviderData.shared.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }
        if type == .delete || type == .update {
            fileProviderManager.signalEnumerator(for: parentItemIdentifier) { _ in }
        }
        fileProviderManager.signalEnumerator(for: .workingSet) { _ in }
        return item
    }

    // MARK: -

    func appendUploadMetadata(id: String, metadata: tableMetadata, task: URLSessionUploadTask?) {
        if let index = uploadMetadata.firstIndex(where: { $0.id == id }) {
            uploadMetadata.remove(at: index)
        }
        uploadMetadata.append(UploadMetadata(id: id, metadata: metadata, task: task))
    }

    func getUploadMetadata(id: String) -> UploadMetadata? {
        return uploadMetadata.filter({ $0.id == id }).first
    }
}
