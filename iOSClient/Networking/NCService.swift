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
import NextcloudKit
import SwiftyJSON

class NCService: NSObject {
    @objc static let shared: NCService = {
        let instance = NCService()
        return instance
    }()

    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    // MARK: -

    @objc public func startRequestServicesServer() {

        NCManageDatabase.shared.clearAllAvatarLoaded()

        guard !appDelegate.account.isEmpty else { return }

        addInternalTypeIdentifier()
        requestServerStatus()
        requestUserProfile()        
    }

    // MARK: -

    func addInternalTypeIdentifier() {

        // txt
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "text/plain", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.typeIconFile.document.rawValue, name: "markdown")

        // html
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "text/html", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.typeIconFile.document.rawValue, name: "markdown")

        // markdown
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "net.daringfireball.markdown", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.typeIconFile.document.rawValue, name: "markdown")
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "text/x-markdown", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.typeIconFile.document.rawValue, name: "markdown")

        // document: text
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.text", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.typeIconFile.document.rawValue, name: "document")
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.wordprocessingml.document", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NKCommon.typeIconFile.document.rawValue, name: "document")
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.word.doc", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.typeIconFile.document.rawValue, name: "document")
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.pages.pages", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.typeIconFile.document.rawValue, name: "pages")

        // document: sheet
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.spreadsheet", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.typeIconFile.xls.rawValue, name: "sheet")
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.spreadsheetml.sheet", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NKCommon.typeIconFile.xls.rawValue, name: "sheet")
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.excel.xls", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.typeIconFile.xls.rawValue, name: "sheet")
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.numbers.numbers", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.typeIconFile.xls.rawValue, name: "numbers")

        // document: presentation
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.presentation", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.typeIconFile.ppt.rawValue, name: "presentation")
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.presentationml.presentation", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NKCommon.typeIconFile.ppt.rawValue, name: "presentation")
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.powerpoint.ppt", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.typeIconFile.ppt.rawValue, name: "presentation")
        NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.keynote.key", classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.typeIconFile.ppt.rawValue, name: "keynote")
    }

    // MARK: -

    private func requestServerStatus() {

        let options = NKRequestOptions(queue: NKCommon.shared.backgroundQueue)

        NextcloudKit.shared.getServerStatus(serverUrl: appDelegate.urlBase, options: options) { serverProductName, _, versionMajor, _, _, extendedSupport, data, error in
            guard error == .success, extendedSupport == false else {
                return
            }

            if serverProductName == "owncloud" {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_warning_owncloud_")
                NCContentPresenter.shared.showWarning(error: error, priority: .max)
            } else if versionMajor <=  NCGlobal.shared.nextcloud_unsupported_version {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_warning_unsupported_")
                NCContentPresenter.shared.showWarning(error: error, priority: .max)
            }
        }
    }

    // MARK: -

    private func requestUserProfile() {
        guard !appDelegate.account.isEmpty else { return }

        let options = NKRequestOptions(queue: NKCommon.shared.backgroundQueue)

        NextcloudKit.shared.getUserProfile(options: options) { account, userProfile, data, error in
            guard error == .success, let userProfile = userProfile else {
                
                // Ops the server has Unauthorized
                NKCommon.shared.writeLog("[ERROR] The server has response with Unauthorized \(error.errorCode)")

                DispatchQueue.main.async {
                    if  (UIApplication.shared.applicationState == .active) &&
                        (NCNetworking.shared.networkReachability != NKCommon.typeReachability.notReachable) &&
                        (error.errorCode == NCGlobal.shared.errorNCUnauthorized || error.errorCode == NCGlobal.shared.errorUnauthorized || error.errorCode == NCGlobal.shared.errorForbidden) {
                        
                        NCBrandColor.shared.settingThemingColor(account: account)
                        NCNetworkingCheckRemoteUser().checkRemoteUser(account: account, error: error)
                    }
                }
                return
            }

            // Update User (+ userProfile.id) & active account & account network
            guard let tableAccount = NCManageDatabase.shared.setAccountUserProfile(account: account, userProfile: userProfile) else {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "Internal error : account not found on DB")
                NCContentPresenter.shared.showError(error: error, priority: .max)
                return
            }

            self.appDelegate.settingAccount(tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user, userId: tableAccount.userId, password: CCUtility.getPassword(tableAccount.account))

            // Synchronize favorite
            NCNetworking.shared.listingFavoritescompletion(selector: NCGlobal.shared.selectorReadFile) { _, _, _ in }

            // Synchronize Offline
            self.synchronizeOffline(account: tableAccount.account)

            // Get Avatar
            let fileName = tableAccount.userBaseUrl + "-" + self.appDelegate.user + ".png"
            let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName
            let etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag
            let options = NKRequestOptions(queue: NKCommon.shared.backgroundQueue)

            NextcloudKit.shared.downloadAvatar(user: tableAccount.userId, fileNameLocalPath: fileNameLocalPath, sizeImage: NCGlobal.shared.avatarSize, avatarSizeRounded: NCGlobal.shared.avatarSizeRounded, etag: etag, options: options) { _, _, _, etag, error in
                guard let etag = etag, error == .success else {
                    if error.errorCode == NCGlobal.shared.errorNotModified {
                        NCManageDatabase.shared.setAvatarLoaded(fileName: fileName)
                    }
                    return
                }
                NCManageDatabase.shared.addAvatar(fileName: fileName, etag: etag)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadAvatar, userInfo: nil)
            }

            self.requestServerCapabilities()
            self.requestDashboardWidget()
        }
    }

    // MARK: -

    private func requestServerCapabilities() {
        guard !appDelegate.account.isEmpty else { return }

        let options = NKRequestOptions(queue: NKCommon.shared.backgroundQueue)

        NextcloudKit.shared.getCapabilities(options: options) { account, data, error in
            guard error == .success, let data = data else {
                NCBrandColor.shared.settingThemingColor(account: account)
                return
            }

            NCManageDatabase.shared.addCapabilitiesJSon(data, account: account)
            let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)

            // Setup communication
            if serverVersionMajor > 0 {
                NKCommon.shared.setup(nextcloudVersion: serverVersionMajor)
            }

            // Theming
            let themingColorNew = NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesThemingColor)
            let themingColorElementNew = NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesThemingColorElement)
            let themingColorTextNew = NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesThemingColorText)
            if themingColorNew != NCBrandColor.shared.themingColor || themingColorElementNew != NCBrandColor.shared.themingColorElement || themingColorTextNew != NCBrandColor.shared.themingColorText {
                NCBrandColor.shared.settingThemingColor(account: account)
            }

            // File Sharing
            let isFilesSharingEnabled = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFileSharingApiEnabled, exists: false)
            if isFilesSharingEnabled {
                NextcloudKit.shared.readShares(parameters: NKShareParameter(), options: options) { account, shares, data, error in
                    if error == .success {
                        NCManageDatabase.shared.deleteTableShare(account: account)
                        if let shares = shares, !shares.isEmpty {
                            NCManageDatabase.shared.addShare(account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId, shares: shares)
                        }
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
                let options = NKRequestOptions(queue: NKCommon.shared.backgroundQueue)
                NextcloudKit.shared.NCTextObtainEditorDetails(options: options) { account, editors, creators, data, error in
                    if error == .success && account == self.appDelegate.account {
                        NCManageDatabase.shared.addDirectEditing(account: account, editors: editors, creators: creators)
                    }
                }
            }

            // External file Server
            let isExternalSitesServerEnabled = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesExternalSitesExists, exists: true)
            if isExternalSitesServerEnabled {
                NextcloudKit.shared.getExternalSite(options: options) { account, externalSites, data, error in
                    if error == .success && account == self.appDelegate.account {
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
                NextcloudKit.shared.getUserStatus(options: options) { account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, userId, data, error in
                    if error == .success && account == self.appDelegate.account && userId == self.appDelegate.userId {
                        NCManageDatabase.shared.setAccountUserStatus(userStatusClearAt: clearAt, userStatusIcon: icon, userStatusMessage: message, userStatusMessageId: messageId, userStatusMessageIsPredefined: messageIsPredefined, userStatusStatus: status, userStatusStatusIsUserDefined: statusIsUserDefined, account: account)
                    }
                }
            }

            // Added UTI for Collabora
            if let richdocumentsMimetypes = NCManageDatabase.shared.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesRichdocumentsMimetypes) {
                for mimeType in richdocumentsMimetypes {
                    NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: mimeType, classFile: NKCommon.typeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.typeIconFile.document.rawValue, name: "document")
                }
            }

            // Added UTI for ONLYOFFICE & Text
            if let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: account) {
                for directEditing in directEditingCreators {
                    NKCommon.shared.addInternalTypeIdentifier(typeIdentifier: directEditing.mimetype, classFile: NKCommon.typeClassFile.document.rawValue, editor: directEditing.editor, iconName: NKCommon.typeIconFile.document.rawValue, name: "document")
                }
            }
        }
    }
    
    // MARK: -

    private func requestDashboardWidget() {
        
        let options = NKRequestOptions(queue: NKCommon.shared.backgroundQueue)
        
        NextcloudKit.shared.getDashboardWidget(options: options) { account, dashboardWidgets, data, error in
            Task {
                if error == .success, let dashboardWidgets = dashboardWidgets  {
                    NCManageDatabase.shared.addDashboardWidget(account: account, dashboardWidgets: dashboardWidgets)
                    for widget in dashboardWidgets {
                        if let url = URL(string: widget.iconUrl), let fileName = widget.iconClass {
                            let (_, data, error) = await NextcloudKit.shared.getPreview(url: url)
                            if error == .success {
                                NCUtility.shared.convertDataToImage(data: data, size: CGSize(width: 256, height: 256), fileNameToWrite: fileName)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: -

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
}
