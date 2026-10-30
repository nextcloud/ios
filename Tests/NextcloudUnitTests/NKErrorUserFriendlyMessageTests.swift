// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Testing
@testable import Nextcloud

@Suite("Error messages shown to people")
struct NKErrorUserFriendlyMessageTests {
    static let shownKinds = NKError.Kind.allCases.filter { $0 != .cancelled }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    @Test("Nothing is shown for success or cancellation")
    func silentErrors() {
        #expect(NKError.success.userFriendlyMessage() == nil)
        #expect(NKError.cancelled.userFriendlyMessage(for: .upload(fileName: "a.jpg")) == nil)
        #expect(NKError(errorCode: NCGlobal.shared.errorTaskCancelled, errorDescription: "Task cancelled").userFriendlyMessage() == nil)
    }

    @Test("Keeps text the app wrote itself")
    func appMessages() {
        #expect(NKError(errorCode: NCGlobal.shared.errorOfflineNotAllowed, errorDescription: "_offline_not_allowed_").userFriendlyMessage() == localized("_offline_not_allowed_"))
        #expect(NKError(errorCode: NCGlobal.shared.errorE2EELock, errorDescription: "Already translated").userFriendlyMessage() == "Already translated")
    }

    @Test("Replaces technical server text")
    func technicalServerText() throws {
        let error = NKError(errorCode: 409, errorDescription: "Parent node does not exist")
        let generic = try #require(error.userFriendlyMessage())

        #expect(error.userFriendlyMessage(for: .createFolder(folderName: "a/b")) == localized("_error_create_folder_no_parent_"))
        #expect(generic != error.errorDescription)
        #expect(!generic.contains("409"))
    }

    @Test("Uses the generic message unless the operation needs its own")
    func operationMessages() {
        let forbidden = NKError(errorCode: 403, errorDescription: "403: Forbidden")
        let generic = forbidden.userFriendlyMessage()

        #expect(generic != nil)
        #expect(forbidden.userFriendlyMessage(for: .delete(fileName: "a.jpg")) == generic)
        #expect(forbidden.userFriendlyMessage(for: .rename) == generic)
        #expect(forbidden.userFriendlyMessage(for: .upload(fileName: "a.jpg")) == generic)
    }

    @Test("Explains document and login failures")
    func documentAndLoginMessages() {
        let forbidden = NKError(errorCode: 403, errorDescription: "403: Forbidden")
        let notFound = NKError(errorCode: 404, errorDescription: "404: Not found")
        let unauthorized = NKError(errorCode: 401, errorDescription: "401: Unauthorized")
        let offline = NKError(errorCode: NSURLErrorNotConnectedToInternet, errorDescription: "The Internet connection appears to be offline.")

        #expect(forbidden.userFriendlyMessage(for: .createDocument(fileName: "a.md")) == localized("_error_create_document_"))
        #expect(forbidden.userFriendlyMessage(for: .openDocument(fileName: "a.md")) == localized("_error_open_document_"))
        #expect(notFound.userFriendlyMessage(for: .openDocument(fileName: "a.md")) == notFound.userFriendlyMessage())
        #expect(unauthorized.userFriendlyMessage(for: .login) == localized("_error_login_credentials_"))
        #expect(forbidden.userFriendlyMessage(for: .login) == localized("_error_login_credentials_"))
        #expect(offline.userFriendlyMessage(for: .login) == offline.userFriendlyMessage())
        #expect(NKError(error: CancellationError()).userFriendlyMessage() == nil)
    }

    @Test("Recognizes uploads rejected by the virus scanner")
    func virusDetected() {
        let error = NKError(errorCode: 415, errorDescription: "Virus Eicar-Signature is detected in the file. Upload cannot be completed.")

        #expect(error.userFriendlyMessage(for: .upload(fileName: "eicar.com")) == localized("_virus_detect_"))
    }

    @Test("Words different kinds of failure differently")
    func kindMessages() {
        let timeout = NKError(errorCode: NSURLErrorTimedOut, errorDescription: "The request timed out.").userFriendlyMessage()
        let quota = NKError(errorCode: 507, errorDescription: "507: Storage quota is reached").userFriendlyMessage()
        let unknown = NKError(errorCode: 418, errorDescription: "418: I'm a teapot").userFriendlyMessage()

        #expect(Set([timeout, quota, unknown]).count == 3)
        #expect(quota != "507: Storage quota is reached")
    }

    @Test("Every kind has a translated message", arguments: NKErrorUserFriendlyMessageTests.shownKinds)
    func everyKind(kind: NKError.Kind) {
        let message = NKError(errorCode: -1, errorDescription: "Technical", kind: kind).userFriendlyMessage()

        #expect(message != nil)
        #expect(message != "Technical")
    }

    @Test("Maps transfer events and saved statuses to operations")
    func contexts() {
        let global = NCGlobal.shared

        #expect(NCErrorContext(networkingStatus: global.networkingStatusUploaded, fileName: "a.jpg") == .upload(fileName: "a.jpg"))
        #expect(NCErrorContext(networkingStatus: global.networkingStatusCopyMove, fileName: "a.jpg") == .moveOrCopy(fileName: "a.jpg"))
        #expect(NCErrorContext(networkingStatus: global.networkingStatusReloadAvatar, fileName: "") == .generic)
        #expect(NCErrorContext(metadataStatus: global.metadataStatusWaitCreateFolder, fileName: "Photos") == .createFolder(folderName: "Photos"))
        #expect(NCErrorContext(metadataStatus: global.metadataStatusDownloadError, fileName: "a.jpg") == .download(fileName: "a.jpg"))
    }

    @Test("Titles say what failed")
    func failureTitles() throws {
        let contexts: [NCErrorContext] = [.upload(fileName: "f"), .download(fileName: "f"), .delete(fileName: "f"), .rename, .moveOrCopy(fileName: "f"), .createFolder(folderName: "f"), .favorite(fileName: "f"), .createDocument(fileName: "f"), .openDocument(fileName: "f")]

        #expect(NCErrorContext.generic.failureTitle == nil)
        #expect(NCErrorContext.login.failureTitle == nil)
        #expect(NCErrorContext.upload(fileName: "IMG_0042.jpg").failureTitle?.contains("IMG_0042.jpg") == true)

        for context in contexts {
            let title = try #require(context.failureTitle)

            #expect(!title.hasPrefix("_"))
        }
    }

    @Test("Words saved transfer errors")
    func savedErrors() {
        let metadata = tableMetadata()
        metadata.fileNameView = "a.jpg"
        metadata.status = NCGlobal.shared.metadataStatusUploadError
        metadata.errorCode = 507
        metadata.sessionError = "507: Storage quota is reached"

        #expect(metadata.sessionErrorMessage == NKError(errorCode: 507, errorDescription: "").userFriendlyMessage())

        metadata.errorCode = NSURLErrorCancelled
        metadata.sessionError = "Transfer was cancelled."

        #expect(metadata.sessionErrorMessage != "Transfer was cancelled.")
        #expect(!metadata.sessionErrorMessage.isEmpty)
    }
}
