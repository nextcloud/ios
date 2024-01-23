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
import RealmSwift

class NCService: NSObject {

    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()

    // MARK: -

    @objc public func startRequestServicesServer() {

        NCManageDatabase.shared.clearAllAvatarLoaded()
        guard !appDelegate.account.isEmpty else { return }
        let account = appDelegate.account

        NCPushNotification.shared().pushNotification()

        Task {
            addInternalTypeIdentifier()
            let result = await requestServerStatus()
            if result {
                synchronize()
                getAvatar()
                requestServerCapabilities()
                requestDashboardWidget()
                NCNetworkingE2EE().unlockAll(account: account)
                NCNetworkingProcessUpload.shared.verifyUploadZombie()
                if NCGlobal.shared.capabilitySecurityGuardDiagnostics {
                    sendClientDiagnosticsRemoteOperation(account: account)
                }
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

    private func requestServerStatus() async -> Bool {

        switch await NextcloudKit.shared.getServerStatus(serverUrl: appDelegate.urlBase, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) {
        case .success(let serverInfo):
            if serverInfo.maintenance {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_maintenance_mode_")
                NCContentPresenter().showWarning(error: error, priority: .max)
                return false
            } else if serverInfo.productName.lowercased().contains("owncloud") {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_warning_owncloud_")
                NCContentPresenter().showWarning(error: error, priority: .max)
                return false
            } else if serverInfo.versionMajor <= NCGlobal.shared.nextcloud_unsupported_version {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_warning_unsupported_")
                NCContentPresenter().showWarning(error: error, priority: .max)
            }
        case .failure:
            return false
        }

        let resultUserProfile = await NextcloudKit.shared.getUserProfile(options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue))
        if resultUserProfile.error == .success, let userProfile = resultUserProfile.userProfile {
            NCManageDatabase.shared.setAccountUserProfile(account: resultUserProfile.account, userProfile: userProfile)
            return true
        } else if resultUserProfile.error.errorCode == NCGlobal.shared.errorUnauthorized401 || resultUserProfile.error.errorCode == NCGlobal.shared.errorUnauthorized997 {
            // Ops the server has Unauthorized
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .active && NCNetworking.shared.networkReachability != NKCommon.TypeReachability.notReachable {
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] The server has response with Unauthorized go checkRemoteUser \(resultUserProfile.error.errorCode)")
                    NCNetworkingCheckRemoteUser().checkRemoteUser(account: resultUserProfile.account, error: resultUserProfile.error)
                }
            }
            return false
        } else {
            NCContentPresenter().showError(error: resultUserProfile.error, priority: .max)
            return false
        }
    }

    func synchronize() {

        NextcloudKit.shared.listingFavorites(showHiddenFiles: NCKeychain().showHiddenFiles,
                                             options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, files, _, error in

            guard error == .success else { return }
            NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, _, metadatas in
                NCManageDatabase.shared.updateMetadatasFavorite(account: account, metadatas: metadatas)
            }
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Synchronize Favorite")
            self.synchronizeOffline(account: account)
        }
    }

    func getAvatar() {

        let fileName = appDelegate.userBaseUrl + "-" + self.appDelegate.user + ".png"
        let fileNameLocalPath = utilityFileSystem.directoryUserData + "/" + fileName
        let etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag

        NextcloudKit.shared.downloadAvatar(user: appDelegate.userId,
                                           fileNameLocalPath: fileNameLocalPath,
                                           sizeImage: NCGlobal.shared.avatarSize,
                                           avatarSizeRounded: NCGlobal.shared.avatarSizeRounded,
                                           etag: etag,
                                           options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, _, _, etag, error in

            if let etag = etag, error == .success {
                NCManageDatabase.shared.addAvatar(fileName: fileName, etag: etag)
            } else if error.errorCode == NCGlobal.shared.errorNotModified {
                NCManageDatabase.shared.setAvatarLoaded(fileName: fileName)
            }
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadAvatar, userInfo: ["error": error])
        }
    }

    private func requestServerCapabilities() {
        guard !appDelegate.account.isEmpty else { return }

        NextcloudKit.shared.getCapabilities(options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, data, error in
            guard error == .success, let data = data else {
                NCBrandColor.shared.settingThemingColor(account: account)
                NCImageCache.shared.createImagesBrandCache()
                return
            }

            data.printJson()

            NCManageDatabase.shared.addCapabilitiesJSon(data, account: account)
            NCManageDatabase.shared.setCapabilities(account: account, data: data)

            // Theming
            if NCGlobal.shared.capabilityThemingColor != NCBrandColor.shared.themingColor || NCGlobal.shared.capabilityThemingColorElement != NCBrandColor.shared.themingColorElement || NCGlobal.shared.capabilityThemingColorText != NCBrandColor.shared.themingColorText {
                NCBrandColor.shared.settingThemingColor(account: account)
                NCImageCache.shared.createImagesBrandCache()
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
                NextcloudKit.shared.NCTextObtainEditorDetails(options: options) { account, editors, creators, _, error in
                    if error == .success && account == self.appDelegate.account {
                        NCManageDatabase.shared.addDirectEditing(account: account, editors: editors, creators: creators)
                    }
                }
            }

            // External file Server
            if NCGlobal.shared.capabilityExternalSites {
                NextcloudKit.shared.getExternalSite(options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, externalSites, _, error in
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
                NextcloudKit.shared.getUserStatus(options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, userId, _, error in
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

        @Sendable func convertDataToImage(data: Data?, size: CGSize, fileNameToWrite: String?) {

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
                    let fileNamePath = utilityFileSystem.directoryUserData + "/" + fileName + ".png"
                    try image.pngData()?.write(to: URL(fileURLWithPath: fileNamePath), options: .atomic)
                } catch { }
            }
        }

        NextcloudKit.shared.getDashboardWidget(options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, dashboardWidgets, data, error in
            Task {
                if error == .success, let dashboardWidgets = dashboardWidgets {
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

        // Synchronize Directory
        Task {
            if let directories = NCManageDatabase.shared.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", account), sorted: "serverUrl", ascending: true) {
                for directory: tableDirectory in directories {
                    await NCNetworking.shared.synchronization(account: account, serverUrl: directory.serverUrl, selector: NCGlobal.shared.selectorSynchronizationOffline)
                }
            }
        }

        // Synchronize Files
        let files = NCManageDatabase.shared.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", account), sorted: "fileName", ascending: true)
        for file: tableLocalFile in files {
            guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(file.ocId) else { continue }
            if metadata.isSynchronizable,
               NCNetworking.shared.downloadQueue.operations.filter({ ($0 as? NCOperationDownload)?.metadata.ocId == metadata.ocId }).isEmpty {
                NCNetworking.shared.downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: NCGlobal.shared.selectorDownloadFile))
            }
        }
    }

    // MARK: -

    func sendClientDiagnosticsRemoteOperation(account: String) {
        if !NCManageDatabase.shared.existsDiagnostics(account: account) { return }

        /*


         let json = """
         {
             "sync_conflicts": {"count": 3, "oldest": 12312332423},
             "problems": {
                 "UploadResult.CREDENTIAL_ERROR": {"count": 1, "oldest": 1213123132},
                 "UploadResult.FOLDER_ERROR": {"count": 5, "oldest": 654654655}
             },
             "virus_detected": {"count": 1, "oldest": 13343345},
             "e2e_errors": {"count": 5, "oldest": 345535454}
         }
         """

         if let jsonData = json.data(using: .utf8) {
             do {
                 let decoder = JSONDecoder()
                 let issuesData = try decoder.decode(IssuesData.self, from: jsonData)

                 // Now, issuesData contains the decoded data
                 print(issuesData)

                 // If you want to encode it back to JSON, you can use JSONEncoder
                 let encoder = JSONEncoder()
                 encoder.outputFormatting = .prettyPrinted
                 let encodedData = try encoder.encode(issuesData)

                 if let encodedJson = String(data: encodedData, encoding: .utf8) {
                     print(encodedJson)
                 }
             } catch {
                 print("Error decoding JSON: \(error)")
             }
         }
         */

        struct Issues: Codable {

            struct SyncConflicts: Codable {
                var count: Int?
                var oldest: TimeInterval?
            }

            struct Problem: Codable {
                struct Error: Codable {
                    var count: Int
                    var oldest: TimeInterval
                }

                var credentialError: Error?
                var uploadForbidden: Error?
            }

            struct VirusDetected: Codable {
                var count: Int?
                var oldest: TimeInterval?
            }

            struct E2EError: Codable {
                var count: Int?
                var oldest: TimeInterval?
            }

            var syncConflicts: SyncConflicts
            var problems: Problem?
            var virusDetected: VirusDetected
            var e2eeErrors: E2EError

            enum CodingKeys: String, CodingKey {
                case syncConflicts = "sync_conflicts"
                case problems
                case virusDetected = "virus_detected"
                case e2eeErrors = "e2ee_errors"
            }
        }

        var syncConflicts: Issues.SyncConflicts = Issues.SyncConflicts()
        var virusDetected: Issues.VirusDetected = Issues.VirusDetected()
        var e2eeErrors: Issues.E2EError = Issues.E2EError()

        var problems: Issues.Problem? = Issues.Problem()
        var uploadForbidden: Issues.Problem.Error?

        if let result = NCManageDatabase.shared.getDiagnostics(account: account, issue: NCGlobal.shared.diagnosticIssueSyncConflicts)?.first {
            syncConflicts = Issues.SyncConflicts(count: result.counter, oldest: result.oldest)
        }
        if let result = NCManageDatabase.shared.getDiagnostics(account: account, issue: NCGlobal.shared.diagnosticIssueVirusDetected)?.first {
            virusDetected = Issues.VirusDetected(count: result.counter, oldest: result.oldest)
        }
        if let result = NCManageDatabase.shared.getDiagnostics(account: account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)?.first {
            e2eeErrors = Issues.E2EError(count: result.counter, oldest: result.oldest)
        }
        if let results = NCManageDatabase.shared.getDiagnostics(account: account, issue: NCGlobal.shared.diagnosticIssueProblems) {
            for result in results {
                switch result.error {
                case NCGlobal.shared.diagnosticProblemsUploadForbidden:
                    uploadForbidden = Issues.Problem.Error(count: result.counter, oldest: result.oldest)
                default:
                    break
                }
            }
            problems = Issues.Problem(credentialError: nil, uploadForbidden: uploadForbidden)
        }

        do {

            let issues = Issues(syncConflicts: syncConflicts, problems: problems, virusDetected: virusDetected, e2eeErrors: e2eeErrors)
            let data = try JSONEncoder().encode(issues)
            data.printJson()

            NextcloudKit.shared.sendClientDiagnosticsRemoteOperation(data: data, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, error in
                if error == .success {
                    NCManageDatabase.shared.deleteDiagnostics(account: account)
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}
