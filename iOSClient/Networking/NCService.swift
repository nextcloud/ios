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

    // MARK: -

    @objc public func startRequestServicesServer() {

        NCManageDatabase.shared.clearAllAvatarLoaded()

        if appDelegate.account == "" { return }

        self.addInternalTypeIdentifier()
        self.requestUserProfile()
        self.requestServerStatus()
    }

    // MARK: -

    func addInternalTypeIdentifier() {

        // txt
        NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "text/plain", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "markdown")

        // html
        NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "text/html", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "markdown")

        // markdown
        NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "net.daringfireball.markdown", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "markdown")
        NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "text/x-markdown", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "markdown")

        // document: text
        NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.text", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "document")
        NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.wordprocessingml.document", classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "document")
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
    }

    private func requestUserProfile() {

        if appDelegate.account == "" { return }

        NCCommunication.shared.getUserProfile(queue: NCCommunicationCommon.shared.backgroundQueue) { account, userProfile, errorCode, errorDescription in

            if errorCode == 0 && account == self.appDelegate.account {

                // Update User (+ userProfile.id) & active account & account network
                guard let tableAccount = NCManageDatabase.shared.setAccountUserProfile(userProfile!) else {
                    NCContentPresenter.shared.messageNotification("Account", description: "Internal error : account not found on DB", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError, priority: .max)
                    return
                }

                self.appDelegate.settingAccount(tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user, userId: tableAccount.userId, password: CCUtility.getPassword(tableAccount.account))

                // Synchronize favorite
                NCNetworking.shared.listingFavoritescompletion(selector: NCGlobal.shared.selectorReadFile) { _, _, _, _ in }

                // Synchronize Offline
                self.synchronizeOffline(account: tableAccount.account)

                // Get Avatar
                let fileName = tableAccount.userBaseUrl + "-" + self.appDelegate.user + ".png"
                let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName
                let etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag

                NCCommunication.shared.downloadAvatar(user: tableAccount.userId, fileNameLocalPath: fileNameLocalPath, sizeImage: NCGlobal.shared.avatarSize, avatarSizeRounded: NCGlobal.shared.avatarSizeRounded, etag: etag, queue: NCCommunicationCommon.shared.backgroundQueue) { _, _, _, etag, errorCode, _ in

                    if let etag = etag, errorCode == 0 {
                        NCManageDatabase.shared.addAvatar(fileName: fileName, etag: etag)
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadAvatar, userInfo: nil)
                    } else if errorCode == NCGlobal.shared.errorNotModified {

                        NCManageDatabase.shared.setAvatarLoaded(fileName: fileName)
                    }
                }
                self.requestServerCapabilities()

            } else {

                if errorCode == 401 || errorCode == 403 {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: account, errorCode: errorCode, errorDescription: errorDescription)
                }
            }
        }
    }

    private func requestServerStatus() {

        NCCommunication.shared.getServerStatus(serverUrl: appDelegate.urlBase, queue: NCCommunicationCommon.shared.backgroundQueue) { serverProductName, _, versionMajor, _, _, extendedSupport, errorCode, _ in

            if errorCode == 0 && extendedSupport == false {

                if serverProductName == "owncloud" {
                    NCContentPresenter.shared.messageNotification("_warning_", description: "_warning_owncloud_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorInternalError, priority: .max)
                } else if versionMajor <=  NCGlobal.shared.nextcloud_unsupported_version {
                    NCContentPresenter.shared.messageNotification("_warning_", description: "_warning_unsupported_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorInternalError, priority: .max)
                }
            }
        }
    }

    private func requestServerCapabilities() {

        if appDelegate.account == "" { return }

        NCCommunication.shared.getCapabilities(queue: NCCommunicationCommon.shared.backgroundQueue) { account, data, errorCode, errorDescription in

            if errorCode == 0 && data != nil {

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
                    NCCommunication.shared.readShares(parameters: NCCShareParameter(), queue: NCCommunicationCommon.shared.backgroundQueue) { account, shares, errorCode, errorDescription in
                        if errorCode == 0 {
                            NCManageDatabase.shared.deleteTableShare(account: account)
                            if shares != nil {
                                NCManageDatabase.shared.addShare(urlBase: self.appDelegate.urlBase, account: account, shares: shares!)
                            }
                            self.appDelegate.shares = NCManageDatabase.shared.getTableShares(account: account)
                        } else {
                            NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
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
                    NCCommunication.shared.NCTextObtainEditorDetails(queue: NCCommunicationCommon.shared.backgroundQueue) { account, editors, creators, errorCode, _ in
                        if errorCode == 0 && account == self.appDelegate.account {
                            NCManageDatabase.shared.addDirectEditing(account: account, editors: editors, creators: creators)
                        }
                    }
                }

                // External file Server
                let isExternalSitesServerEnabled = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesExternalSitesExists, exists: true)
                if isExternalSitesServerEnabled {
                    NCCommunication.shared.getExternalSite(queue: NCCommunicationCommon.shared.backgroundQueue) { account, externalSites, errorCode, _ in
                        if errorCode == 0 && account == self.appDelegate.account {
                            NCManageDatabase.shared.deleteExternalSites(account: account)
                            for externalSite in externalSites {
                                NCManageDatabase.shared.addExternalSites(externalSite, account: account)
                            }
                        }
                    }

                } else {
                    NCManageDatabase.shared.deleteExternalSites(account: account)
                }

                // User Status
                let userStatus = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesUserStatusEnabled, exists: false)
                if userStatus {
                    NCCommunication.shared.getUserStatus(queue: NCCommunicationCommon.shared.backgroundQueue) { account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, userId, errorCode, _ in
                        if errorCode == 0 && account == self.appDelegate.account && userId == self.appDelegate.userId {
                            NCManageDatabase.shared.setAccountUserStatus(userStatusClearAt: clearAt, userStatusIcon: icon, userStatusMessage: message, userStatusMessageId: messageId, userStatusMessageIsPredefined: messageIsPredefined, userStatusStatus: status, userStatusStatusIsUserDefined: statusIsUserDefined, account: account)
                        }
                    }
                }

                // Added UTI for Collabora
                if let richdocumentsMimetypes = NCManageDatabase.shared.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesRichdocumentsMimetypes) {
                    for mimeType in richdocumentsMimetypes {
                        NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: mimeType, classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "document")
                    }
                }

                // Added UTI for ONLYOFFICE & Text
                if let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: account) {
                    for directEditing in directEditingCreators {
                        NCCommunicationCommon.shared.addInternalTypeIdentifier(typeIdentifier: directEditing.mimetype, classFile: NCCommunicationCommon.typeClassFile.document.rawValue, editor: directEditing.editor, iconName: NCCommunicationCommon.typeIconFile.document.rawValue, name: "document")
                    }
                }

                //                    Handwerkcloud
                //                    let isHandwerkcloudEnabled = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesHWCEnabled, exists: false)
                //                    if (isHandwerkcloudEnabled) {
                //                        self.requestHC()
                //                    }

            } else if errorCode != 0 {

                NCBrandColor.shared.settingThemingColor(account: account)

                if errorCode == 401 || errorCode == 403 {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: account, errorCode: errorCode, errorDescription: errorDescription)
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

    // MARK: - Thirt Part

    private func requestHC() {

    }
}
