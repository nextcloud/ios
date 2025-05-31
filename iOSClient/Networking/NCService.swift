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
@preconcurrency import NextcloudKit
import RealmSwift

class NCService: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared

    // MARK: -

    public func startRequestServicesServer(account: String, controller: NCMainTabBarController?) {
        guard !account.isEmpty
        else {
            return
        }

        self.database.clearAllAvatarLoaded(sync: false)
        self.addInternalTypeIdentifier(account: account)

        Task(priority: .background) {
            let result = await requestServerStatus(account: account, controller: controller)
            if result {
                await requestServerCapabilities(account: account, controller: controller)
                await getAvatar(account: account)
                await NCNetworkingE2EE().unlockAll(account: account)
                await sendClientDiagnosticsRemoteOperation(account: account)
                await synchronize(account: account)
            }
        }
    }

    // MARK: -

    func addInternalTypeIdentifier(account: String) {
        NextcloudKit.shared.nkCommonInstance.clearInternalTypeIdentifier(account: account)

        // txt
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "text/plain", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.TypeIconFile.document.rawValue, name: "markdown", account: account)

        // html
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "text/html", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.TypeIconFile.document.rawValue, name: "markdown", account: account)

        // markdown
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "net.daringfireball.markdown", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.TypeIconFile.document.rawValue, name: "markdown", account: account)
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "text/x-markdown", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorText, iconName: NKCommon.TypeIconFile.document.rawValue, name: "markdown", account: account)

        // document: text
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.text", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document", account: account)
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.wordprocessingml.document", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document", account: account)
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.word.doc", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document", account: account)
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.pages.pages", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.document.rawValue, name: "pages", account: account)

        // document: sheet
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.spreadsheet", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.TypeIconFile.xls.rawValue, name: "sheet", account: account)
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.spreadsheetml.sheet", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NKCommon.TypeIconFile.xls.rawValue, name: "sheet", account: account)
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.excel.xls", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.xls.rawValue, name: "sheet", account: account)
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.numbers.numbers", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.xls.rawValue, name: "numbers", account: account)

        // document: presentation
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.oasis-open.opendocument.presentation", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.TypeIconFile.ppt.rawValue, name: "presentation", account: account)
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "org.openxmlformats.presentationml.presentation", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorOnlyoffice, iconName: NKCommon.TypeIconFile.ppt.rawValue, name: "presentation", account: account)
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.microsoft.powerpoint.ppt", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.ppt.rawValue, name: "presentation", account: account)
        NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: "com.apple.iwork.keynote.key", classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorQuickLook, iconName: NKCommon.TypeIconFile.ppt.rawValue, name: "keynote", account: account)
    }

    // MARK: -

    private func requestServerStatus(account: String, controller: NCMainTabBarController?) async -> Bool {
        let serverUrl = NCSession.shared.getSession(account: account).urlBase
        let userId = NCSession.shared.getSession(account: account).userId
        let resultServerStatus = await NextcloudKit.shared.getServerStatusAsync(serverUrl: serverUrl)
        switch resultServerStatus.result {
        case .success(let serverInfo):
            if serverInfo.maintenance {
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

        let resultUserProfile = await NextcloudKit.shared.getUserMetadataAsync(account: account, userId: userId, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue))
        if resultUserProfile.error == .success,
           let userProfile = resultUserProfile.userProfile,
           userId == userProfile.userId {
            self.database.setAccountUserProfile(account: resultUserProfile.account, userProfile: userProfile, sync: false)
            return true
        } else {
            return false
        }
    }

    private func getAvatar(account: String) async {
        let session = NCSession.shared.getSession(account: account)
        let fileName = NCSession.shared.getFileName(urlBase: session.urlBase, user: session.user)

        let tblAvatar = await self.database.getTableAvatarAsync(fileName: fileName)
        let resultsDownload = await NextcloudKit.shared.downloadAvatarAsync(user: session.userId,
                                                                            fileNameLocalPath: self.utilityFileSystem.directoryUserData + "/" + fileName,
                                                                            sizeImage: NCGlobal.shared.avatarSize,
                                                                            etag: tblAvatar?.etag,
                                                                            account: account)

        if  resultsDownload.error == .success,
            let etag = resultsDownload.etag,
            etag != tblAvatar?.etag {
            self.database.addAvatar(fileName: fileName, etag: etag, sync: false)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadAvatar, userInfo: ["error": resultsDownload.error])
        } else {
            self.database.setAvatarLoaded(fileName: fileName, sync: false)
        }
    }

    private func requestServerCapabilities(account: String, controller: NCMainTabBarController?) async {
        let resultsCapabilities = await NextcloudKit.shared.getCapabilitiesAsync(account: account)
        guard resultsCapabilities.error == .success, let data = resultsCapabilities.responseData?.data else {
            return
        }

        data.printJson()

        self.database.addCapabilitiesJSon(data, account: account, sync: false)

        guard let capability = self.database.setCapabilities(account: account, data: data) else {
            return
        }

        // Recommendations
        if !NCCapabilities.shared.getCapabilities(account: account).capabilityRecommendations {
            self.database.deleteAllRecommendedFiles(account: account, sync: false)
        }

        // Theming
        if NCBrandColor.shared.settingThemingColor(account: account) {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeTheming, userInfo: ["account": account])
        }

        // Text direct editor detail
        if capability.capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion18 {
            let results = await NextcloudKit.shared.textObtainEditorDetailsAsync(account: account)
            if results.error == .success {
                self.database.addDirectEditing(account: account, editors: results.editors, creators: results.creators, sync: false)
            }
        }

        // External file Server
        if capability.capabilityExternalSites {
            let results = await NextcloudKit.shared.getExternalSiteAsync(account: account)
            if results.error == .success {
                self.database.deleteExternalSites(account: account, sync: false)
                for site in results.externalSite {
                    self.database.addExternalSites(site, account: account, sync: false)
                }
            }
        } else {
            self.database.deleteExternalSites(account: account, sync: false)
        }

        // User Status
        if capability.capabilityUserStatusEnabled {
            let results = await NextcloudKit.shared.getUserStatusAsync(account: account)
            if results.error == .success {
                self.database.setAccountUserStatus(userStatusClearAt: results.clearAt,
                                                   userStatusIcon: results.icon,
                                                   userStatusMessage: results.message,
                                                   userStatusMessageId: results.messageId,
                                                   userStatusMessageIsPredefined: results.messageIsPredefined,
                                                   userStatusStatus: results.status,
                                                   userStatusStatusIsUserDefined: results.statusIsUserDefined,
                                                   account: results.account, sync: false)
            }
        }

        // Added UTI for Collabora
        capability.capabilityRichDocumentsMimetypes.forEach { mimeType in
            NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: mimeType, classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document", account: account)
        }

        // Added UTI for ONLYOFFICE & Text
        self.database.getDirectEditingCreators(account: account,
                                               dispatchOnMainQueue: false) { tblDirectEditingCreators in
            for directEditing in tblDirectEditingCreators {
                NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: directEditing.mimetype, classFile: NKCommon.TypeClassFile.document.rawValue, editor: directEditing.editor, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document", account: account)
            }
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUpdateNotification)
    }

    // MARK: -

    func synchronize(account: String) async {
        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: account)
        let resultsFavorite = await NextcloudKit.shared.listingFavoritesAsync(showHiddenFiles: showHiddenFiles, account: account)
        if resultsFavorite.error == .success, let files = resultsFavorite.files {
            let resultsMetadatas = await self.database.convertFilesToMetadatasAsync(files, useFirstAsMetadataFolder: false)
            if !resultsMetadatas.metadatas.isEmpty {
                await self.database.updateMetadatasFavoriteAsync(account: account, metadatas: resultsMetadatas.metadatas)
            }
        }

        // Synchronize Directory
        let directories = await self.database.getTablesDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND offline == true", account), sorted: "serverUrl", ascending: true)
        for directory in directories {
            await NCNetworking.shared.synchronization(account: account, serverUrl: directory.serverUrl, add: false)
        }

        // Synchronize Files
        let files = await self.database.getTableLocalFilesAsync(predicate: NSPredicate(format: "account == %@ AND offline == true", account), sorted: "fileName", ascending: true)
        for file in files {
            if let metadata = await self.database.getMetadataFromOcIdAsync(file.ocId),
               await NCNetworking.shared.isSynchronizable(ocId: metadata.ocId, fileName: metadata.fileName, etag: metadata.etag) {
                await self.database.setMetadataSessionInWaitDownloadAsync(metadata: metadata,
                                                                          session: NCNetworking.shared.sessionDownloadBackground,
                                                                          selector: NCGlobal.shared.selectorSynchronizationOffline)
            }
        }
    }

    // MARK: -

    func sendClientDiagnosticsRemoteOperation(account: String) async {
        guard NCCapabilities.shared.getCapabilities(account: account).capabilitySecurityGuardDiagnostics,
              self.database.existsDiagnostics(account: account) else {
            return
        }

        struct Issues: Codable {
            struct SyncConflicts: Codable {
                var count: Int?
                var oldest: TimeInterval?
            }

            struct VirusDetected: Codable {
                var count: Int?
                var oldest: TimeInterval?
            }

            struct E2EError: Codable {
                var count: Int?
                var oldest: TimeInterval?
            }

            struct Problem: Codable {
                struct Error: Codable {
                    var count: Int
                    var oldest: TimeInterval
                }

                var forbidden: Error?               // NCGlobal.shared.diagnosticProblemsForbidden
                var badResponse: Error?             // NCGlobal.shared.diagnosticProblemsBadResponse
                var uploadServerError: Error?       // NCGlobal.shared.diagnosticProblemsUploadServerError
            }

            var syncConflicts: SyncConflicts
            var virusDetected: VirusDetected
            var e2eeErrors: E2EError
            var problems: Problem?

            enum CodingKeys: String, CodingKey {
                case syncConflicts = "sync_conflicts"
                case virusDetected = "virus_detected"
                case e2eeErrors = "e2ee_errors"
                case problems
            }
        }

        var ids: [ObjectId] = []

        var syncConflicts: Issues.SyncConflicts = Issues.SyncConflicts()
        var virusDetected: Issues.VirusDetected = Issues.VirusDetected()
        var e2eeErrors: Issues.E2EError = Issues.E2EError()

        var problems: Issues.Problem? = Issues.Problem()
        var problemForbidden: Issues.Problem.Error?
        var problemBadResponse: Issues.Problem.Error?
        var problemUploadServerError: Issues.Problem.Error?

        if let results = await self.database.getDiagnosticsAsync(account: account) {
            if let result = results.first(where: { $0.issue == NCGlobal.shared.diagnosticIssueSyncConflicts }) {
                syncConflicts = Issues.SyncConflicts(count: result.counter, oldest: result.oldest)
                ids.append(result.id)
            }

            if let result = results.first(where: { $0.issue == NCGlobal.shared.diagnosticIssueVirusDetected }) {
                virusDetected = Issues.VirusDetected(count: result.counter, oldest: result.oldest)
                ids.append(result.id)
            }

            if let result = results.first(where: { $0.issue == NCGlobal.shared.diagnosticIssueE2eeErrors }) {
                e2eeErrors = Issues.E2EError(count: result.counter, oldest: result.oldest)
                ids.append(result.id)
            }

            let problemResults = results.filter { $0.issue == NCGlobal.shared.diagnosticIssueProblems }
            for result in problemResults {
                switch result.error {
                case NCGlobal.shared.diagnosticProblemsForbidden:
                    if result.counter >= 1 {
                        problemForbidden = Issues.Problem.Error(count: result.counter, oldest: result.oldest)
                        ids.append(result.id)
                    }
                case NCGlobal.shared.diagnosticProblemsBadResponse:
                    if result.counter >= 2 {
                        problemBadResponse = Issues.Problem.Error(count: result.counter, oldest: result.oldest)
                        ids.append(result.id)
                    }
                case NCGlobal.shared.diagnosticProblemsUploadServerError:
                    if result.counter >= 1 {
                        problemUploadServerError = Issues.Problem.Error(count: result.counter, oldest: result.oldest)
                        ids.append(result.id)
                    }
                default:
                    break
                }
            }

            problems = Issues.Problem(forbidden: problemForbidden, badResponse: problemBadResponse, uploadServerError: problemUploadServerError)

            do {
                let issues = Issues(syncConflicts: syncConflicts, virusDetected: virusDetected, e2eeErrors: e2eeErrors, problems: problems)
                let data = try JSONEncoder().encode(issues)
                data.printJson()
                let results = await NextcloudKit.shared.sendClientDiagnosticsRemoteOperationAsync(data: data, account: account)
                if results.error == .success {
                    await self.database.deleteDiagnosticsAsync(account: account, ids: ids)
                }
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}
