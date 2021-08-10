//
//  NCService.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/03/18.
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
import SVGKit
import NCCommunication

class NCService: NSObject {
    @objc static let shared: NCService = {
        let instance = NCService()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //MARK: -
    
    @objc public func startRequestServicesServer() {
   
        if appDelegate.account == "" { return }
        
        self.requestUserProfile()
        self.requestServerStatus()
    }

    //MARK: -
    
    private func requestUserProfile() {
        
        if appDelegate.account == "" { return }
        
        NCCommunication.shared.getUserProfile() { (account, userProfile, errorCode, errorDescription) in
               
            if errorCode == 0 && account == self.appDelegate.account {
                  
                DispatchQueue.global().async {
                
                    // Update User (+ userProfile.id) & active account & account network
                    guard let tableAccount = NCManageDatabase.shared.setAccountUserProfile(userProfile!) else {
                        NCContentPresenter.shared.messageNotification("Account", description: "Internal error : account not found on DB",  delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
                        return
                    }
                
                    let user = tableAccount.user
                    let url = tableAccount.urlBase
                    let stringUser = CCUtility.getStringUser(user, urlBase: url)!
                    
                    self.appDelegate.settingAccount(tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user, userId: tableAccount.userId, password: CCUtility.getPassword(tableAccount.account))
                       
                    // Synchronize favorite                    
                    NCNetworking.shared.listingFavoritescompletion(selector: NCGlobal.shared.selectorReadFile) { (_, _, _, _) in }
                
                    // Synchronize Offline
                    self.synchronizeOffline(account: tableAccount.account)
                    
                    // Get Avatar
                    let avatarUrl = "\(self.appDelegate.urlBase)/index.php/avatar/\(self.appDelegate.user)/\(NCGlobal.shared.avatarSize)".addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
                    let fileNamePath = String(CCUtility.getDirectoryUserData()) + "/" + stringUser + "-" + self.appDelegate.user + ".png"
                    NCCommunication.shared.downloadContent(serverUrl: avatarUrl) { (account, data, errorCode, errorMessage) in
                        
                        if errorCode == 0 && account == self.appDelegate.account {
                                                            
                            if let image = UIImage(data: data!) {
                                do {
                                    if let data = image.pngData() {
                                        try data.write(to: URL(fileURLWithPath: fileNamePath))
                                    }
                                } catch {
                                    print(error)
                                }
                            }
                        }
                    }
                          
                    self.requestServerCapabilities()
                }
                
            } else {
                
                if errorCode == 401 || errorCode == 403 {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: account)
                }
            }
        }
    }
    
    private func requestServerStatus() {
        
        NCCommunication.shared.getServerStatus(serverUrl: appDelegate.urlBase) { (serverProductName, serverVersion, versionMajor, versionMinor, versionMicro, extendedSupport, errorCode, errorMessage) in
                        
            if errorCode == 0 {
                
                DispatchQueue.global().async {
                    
                    if extendedSupport == false {
                        if serverProductName == "owncloud" {
                            NCContentPresenter.shared.messageNotification("_warning_", description: "_warning_owncloud_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorInternalError)
                        } else if versionMajor <=  NCGlobal.shared.nextcloud_unsupported_version {
                            NCContentPresenter.shared.messageNotification("_warning_", description: "_warning_unsupported_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorInternalError)
                        }
                    }
                }
            }
        }
    }
    
    private func requestServerCapabilities() {
        
        if appDelegate.account == "" { return }
        
        NCCommunication.shared.getCapabilities() { (account, data, errorCode, errorDescription) in
            
            if errorCode == 0 && data != nil {
                
                DispatchQueue.global().async {
                
                    NCManageDatabase.shared.addCapabilitiesJSon(data!, account: account)
                
                    let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
                    
                    // Setup communication
                    if serverVersionMajor > 0 {
                        NCCommunicationCommon.shared.setup(nextcloudVersion: serverVersionMajor)
                    }
                    NCCommunicationCommon.shared.setup(webDav: NCUtilityFileSystem.shared.getWebDAV(account: account))
                    
                    // Theming
                    NCBrandColor.shared.settingThemingColor(account: account)
                
                    // File Sharing
                    let isFilesSharingEnabled = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFileSharingApiEnabled, exists: false)
                    if isFilesSharingEnabled {
                        NCCommunication.shared.readShares { (account, shares, errorCode, ErrorDescription) in
                            if errorCode == 0 {
                                
                                NCManageDatabase.shared.deleteTableShare(account: account)
                                if shares != nil {
                                    NCManageDatabase.shared.addShare(urlBase: self.appDelegate.urlBase, account: account, shares: shares!)
                                }
                                self.appDelegate.shares = NCManageDatabase.shared.getTableShares(account: account)
                               
                            } else {
                                NCContentPresenter.shared.messageNotification("_share_", description: ErrorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            }
                        }
                    }
                    
                    let comments = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFilesComments, exists: false)
                    let activity = NCManageDatabase.shared.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesActivity)
                    
                    if !isFilesSharingEnabled && !comments && activity == nil {
                        self.appDelegate.disableSharesView = true
                    } else {
                        self.appDelegate.disableSharesView = false
                    }
                
                    // Text direct editor detail
                    if serverVersionMajor >= NCGlobal.shared.nextcloudVersion18 {
                        NCCommunication.shared.NCTextObtainEditorDetails() { (account, editors, creators, errorCode, errorMessage) in
                            if errorCode == 0 && account == self.appDelegate.account {
                                
                                DispatchQueue.global().async {
                                
                                    NCManageDatabase.shared.addDirectEditing(account: account, editors: editors, creators: creators)
                                }
                            }
                        }
                    }
                    
                    // External file Server
                    let isExternalSitesServerEnabled = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesExternalSitesExists, exists: true)
                    if (isExternalSitesServerEnabled) {
                        NCCommunication.shared.getExternalSite() { (account, externalSites, errorCode, errorDescription) in
                            if errorCode == 0 && account == self.appDelegate.account {
                                
                                DispatchQueue.global().async {
                                
                                    NCManageDatabase.shared.deleteExternalSites(account: account)
                                    for externalSite in externalSites {
                                        NCManageDatabase.shared.addExternalSites(externalSite, account: account)
                                    }
                                }
                            }
                        }
                        
                    } else {
                        NCManageDatabase.shared.deleteExternalSites(account: account)
                    }
                    
                    // User Status
                    let userStatus = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesUserStatusEnabled, exists: false)
                    if userStatus {
                        NCCommunication.shared.getUserStatus { (account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, userId, errorCode, errorDescription) in
                            if errorCode == 0 && account == self.appDelegate.account && userId == self.appDelegate.userId {
                                
                                DispatchQueue.global().async {
                                
                                    NCManageDatabase.shared.setAccountUserStatus(userStatusClearAt: clearAt, userStatusIcon: icon, userStatusMessage: message, userStatusMessageId: messageId, userStatusMessageIsPredefined: messageIsPredefined, userStatusStatus: status, userStatusStatusIsUserDefined: statusIsUserDefined, account: account)
                                }
                            }
                        }
                    }

                    // markdown
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "net.daringfireball.markdown", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "markdown")
                    
                    // document: text
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.text", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "document")
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.wordprocessingml.document", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice ,iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "document")
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.word.doc", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "document")
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.pages.pages", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "pages")
                    
                    // document: sheet
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.spreadsheet", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NCCommunicationCommon.typeIconFile.xls.rawValue, name: "sheet")
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.spreadsheetml.sheet", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NCCommunicationCommon.typeIconFile.xls.rawValue, name: "sheet")
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.excel.xls", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NCCommunicationCommon.typeIconFile.xls.rawValue, name: "sheet")
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.numbers.numbers", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NCCommunicationCommon.typeIconFile.xls.rawValue, name: "numbers")
                    
                    // document: presentation
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.presentation", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NCCommunicationCommon.typeIconFile.ppt.rawValue, name: "presentation")
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.presentationml.presentation", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NCCommunicationCommon.typeIconFile.ppt.rawValue, name: "presentation")
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.powerpoint.ppt", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NCCommunicationCommon.typeIconFile.ppt.rawValue, name: "presentation")
                    NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.keynote.key", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NCCommunicationCommon.typeIconFile.ppt.rawValue, name: "keynote")
                     
                    // Added UTI for Collabora
                    if let richdocumentsMimetypes = NCManageDatabase.shared.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesRichdocumentsMimetypes) {
                        for mimeType in richdocumentsMimetypes {
                            NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: mimeType, classFile:  NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "document")
                        }
                    }
                    
                    // Added UTI for ONLYOFFICE & Text
                    if let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: account) {
                        for directEditing in directEditingCreators {
                            NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: directEditing.mimetype, classFile:  NCCommunicationCommon.typeClassFile.document.rawValue, editor: directEditing.editor, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "document")
                        }
                    }

                    //                    Handwerkcloud
                    //                    let isHandwerkcloudEnabled = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesHWCEnabled, exists: false)
                    //                    if (isHandwerkcloudEnabled) {
                    //                        self.requestHC()
                    //                    }
                }
                
            } else if errorCode != 0 {
                
                NCBrandColor.shared.settingThemingColor(account: account)
                
                if errorCode == 401 || errorCode == 403 {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: account)
                }
                
            } else {
                NCBrandColor.shared.settingThemingColor(account: account)
            }
        }
    }
    
    @objc func synchronizeOffline(account: String) {
        
        // Synchronize Offline Directory
        if let directories = NCManageDatabase.shared.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", account), sorted: "serverUrl", ascending: true) {
            for directory: tableDirectory in directories {
                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(directory.ocId) else {
                    continue
                }
                NCOperationQueue.shared.synchronizationMetadata(metadata, selector: NCGlobal.shared.selectorDownloadFile)
            }
        }
    
        // Synchronize Offline Files
        let files = NCManageDatabase.shared.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", account), sorted: "fileName", ascending: true)
        for file: tableLocalFile in files {
            guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(file.ocId) else {
                continue
            }
            NCOperationQueue.shared.synchronizationMetadata(metadata, selector: NCGlobal.shared.selectorDownloadFile)
        }
    }
   
    //MARK: - Thirt Part
    
    private func requestHC() {

    }
}
