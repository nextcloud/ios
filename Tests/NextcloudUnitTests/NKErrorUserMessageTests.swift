// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Testing
@testable import Nextcloud

@Suite("Error messages shown to people")
struct NKErrorUserMessageTests {
    static let shownKinds = NKError.Kind.allCases.filter { $0 != .cancelled }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    @Test("Nothing is shown for success or cancellation")
    func silentErrors() {
        #expect(NKError.success.userMessage() == nil)
        #expect(NKError.cancelled.userMessage(for: .upload(fileName: "a.jpg")) == nil)
        #expect(NKError(errorCode: NCGlobal.shared.errorTaskCancelled, errorDescription: "Task cancelled").userMessage() == nil)
    }

    @Test("Keeps text the app wrote itself")
    func appMessages() {
        #expect(NKError(errorCode: NCGlobal.shared.errorOfflineNotAllowed, errorDescription: "_offline_not_allowed_").userMessage() == localized("_offline_not_allowed_"))
        #expect(NKError(errorCode: NCGlobal.shared.errorE2EELock, errorDescription: "Already translated").userMessage() == "Already translated")
    }

    @Test("Prefers the server's message when Nextcloud wrote it for people")
    func userFacingServerMessage() {
        let body = Data(#"{"ocs":{"meta":{"statuscode":403},"data":"Group sharing is disabled by the administrator"}}"#.utf8)
        let error = NKError(errorCode: 403, errorDescription: "403: Forbidden", responseData: body)

        #expect(error.userMessage(for: .delete(fileName: "a.jpg")) == "Group sharing is disabled by the administrator")
    }

    @Test("Replaces technical server text")
    func technicalServerText() {
        let error = NKError(statusCode: 409, fallbackDescription: "Parent node does not exist")

        #expect(error.userMessage(for: .createFolder(folderName: "a/b")) == localized("_error_create_folder_no_parent_"))
        #expect(error.userMessage() == localized("_error_changed_on_server_"))
    }

    @Test("Words errors for the operation that failed")
    func operationMessages() {
        let forbidden = NKError(errorCode: 403, errorDescription: "403: Forbidden")

        #expect(forbidden.userMessage(for: .delete(fileName: "a.jpg")) == localized("_no_permission_delete_file_"))
        #expect(forbidden.userMessage(for: .rename) == localized("_no_permission_modify_file_"))
        #expect(forbidden.userMessage(for: .upload(fileName: "a.jpg")) == localized("_no_file_no_permission_to_create_"))
        #expect(forbidden.userMessage() == localized("_error_forbidden_"))
        #expect(NKError(errorCode: 405, errorDescription: "405", kind: .alreadyExists).userMessage(for: .createFolder(folderName: "Photos")) == localized("_error_create_folder_exists_"))
        #expect(NKError(errorCode: 404, errorDescription: "404: Not found").userMessage(for: .download(fileName: "a.jpg")) == localized("_error_download_not_found_"))
    }

    @Test("Recognizes uploads rejected by the virus scanner")
    func virusDetected() {
        let error = NKError(errorCode: 415, errorDescription: "Virus Eicar-Signature is detected in the file. Upload cannot be completed.")

        #expect(error.userMessage(for: .upload(fileName: "eicar.com")) == localized("_virus_detect_"))
    }

    @Test("Falls back to the kind of failure")
    func kindMessages() {
        #expect(NKError(errorCode: NSURLErrorTimedOut, errorDescription: "The request timed out.").userMessage(for: .upload(fileName: "a.jpg")) == localized("_error_timeout_"))
        #expect(NKError(errorCode: 507, errorDescription: "507: Storage quota is reached").userMessage() == localized("_error_quota_exceeded_"))
        #expect(NKError(errorCode: 418, errorDescription: "418: I'm a teapot").userMessage() == localized("_error_occurred_"))
    }

    @Test("Every kind has a translated message", arguments: NKErrorUserMessageTests.shownKinds)
    func everyKind(kind: NKError.Kind) {
        let message = NKError(errorCode: -1, errorDescription: "Technical", kind: kind).userMessage()

        #expect(message != nil)
        #expect(message != "Technical")
        #expect(message?.hasPrefix("_") == false)
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
        let contexts: [NCErrorContext] = [.upload(fileName: "f"), .download(fileName: "f"), .delete(fileName: "f"), .rename, .moveOrCopy(fileName: "f"), .createFolder(folderName: "f"), .favorite(fileName: "f")]

        #expect(NCErrorContext.generic.failureTitle == nil)
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

        #expect(metadata.sessionErrorMessage == localized("_error_quota_exceeded_"))

        metadata.errorCode = NSURLErrorCancelled
        metadata.sessionError = "Transfer was cancelled."

        #expect(metadata.sessionErrorMessage == localized("_error_transfer_cancelled_"))
    }
}
