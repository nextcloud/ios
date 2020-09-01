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

import NCCommunication

class fileProviderData: NSObject {
    @objc static let sharedInstance: fileProviderData = {
        let instance = fileProviderData()
        return instance
    }()
        
    var account = ""
    var accountUser = ""
    var accountUserID = ""
    var accountPassword = ""
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
   
    // UserDefaults
    var ncUserDefaults = UserDefaults(suiteName: NCBrandOptions.sharedInstance.capabilitiesGroups)
    
    // Error
    enum FileProviderError: Error {
        case downloadError
        case uploadError
    }
    
    // MARK: - 
    
    func setupAccount(domain: String?, providerExtension: NSFileProviderExtension) -> Bool {
        
        var foundAccount: Bool = false
        
        if CCUtility.getDisableFilesApp() || NCBrandOptions.sharedInstance.disable_openin_file {
            return false
        }
                
        // NO DOMAIN -> Set default account
        if domain == nil {
            
            guard let tableAccount = NCManageDatabase.sharedInstance.getAccountActive() else { return false }
            let serverVersionMajor = NCManageDatabase.sharedInstance.getCapabilitiesServerInt(account: tableAccount.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
            let webDav = NCUtility.shared.getWebDAV(account: tableAccount.account)
            
            account = tableAccount.account
            accountUser = tableAccount.user
            accountUserID = tableAccount.userID
            accountPassword = CCUtility.getPassword(tableAccount.account)
            accountUrlBase = tableAccount.urlBase
            homeServerUrl = NCUtility.shared.getHomeServer(urlBase: tableAccount.urlBase, account: tableAccount.account)
                        
            NCCommunicationCommon.shared.setup(account: account, user: accountUser, userId: accountUserID, password: accountPassword, urlBase: accountUrlBase, userAgent: CCUtility.getUserAgent(), webDav: webDav, dav: nil, nextcloudVersion: serverVersionMajor, delegate: NCNetworking.shared)
            NCNetworking.shared.delegate = providerExtension as? NCNetworkingDelegate
            
            return true
        }
        
        let tableAccounts = NCManageDatabase.sharedInstance.getAllAccount()
        if tableAccounts.count == 0 { return false }
        
        for tableAccount in tableAccounts {
            guard let url = NSURL(string: tableAccount.urlBase) else { continue }
            guard let host = url.host else { continue }
            let accountDomain = tableAccount.userID + " (" + host + ")"
            if accountDomain == domain {
                
                let serverVersionMajor = NCManageDatabase.sharedInstance.getCapabilitiesServerInt(account: tableAccount.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
                let webDav = NCUtility.shared.getWebDAV(account: tableAccount.account)
                
                account = tableAccount.account
                accountUser = tableAccount.user
                accountUserID = tableAccount.userID
                guard let password = CCUtility.getPassword(tableAccount.account) else { return false }
                accountPassword = password
                accountUrlBase = tableAccount.urlBase
                homeServerUrl = NCUtility.shared.getHomeServer(urlBase: tableAccount.urlBase, account: tableAccount.account)
                
                NCCommunicationCommon.shared.setup(account: account, user: accountUser, userId: accountUserID, password: accountPassword, urlBase: accountUrlBase, userAgent: CCUtility.getUserAgent(), webDav: webDav, dav: nil, nextcloudVersion: serverVersionMajor, delegate: NCNetworking.shared)
                NCNetworking.shared.delegate = providerExtension as? NCNetworkingDelegate

                foundAccount = true
            }
        }
        
        return foundAccount
    }
    
    func setupAccount(itemIdentifier: NSFileProviderItemIdentifier, providerExtension: NSFileProviderExtension) -> Bool {
        
        var foundAccount: Bool = false

        guard let accountFromItemIdentifier = fileProviderUtility.sharedInstance.getAccountFromItemIdentifier(itemIdentifier) else { return false }
        
        let tableAccounts = NCManageDatabase.sharedInstance.getAllAccount()
        if tableAccounts.count == 0 { return false }
        
        for tableAccount in tableAccounts {
            if accountFromItemIdentifier == tableAccount.account {
                
                let serverVersionMajor = NCManageDatabase.sharedInstance.getCapabilitiesServerInt(account: tableAccount.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
                let webDav = NCUtility.shared.getWebDAV(account: tableAccount.account)
                
                account = tableAccount.account
                accountUser = tableAccount.user
                accountUserID = tableAccount.userID
                accountPassword = CCUtility.getPassword(tableAccount.account)
                accountUrlBase = tableAccount.urlBase
                homeServerUrl = NCUtility.shared.getHomeServer(urlBase: tableAccount.urlBase, account: tableAccount.account)
                
                NCCommunicationCommon.shared.setup(account: account, user: accountUser, userId: accountUserID, password: accountPassword, urlBase: accountUrlBase, userAgent: CCUtility.getUserAgent(), webDav: webDav, dav: nil, nextcloudVersion: serverVersionMajor, delegate: NCNetworking.shared)
                NCNetworking.shared.delegate = providerExtension as? NCNetworkingDelegate
                
                foundAccount = true
            }
        }
        
        return foundAccount
    }
    
    // MARK: -

    // Convinent method to signal the enumeration for containers.
    //
    func signalEnumerator(for containerItemIdentifiers: [NSFileProviderItemIdentifier]) {
                
        currentAnchor += 1
        
        for containerItemIdentifier in containerItemIdentifiers {
            
            NSFileProviderManager.default.signalEnumerator(for: containerItemIdentifier) { error in
                if let error = error {
                    print("SignalEnumerator for \(containerItemIdentifier) returned error: \(error)")
                }
            }
        }
    }
    
    /*
     func updateFavoriteForWorkingSet() {
         
         var updateWorkingSet = false
         let oldListFavoriteIdentifierRank = listFavoriteIdentifierRank
         listFavoriteIdentifierRank = NCManageDatabase.sharedInstance.getTableMetadatasDirectoryFavoriteIdentifierRank(account: account)
         
         // (ADD)
         for (identifier, _) in listFavoriteIdentifierRank {
             
             guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", identifier)) else { continue }
             guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: homeServerUrl) else { continue }
             let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                 
             fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
             updateWorkingSet = true
         }
         
         // (REMOVE)
         for (identifier, _) in oldListFavoriteIdentifierRank {
             
             if !listFavoriteIdentifierRank.keys.contains(identifier) {
                 
                 guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", identifier)) else { continue }
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
