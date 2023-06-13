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

    var domain: NSFileProviderDomain?
    var fileProviderManager: NSFileProviderManager = NSFileProviderManager.default

    var account = ""
    var user = ""
    var userId = ""
    var accountUrlBase = ""
    var homeServerUrl = ""

    // Max item for page
    let itemForPage = 100

    // Anchor
    var currentAnchor: UInt64 = 0

    // Rank favorite
    var listFavoriteIdentifierRank: [String: NSNumber] = [:]

    // Item for signalEnumerator
    var fileProviderSignalDeleteContainerItemIdentifier: [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier] = [:]
    var fileProviderSignalUpdateContainerItem: [NSFileProviderItemIdentifier: FileProviderItem] = [:]
    var fileProviderSignalDeleteWorkingSetItemIdentifier: [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier] = [:]
    var fileProviderSignalUpdateWorkingSetItem: [NSFileProviderItemIdentifier: FileProviderItem] = [:]

    // Error
    enum FileProviderError: Error {
        case downloadError
        case uploadError
    }

    // MARK: - 

    func setupAccount(domain: NSFileProviderDomain?, providerExtension: NSFileProviderExtension) -> tableAccount? {

        self.domain = domain
        if domain != nil {
            if let fileProviderManager = NSFileProviderManager(for: domain!) {
                self.fileProviderManager = fileProviderManager
            }
        }

        // LOG
        if let pathDirectoryGroup = CCUtility.getDirectoryGroup()?.path {
            NextcloudKit.shared.nkCommonInstance.pathLog = pathDirectoryGroup
            let levelLog = CCUtility.getLogLevel()
            NextcloudKit.shared.nkCommonInstance.levelLog = levelLog
            let version = NSString(format: NCBrandOptions.shared.textCopyrightNextcloudiOS as NSString, NCUtility.shared.getVersionApp()) as String
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start File Provider session with level \(levelLog) " + version + " (File Provider Extension)")
        }

        // NO DOMAIN -> Set default account
        if domain == nil {

            guard let activeAccount = NCManageDatabase.shared.getActiveAccount() else { return nil }

            account = activeAccount.account
            user = activeAccount.user
            userId = activeAccount.userId
            accountUrlBase = activeAccount.urlBase
            homeServerUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, userId: activeAccount.userId)

            NCManageDatabase.shared.setCapabilities(account: account)

            NextcloudKit.shared.setup(account: activeAccount.account, user: activeAccount.user, userId: activeAccount.userId, password: CCUtility.getPassword(activeAccount.account), urlBase: activeAccount.urlBase, userAgent: CCUtility.getUserAgent(), nextcloudVersion: NCGlobal.shared.capabilityServerVersionMajor, delegate: NCNetworking.shared)
            NCNetworking.shared.delegate = providerExtension as? NCNetworkingDelegate

            return tableAccount.init(value: activeAccount)
        }

        // DOMAIN
        let accounts = NCManageDatabase.shared.getAllAccount()
        if accounts.count == 0 { return nil }

        for activeAccount in accounts {
            guard let url = NSURL(string: activeAccount.urlBase) else { continue }
            guard let host = url.host else { continue }
            let accountDomain = activeAccount.userId + " (" + host + ")"
            if accountDomain == domain!.identifier.rawValue {

                account = activeAccount.account
                user = activeAccount.user
                userId = activeAccount.userId
                accountUrlBase = activeAccount.urlBase
                homeServerUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, userId: activeAccount.userId)

                NCManageDatabase.shared.setCapabilities(account: account)

                NextcloudKit.shared.setup(account: activeAccount.account, user: activeAccount.user, userId: activeAccount.userId, password: CCUtility.getPassword(activeAccount.account), urlBase: activeAccount.urlBase, userAgent: CCUtility.getUserAgent(), nextcloudVersion: NCGlobal.shared.capabilityServerVersionMajor, delegate: NCNetworking.shared)
                NCNetworking.shared.delegate = providerExtension as? NCNetworkingDelegate

                return tableAccount.init(value: activeAccount)
            }
        }

        return nil
    }

    // MARK: -

    @discardableResult
    func signalEnumerator(ocId: String, delete: Bool = false, update: Bool = false) -> FileProviderItem? {

        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return nil }

        guard let parentItemIdentifier = fileProviderUtility.shared.getParentItemIdentifier(metadata: metadata) else { return nil }

        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)

        if delete {
            fileProviderData.shared.fileProviderSignalDeleteContainerItemIdentifier[item.itemIdentifier] = item.itemIdentifier
            fileProviderData.shared.fileProviderSignalDeleteWorkingSetItemIdentifier[item.itemIdentifier] = item.itemIdentifier
        }

        if update {
            fileProviderData.shared.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
            fileProviderData.shared.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }

        if !update && !delete {
            fileProviderData.shared.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }

        if update || delete {
            currentAnchor += 1
            fileProviderManager.signalEnumerator(for: parentItemIdentifier) { _ in }
        }

        fileProviderManager.signalEnumerator(for: .workingSet) { _ in }

        return item
    }

    /*
     func updateFavoriteForWorkingSet() {
         
         var updateWorkingSet = false
         let oldListFavoriteIdentifierRank = listFavoriteIdentifierRank
         listFavoriteIdentifierRank = NCManageDatabase.shared.getTableMetadatasDirectoryFavoriteIdentifierRank(account: account)
         
         // (ADD)
         for (identifier, _) in listFavoriteIdentifierRank {
             
             guard let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "ocId == %@", identifier)) else { continue }
             guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: homeServerUrl) else { continue }
             let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                 
             fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
             updateWorkingSet = true
         }
         
         // (REMOVE)
         for (identifier, _) in oldListFavoriteIdentifierRank {
             
             if !listFavoriteIdentifierRank.keys.contains(identifier) {
                 
                 guard let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "ocId == %@", identifier)) else { continue }
                 let itemIdentifier = fileProviderUtility.sharedInstance.getItemIdentifier(metadata: metadata)
                 
                 fileProviderSignalDeleteWorkingSetItemIdentifier[itemIdentifier] = itemIdentifier
                 updateWorkingSet = true
             }
         }
         
         if updateWorkingSet {
             signalEnumerator(for: [.workingSet])
         }
     }
     */
}
