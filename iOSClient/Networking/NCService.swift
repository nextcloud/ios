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

        Task {
            addInternalTypeIdentifier()
            let result = await requestServerStatus()
            if result.serverStatus, let tableAccount = result.tableAccount {
                synchronize(tableAccount: tableAccount)
                getAvatar(tableAccount: tableAccount)
                requestServerCapabilities()
                requestDashboardWidget()
                NCNetworkingE2EE.shared.unlockAll(account: tableAccount.account)
            }
        }
    }

    // MARK: -

    func addInternalTypeIdentifier() {

        // txt
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "text/plain", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.TypeIconFile.document.rawValue, name: "markdown")

        // html
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "text/html", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.TypeIconFile.document.rawValue, name: "markdown")

        // markdown
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "net.daringfireball.markdown", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.TypeIconFile.document.rawValue, name: "markdown")
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "text/x-markdown", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.TypeIconFile.document.rawValue, name: "markdown")

        // document: text
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.text", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document")
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.wordprocessingml.document", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document")
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.word.doc", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document")
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.pages.pages", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.document.rawValue, name: "pages")

        // document: sheet
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.spreadsheet", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.TypeIconFile.xls.rawValue, name: "sheet")
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.spreadsheetml.sheet", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NKCommon.TypeIconFile.xls.rawValue, name: "sheet")
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.excel.xls", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.xls.rawValue, name: "sheet")
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.numbers.numbers", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.xls.rawValue, name: "numbers")

        // document: presentation
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.presentation", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.TypeIconFile.ppt.rawValue, name: "presentation")
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.presentationml.presentation", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NKCommon.TypeIconFile.ppt.rawValue, name: "presentation")
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.powerpoint.ppt", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.ppt.rawValue, name: "presentation")
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.keynote.key", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.ppt.rawValue, name: "keynote")
    }

    // MARK: -

    private func requestServerStatus() async -> (serverStatus: Bool, tableAccount: tableAccount?) {

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        switch await NextcloudKit.shared.getServerStatus(serverUrl: appDelegate.urlBase, options: options) {
        case .success(let serverInfo):
            if serverInfo.maintenance {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_maintenance_mode_")
                NCContentPresenter.shared.showWarning(error: error, priority: .max)
                return (false, nil)
            } else if serverInfo.productName.lowercased().contains("owncloud") {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_warning_owncloud_")
                NCContentPresenter.shared.showWarning(error: error, priority: .max)
                return (false, nil)
            } else if serverInfo.versionMajor <=  NCGlobal.shared.nextcloud_unsupported_version {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_warning_unsupported_")
                NCContentPresenter.shared.showWarning(error: error, priority: .max)
            }
        case .failure(_):
            return(false, nil)
        }

        let resultUserProfile = await NextcloudKit.shared.getUserProfile(options: options)
        if resultUserProfile.error == .success, let userProfile = resultUserProfile.userProfile {
            guard let tableAccount = NCManageDatabase.shared.setAccountUserProfile(account: resultUserProfile.account, userProfile: userProfile) else {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "Internal error: account not found on DB")
                NCContentPresenter.shared.showError(error: error, priority: .max)
                return (false, nil)
            }
            await self.appDelegate.settingAccount(tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user, userId: tableAccount.userId, password: CCUtility.getPassword(tableAccount.account))
            return (true, tableAccount)
        } else if resultUserProfile.error.errorCode == NCGlobal.shared.errorUnauthorized401 ||
                    resultUserProfile.error.errorCode == NCGlobal.shared.errorUnauthorized997 {
            // Ops the server has Unauthorized
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .active && NCNetworking.shared.networkReachability != NKCommon.TypeReachability.notReachable {
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] The server has response with Unauthorized go checkRemoteUser \(resultUserProfile.error.errorCode)")
                    NCNetworkingCheckRemoteUser().checkRemoteUser(account: resultUserProfile.account, error: resultUserProfile.error)
                }
            }
            return (false, nil)
        } else {
            NCContentPresenter.shared.showError(error: resultUserProfile.error, priority: .max)
            return (false, nil)
        }
    }

    func synchronize(tableAccount: tableAccount) {

        NCNetworking.shared.listingFavoritescompletion(selector: NCGlobal.shared.selectorReadFile) { _, _, _ in }
        self.synchronizeOffline(account: tableAccount.account)
    }

    func getAvatar(tableAccount: tableAccount) {

        let fileName = tableAccount.userBaseUrl + "-" + self.appDelegate.user + ".png"
        let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName
        let etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

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
    }

    private func requestServerCapabilities() {
        guard !appDelegate.account.isEmpty else { return }

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.getCapabilities(options: options) { account, data, error in
            guard error == .success, let data = data else {
                NCBrandColor.shared.settingThemingColor(account: account)
                return
            }

            data.printJson()
            
            NCManageDatabase.shared.addCapabilitiesJSon(data, account: account)
            NCManageDatabase.shared.setCapabilities(account: account, data: data)

            // Setup communication
            if NCGlobal.shared.capabilityServerVersionMajor > 0 {
                NextcloudKit.shared.setup(nextcloudVersion: NCGlobal.shared.capabilityServerVersionMajor)
            }

            // Theming
            if NCGlobal.shared.capabilityThemingColor != NCBrandColor.shared.themingColor || NCGlobal.shared.capabilityThemingColorElement != NCBrandColor.shared.themingColorElement || NCGlobal.shared.capabilityThemingColorText != NCBrandColor.shared.themingColorText {
                NCBrandColor.shared.settingThemingColor(account: account)
            }

            // Sharing & Comments
            if !NCGlobal.shared.capabilityFileSharingApiEnabled && !NCGlobal.shared.capabilityFilesComments && NCGlobal.shared.capabilityActivity.isEmpty {
                self.appDelegate.disableSharesView = true
            } else {
                self.appDelegate.disableSharesView = false
            }

            // Text direct editor detail
            if NCGlobal.shared.capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion18 {
                let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
                NextcloudKit.shared.NCTextObtainEditorDetails(options: options) { account, editors, creators, data, error in
                    if error == .success && account == self.appDelegate.account {
                        NCManageDatabase.shared.addDirectEditing(account: account, editors: editors, creators: creators)
                    }
                }
            }

            // External file Server
            if NCGlobal.shared.capabilityExternalSites {
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
            if NCGlobal.shared.capabilityUserStatusEnabled {
                NextcloudKit.shared.getUserStatus(options: options) { account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, userId, data, error in
                    if error == .success && account == self.appDelegate.account && userId == self.appDelegate.userId {
                        NCManageDatabase.shared.setAccountUserStatus(userStatusClearAt: clearAt, userStatusIcon: icon, userStatusMessage: message, userStatusMessageId: messageId, userStatusMessageIsPredefined: messageIsPredefined, userStatusStatus: status, userStatusStatusIsUserDefined: statusIsUserDefined, account: account)
                    }
                }
            }

            // Added UTI for Collabora
            for mimeType in NCGlobal.shared.capabilityRichdocumentsMimetypes {
                NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: mimeType, classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document")
            }

            // Added UTI for ONLYOFFICE & Text
            if let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: account) {
                for directEditing in directEditingCreators {
                    NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: directEditing.mimetype, classFile: NKCommon.TypeClassFile.document.rawValue, editor: directEditing.editor, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document")
                }
            }
        }
    }

    // MARK: -

    private func requestDashboardWidget() {

        @Sendable func convertDataToImage(data: Data?, size:CGSize, fileNameToWrite: String?) {

            guard let data = data else { return }
            var imageData: UIImage?

            if let image = UIImage(data: data), let image = image.resizeImage(size: size) {
                imageData = image
            } else if let image = SVGKImage(data: data) {
                image.size = size
                imageData = image.uiImage
            } else {
                print("error")
            }
            if let fileName = fileNameToWrite, let image = imageData {
                do {
                    let fileNamePath: String = CCUtility.getDirectoryUserData() + "/" + fileName + ".png"
                    try image.pngData()?.write(to: URL(fileURLWithPath: fileNamePath), options: .atomic)
                } catch { }
            }
        }

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        NextcloudKit.shared.getDashboardWidget(options: options) { account, dashboardWidgets, data, error in
            Task {
                if error == .success, let dashboardWidgets = dashboardWidgets  {
                    NCManageDatabase.shared.addDashboardWidget(account: account, dashboardWidgets: dashboardWidgets)
                    for widget in dashboardWidgets {
                        if let url = URL(string: widget.iconUrl), let fileName = widget.iconClass {
                            let (_, data, error) = await NextcloudKit.shared.getPreview(url: url)
                            if error == .success {
                                convertDataToImage(data: data, size: CGSize(width: 256, height: 256), fileNameToWrite: fileName)
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
