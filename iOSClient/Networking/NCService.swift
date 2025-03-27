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

    // MARK: -

    public func startRequestServicesServer(account: String, controller: NCMainTabBarController?) {
        guard !account.isEmpty
        else {
            return
        }

        self.database.clearAllAvatarLoaded()
        self.addInternalTypeIdentifier(account: account)

        Task(priority: .background) {
            let result = await requestServerStatus(account: account, controller: controller)
            if result {
                requestServerCapabilities(account: account, controller: controller)
                getAvatar(account: account)
                NCNetworkingE2EE().unlockAll(account: account)
                sendClientDiagnosticsRemoteOperation(account: account)
                synchronize(account: account)
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
        switch await NCNetworking.shared.getServerStatus(serverUrl: serverUrl, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) {
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

        let resultUserProfile = await NCNetworking.shared.getUserProfile(account: account, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue))
        if resultUserProfile.error == .success,
           let userProfile = resultUserProfile.userProfile {
            self.database.setAccountUserProfile(account: resultUserProfile.account, userProfile: userProfile)
            return true
        } else {
            return false
        }
    }

    func synchronize(account: String) {
        NextcloudKit.shared.listingFavorites(showHiddenFiles: NCKeychain().showHiddenFiles,
                                             account: account,
                                             options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, files, _, error in
            guard error == .success, let files else { return }
            self.database.convertFilesToMetadatas(files, useFirstAsMetadataFolder: false) { _, metadatas in
                self.database.updateMetadatasFavorite(account: account, metadatas: metadatas)
            }
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Synchronize Favorite")
            self.synchronizeOffline(account: account)
        }
    }

    func getAvatar(account: String) {
        let session = NCSession.shared.getSession(account: account)
        let fileName = NCSession.shared.getFileName(urlBase: session.urlBase, user: session.user)
        let etag = self.database.getTableAvatar(fileName: fileName)?.etag

        NextcloudKit.shared.downloadAvatar(user: session.userId,
                                           fileNameLocalPath: utilityFileSystem.directoryUserData + "/" + fileName,
                                           sizeImage: NCGlobal.shared.avatarSize,
                                           avatarSizeRounded: NCGlobal.shared.avatarSizeRounded,
                                           etag: etag,
                                           account: account,
                                           options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, _, _, newEtag, _, error in
            if let newEtag,
               etag != newEtag,
               error == .success {
                self.database.addAvatar(fileName: fileName, etag: newEtag)

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadAvatar, userInfo: ["error": error])
            } else if error.errorCode == NCGlobal.shared.errorNotModified {
                self.database.setAvatarLoaded(fileName: fileName)
            }
        }
    }

    private func requestServerCapabilities(account: String, controller: NCMainTabBarController?) {
        NextcloudKit.shared.getCapabilities(account: account, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, presponseData, error in
            guard error == .success, let data = presponseData?.data else {
                return
            }

            data.printJson()

            self.database.addCapabilitiesJSon(data, account: account)

            guard let capability = self.database.setCapabilities(account: account, data: data) else {
                return
            }

            // Recommendations
            if NCCapabilities.shared.getCapabilities(account: account).capabilityRecommendations {
                Task.detached {
                    let session = NCSession.shared.getSession(account: account)
                    await NCNetworking.shared.createRecommendations(session: session)
                }
            } else {
                self.database.deleteAllRecommendedFiles(account: account)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadHeader, userInfo: ["account": account])
            }

            // Theming
            if NCBrandColor.shared.settingThemingColor(account: account) {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeTheming, userInfo: ["account": account])
            }

            // Text direct editor detail
            if capability.capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion18 {
                let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
                NextcloudKit.shared.NCTextObtainEditorDetails(account: account, options: options) { account, editors, creators, _, error in
                    if error == .success {
                        self.database.addDirectEditing(account: account, editors: editors, creators: creators)
                    }
                }
            }

            // External file Server
            if capability.capabilityExternalSites {
                NextcloudKit.shared.getExternalSite(account: account, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, externalSites, _, error in
                    if error == .success {
                        self.database.deleteExternalSites(account: account)
                        for externalSite in externalSites {
                            self.database.addExternalSites(externalSite, account: account)
                        }
                    }
                }
            } else {
                self.database.deleteExternalSites(account: account)
            }

            // User Status
            if capability.capabilityUserStatusEnabled {
                NextcloudKit.shared.getUserStatus(account: account, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, _, _, error in
                    if error == .success {
                        self.database.setAccountUserStatus(userStatusClearAt: clearAt, userStatusIcon: icon, userStatusMessage: message, userStatusMessageId: messageId, userStatusMessageIsPredefined: messageIsPredefined, userStatusStatus: status, userStatusStatusIsUserDefined: statusIsUserDefined, account: account)
                    }
                }
            }

            // Notifications
            controller?.availableNotifications = false
            if capability.capabilityNotification.count > 0 {
                NextcloudKit.shared.getNotifications(account: account) { _ in
                } completion: { _, notifications, _, error in
                    if error == .success, let notifications = notifications, notifications.count > 0 {
                        controller?.availableNotifications = true
                    }
                }
            }

            // Added UTI for Collabora
            capability.capabilityRichDocumentsMimetypes.forEach { mimeType in
                NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: mimeType, classFile: NKCommon.TypeClassFile.document.rawValue, editor: NCGlobal.shared.editorCollabora, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document", account: account)
            }

            // Added UTI for ONLYOFFICE & Text
            if let directEditingCreators = self.database.getDirectEditingCreators(account: account) {
                for directEditing in directEditingCreators {
                    NextcloudKit.shared.nkCommonInstance.addInternalTypeIdentifier(typeIdentifier: directEditing.mimetype, classFile: NKCommon.TypeClassFile.document.rawValue, editor: directEditing.editor, iconName: NKCommon.TypeIconFile.document.rawValue, name: "document", account: account)
                }
            }
        }
    }

    // MARK: -

    @objc func synchronizeOffline(account: String) {
        // Synchronize Directory
        Task {
            if let directories = self.database.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", account), sorted: "serverUrl", ascending: true) {
                for directory: tableDirectory in directories {
                    await NCNetworking.shared.synchronization(account: account, serverUrl: directory.serverUrl, add: false)
                }
            }
        }

        // Synchronize Files
        let files = self.database.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", account), sorted: "fileName", ascending: true)
        for file: tableLocalFile in files {
            guard let metadata = self.database.getMetadataFromOcId(file.ocId) else { continue }
            if NCNetworking.shared.isSynchronizable(ocId: metadata.ocId, fileName: metadata.fileName, etag: metadata.etag) {
                self.database.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                session: NCNetworking.shared.sessionDownloadBackground,
                                                                selector: NCGlobal.shared.selectorSynchronizationOffline)
            }
        }
    }

    // MARK: -

    func sendClientDiagnosticsRemoteOperation(account: String) {
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

        if let result = self.database.getDiagnostics(account: account, issue: NCGlobal.shared.diagnosticIssueSyncConflicts)?.first {
            syncConflicts = Issues.SyncConflicts(count: result.counter, oldest: result.oldest)
            ids.append(result.id)
        }
        if let result = self.database.getDiagnostics(account: account, issue: NCGlobal.shared.diagnosticIssueVirusDetected)?.first {
            virusDetected = Issues.VirusDetected(count: result.counter, oldest: result.oldest)
            ids.append(result.id)
        }
        if let result = self.database.getDiagnostics(account: account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)?.first {
            e2eeErrors = Issues.E2EError(count: result.counter, oldest: result.oldest)
            ids.append(result.id)
        }
        if let results = self.database.getDiagnostics(account: account, issue: NCGlobal.shared.diagnosticIssueProblems) {
            for result in results {
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
        }

        do {
            let issues = Issues(syncConflicts: syncConflicts, virusDetected: virusDetected, e2eeErrors: e2eeErrors, problems: problems)
            let data = try JSONEncoder().encode(issues)
            data.printJson()
            NextcloudKit.shared.sendClientDiagnosticsRemoteOperation(data: data, account: account, options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, _, error in
                if error == .success {
                    self.database.deleteDiagnostics(account: account, ids: ids)
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}
