// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import Alamofire

class NCNetworkingE2EE: NSObject {
    let database = NCManageDatabase.shared
    let e2EEApiVersion1 = "v1"
    let e2EEApiVersion2 = "v2"

    /// Executes at most one user-certificate request per account while the app
    /// remains active. Concurrent callers share the same in-flight request.
    private actor ServerKeyValidationGate {
        private var validations: [String: Task<NKError, Never>] = [:]

        func beginNewActiveCycle() {
            validations.removeAll()
        }

        func validate(
            account: String,
            operation: @escaping @Sendable () async -> NKError
        ) async -> NKError {
            if let validation = validations[account] {
                return await validation.value
            }

            let validation = Task { await operation() }
            validations[account] = validation
            return await validation.value
        }

        func markValidated(account: String) {
            validations[account] = Task { .success }
        }
    }

    private static let serverKeyValidationGate = ServerKeyValidationGate()

    public struct X509CertificateValidity {
        let notBefore: Date
        let notAfter: Date

        var isValid: Bool {
            let now = Date()
            return now >= notBefore && now <= notAfter
        }

        var isExpired: Bool {
            Date() > notAfter
        }
    }

    enum E2EECSRError: Error {
        case invalidPrivateKey
        case unableToCreateRequest
        case unableToSetSubject
        case unableToSetPublicKey
        case unableToSignRequest
        case unableToEncodeRequest
    }

    func isInUpload(account: String, serverUrl: String) async -> Bool {
        let counter = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d)",
                                                                                   account,
                                                                                   serverUrl,
                                                                                   NCGlobal.shared.metadataStatusWaitUpload,
                                                                                   NCGlobal.shared.metadataStatusUploading))?.count ?? 0

        return counter > 0 ? true : false
    }

    func generateRandomIdentifier() -> String {
        var UUID = NSUUID().uuidString
        UUID = "E2EE" + UUID.replacingOccurrences(of: "-", with: "")
        return UUID
    }

    func getOptions(account: String, capabilities: NKCapabilities.Capabilities) -> NKRequestOptions {
        var version = e2EEApiVersion1
        if capabilities.e2EEApiVersion.hasPrefix("2.") {
            version = e2EEApiVersion2
        }
        return NKRequestOptions(version: version)
    }

    /// Invalidates the result of the current foreground period. The first
    /// subsequent E2EE access will perform one new server validation.
    static func beginNewServerKeyValidationCycle() async {
        await serverKeyValidationGate.beginNewActiveCycle()
        nkLog(
            tag: NCGlobal.shared.logTagE2EE,
            message: "Started a new server-key validation cycle."
        )
    }

    /// Records a key set that was already fetched and cryptographically
    /// verified by setup, avoiding a redundant request in the same cycle.
    static func markServerKeyAsValidated(account: String) async {
        await serverKeyValidationGate.markValidated(account: account)
        nkLog(
            tag: NCGlobal.shared.logTagE2EE,
            message: "Server key marked as validated by E2EE setup."
        )
    }

    /// Verifies once per active app cycle that the locally active user key is
    /// still the key published by the server. The server public key only
    /// authenticates the remote certificate; the embedded user public keys
    /// determine whether the user's key pair changed.
    func validateCurrentServerKey(account: String) async -> NKError {
        let preferences = NCPreferences()
        guard let localCertificate = preferences.getEndToEndCertificate(account: account),
              !localCertificate.isEmpty,
              let serverPublicKey = preferences.getEndToEndPublicKey(account: account),
              !serverPublicKey.isEmpty else {
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "Server-key validation skipped because the active key set is incomplete."
            )
            return NKError(
                errorCode: NCGlobal.shared.errorE2EENotEnabled,
                errorDescription: NSLocalizedString("_e2ee_no_metadataKey_found_", comment: "")
            )
        }

        if preferences.isEndToEndServerKeyStale(account: account) {
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "Server-key validation blocked because the active key set is stale."
            )
            return Self.serverKeyChangedError
        }

        return await Self.serverKeyValidationGate.validate(
            account: account
        ) {
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "Validating the active user key against the server."
            )
            return await Self.performServerKeyValidation(
                account: account,
                localCertificate: localCertificate,
                serverPublicKey: serverPublicKey
            )
        }
    }

    private static func performServerKeyValidation(
        account: String,
        localCertificate: String,
        serverPublicKey: String
    ) async -> NKError {
        let networkingE2EE = NCNetworkingE2EE()
        let preferences = NCPreferences()
        let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
        let result = await NextcloudKit.shared.getE2EECertificateAsync(
            account: account,
            options: networkingE2EE.getOptions(account: account, capabilities: capabilities)
        )

        if result.error.errorCode == NCGlobal.shared.errorResourceNotFound {
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "The server user certificate is missing."
            )
            return markCurrentServerKeyAsStale(
                account: account,
                expectedCertificate: localCertificate,
                preferences: preferences
            )
        }

        guard result.error == .success else {
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "Server-key validation request failed with error code \(result.error.errorCode)."
            )
            return result.error
        }

        guard let remoteCertificate = result.certificate, !remoteCertificate.isEmpty,
              let endToEndEncryption = NCEndToEndEncryption.shared(),
              let localUserPublicKey = endToEndEncryption.extractPublicKey(fromCertificate: localCertificate),
              let remoteUserPublicKey = endToEndEncryption.extractPublicKey(fromCertificate: remoteCertificate) else {
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "Server-key validation received invalid certificate data."
            )
            return .invalidData
        }

        guard endToEndEncryption.verifyCertificate(remoteCertificate, publicKey: serverPublicKey) else {
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "Server-key validation detected an invalid remote certificate."
            )
            return markCurrentServerKeyAsStale(
                account: account,
                expectedCertificate: localCertificate,
                preferences: preferences
            )
        }

        guard networkingE2EE.publicKeysMatch(localUserPublicKey, remoteUserPublicKey) else {
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "Server-key validation detected a changed user key."
            )
            return markCurrentServerKeyAsStale(
                account: account,
                expectedCertificate: localCertificate,
                preferences: preferences
            )
        }

        preferences.setEndToEndServerKeyStale(account: account, stale: false)
        nkLog(
            tag: NCGlobal.shared.logTagE2EE,
            message: "The active user key matches the server."
        )
        return .success
    }

    /// Compares the PEM payload rather than its formatting. Kept internal so
    /// normal and changed-key behavior can be covered by unit tests.
    func publicKeysMatch(_ first: String, _ second: String) -> Bool {
        func payload(_ key: String) -> String {
            key.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("-----") }
                .joined()
        }

        let firstPayload = payload(first)
        let secondPayload = payload(second)
        return !firstPayload.isEmpty && firstPayload == secondPayload
    }

    private static func markCurrentServerKeyAsStale(
        account: String,
        expectedCertificate: String,
        preferences: NCPreferences
    ) -> NKError {
        // Setup may have replaced the active set while this request was in
        // flight. An obsolete response must never mark the new set as stale.
        guard preferences.getEndToEndCertificate(account: account) == expectedCertificate else {
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "Ignored an obsolete server-key validation response."
            )
            return .success
        }

        do {
            try preferences.archiveCurrentEndToEndKeySet(account: account)
            preferences.setEndToEndServerKeyStale(account: account, stale: true)
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "Archived the active key set and marked it as stale."
            )
            return serverKeyChangedError
        } catch {
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "Unable to archive the active key set after server-key validation."
            )
            return NKError(
                errorCode: NCGlobal.shared.errorInternalError,
                errorDescription: error.localizedDescription
            )
        }
    }

    private static var serverKeyChangedError: NKError {
        NKError(
            errorCode: NCGlobal.shared.errorE2EEServerKeyChanged,
            errorDescription: NSLocalizedString("_e2ee_server_key_changed_", comment: "")
        )
    }

    // MARK: -

    func getMetadata(fileId: String, e2eToken: String?, account: String) async -> (account: String,
                                                                                   version: String?,
                                                                                   e2eMetadata: String?,
                                                                                   signature: String?,
                                                                                   responseData: AFDataResponse<Data>?,
                                                                                   error: NKError) {
        let capabilities = await NKCapabilities.shared.getCapabilities(for: account)

        switch capabilities.e2EEApiVersion {
        case let v where v.hasPrefix("1."):
            let options = NKRequestOptions(version: e2EEApiVersion1)
            let results = await NextcloudKit.shared.getE2EEMetadataAsync(fileId: fileId, e2eToken: e2eToken, account: account, options: options) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                path: fileId,
                                                                                                name: "getE2EEMetadata")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            return (results.account, self.e2EEApiVersion1, results.e2eMetadata, results.signature, results.responseData, results.error)
        case let v where v.hasPrefix("2."):
            var options = NKRequestOptions(version: e2EEApiVersion2)
            let results = await NextcloudKit.shared.getE2EEMetadataAsync(fileId: fileId, e2eToken: e2eToken, account: account, options: options) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                path: fileId,
                                                                                                name: "getE2EEMetadata")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            if results.error == .success || results.error.errorCode == NCGlobal.shared.errorResourceNotFound {
                return (results.account, self.e2EEApiVersion2, results.e2eMetadata, results.signature, results.responseData, results.error)
            } else {
                options = NKRequestOptions(version: self.e2EEApiVersion1)
                let results = await NextcloudKit.shared.getE2EEMetadataAsync(fileId: fileId, e2eToken: e2eToken, account: account, options: options) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                    path: fileId,
                                                                                                    name: "getE2EEMetadata")
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                }
                if results.error == .success || results.error.errorCode == NCGlobal.shared.errorResourceNotFound {
                    return (results.account, self.e2EEApiVersion2, results.e2eMetadata, results.signature, results.responseData, results.error)
                } else {
                    options = NKRequestOptions(version: self.e2EEApiVersion1)
                    let results = await NextcloudKit.shared.getE2EEMetadataAsync(fileId: fileId, e2eToken: e2eToken, account: account, options: options) { task in
                        Task {
                            let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                        path: fileId,
                                                                                                        name: "getE2EEMetadata")
                            await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                        }
                    }
                    return (results.account, self.e2EEApiVersion1, results.e2eMetadata, results.signature, results.responseData, results.error)
                }
            }
        default:
            return ("", "", nil, nil, nil, NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "version e2ee not available"))
        }
    }

    // MARK: -

    private enum MetadataUploadMode {
        case updateOrRecover
        case initialCreation
    }

    @discardableResult
    func uploadMetadata(serverUrl: String,
                        addUserId: String? = nil,
                        removeUserId: String? = nil,
                        updateVersionV1V2: Bool = false,
                        account: String) async -> NKError {
        let serverKeyError = await validateCurrentServerKey(account: account)
        guard serverKeyError == .success else {
            return serverKeyError
        }

        return await uploadMetadata(
            serverUrl: serverUrl,
            addUserId: addUserId,
            removeUserId: removeUserId,
            updateVersionV1V2: updateVersionV1V2,
            mode: .updateOrRecover,
            account: account
        )
    }

    @discardableResult
    func createInitialMetadata(serverUrl: String, account: String) async -> NKError {
        let serverKeyError = await validateCurrentServerKey(account: account)
        guard serverKeyError == .success else {
            return serverKeyError
        }

        return await uploadMetadata(
            serverUrl: serverUrl,
            addUserId: nil,
            removeUserId: nil,
            updateVersionV1V2: false,
            mode: .initialCreation,
            account: account
        )
    }

    private func uploadMetadata(serverUrl: String,
                                addUserId: String?,
                                removeUserId: String?,
                                updateVersionV1V2: Bool,
                                mode: MetadataUploadMode,
                                account: String) async -> NKError {
        var addCertificate: String?
        var method = "POST"
        let session = NCSession.shared.getSession(account: account)
        let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
        guard let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB,
                           errorDescription: NSLocalizedString("_e2ee_no_dir_", comment: ""))
        }

        if let addUserId {
            let results = await NextcloudKit.shared.getE2EECertificateAsync(user: addUserId, account: session.account, options: NCNetworkingE2EE().getOptions(account: account, capabilities: capabilities)) {task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                path: addUserId,
                                                                                                name: "getE2EECertificate")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            if results.error == .success, let certificateUser = results.certificateUser {
                addCertificate = certificateUser
            } else {
                return results.error
            }
        }

        // LOCK
        //
        let resultsLock = await lock(account: session.account, serverUrl: serverUrl)
        guard resultsLock.error == .success, let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId else {
            return resultsLock.error
        }

        // METHOD + WRITE ACCESS
        //
        let resultsGetE2EEMetadata = await getMetadata(fileId: fileId, e2eToken: e2eToken, account: session.account)
        if resultsGetE2EEMetadata.error == .success,
           let e2eMetadata = resultsGetE2EEMetadata.e2eMetadata {
            let accessError = await validateMetadataWriteAccess(
                e2eMetadata: e2eMetadata,
                serverUrl: serverUrl,
                session: session
            )
            guard accessError == .success else {
                await unlock(account: session.account, serverUrl: serverUrl)
                return accessError
            }
            method = "PUT"
        } else if resultsGetE2EEMetadata.error.errorCode == NCGlobal.shared.errorResourceNotFound,
                  !updateVersionV1V2 {
            if case .updateOrRecover = mode {
                let storedAccess: NCEndToEndKeySetAccess
                do {
                    storedAccess = try await NCEndToEndMetadata().resolveStoredRootKeySetAccess(
                        serverUrl: serverUrl,
                        session: session
                    )
                } catch {
                    await unlock(account: session.account, serverUrl: serverUrl)
                    return NKError(
                        errorCode: NCGlobal.shared.errorInternalError,
                        errorDescription: error.localizedDescription
                    )
                }

                guard storedAccess.writeAccessError == .success else {
                    await unlock(account: session.account, serverUrl: serverUrl)
                    return storedAccess.writeAccessError
                }
            }
            method = "POST"
        } else {
            await unlock(account: session.account, serverUrl: serverUrl)
            return resultsGetE2EEMetadata.error == .success
                ? .invalidData
                : resultsGetE2EEMetadata.error
        }

        // UPLOAD METADATA
        //
        let uploadMetadataError = await uploadMetadata(serverUrl: serverUrl,
                                                       ocIdServerUrl: directory.ocId,
                                                       fileId: fileId,
                                                       e2eToken: e2eToken,
                                                       method: method,
                                                       addUserId: addUserId,
                                                       addCertificate: addCertificate,
                                                       removeUserId: removeUserId,
                                                       session: session)

        guard uploadMetadataError == .success else {
            await unlock(account: session.account, serverUrl: serverUrl)
            return uploadMetadataError
        }

        // UNLOCK
        //
        await unlock(account: session.account, serverUrl: serverUrl)

        return NKError()
    }

    func validateFolderWriteAccess(serverUrl: String, account: String) async -> NKError {
        let serverKeyError = await validateCurrentServerKey(account: account)
        guard serverKeyError == .success else {
            return serverKeyError
        }

        let session = NCSession.shared.getSession(account: account)
        let resultsLock = await lock(account: account, serverUrl: serverUrl)
        guard resultsLock.error == .success,
              let e2eToken = resultsLock.e2eToken,
              let fileId = resultsLock.fileId else {
            return resultsLock.error
        }

        let metadataResult = await getMetadata(fileId: fileId, e2eToken: e2eToken, account: account)
        let error: NKError
        if metadataResult.error == .success,
           let e2eMetadata = metadataResult.e2eMetadata {
            error = await validateMetadataWriteAccess(
                e2eMetadata: e2eMetadata,
                serverUrl: serverUrl,
                session: session
            )
        } else {
            error = metadataResult.error == .success
                ? .invalidData
                : metadataResult.error
        }

        await unlock(account: account, serverUrl: serverUrl)
        return error
    }

    private func validateMetadataWriteAccess(
        e2eMetadata: String,
        serverUrl: String,
        session: NCSession.Session
    ) async -> NKError {
        let access: NCEndToEndKeySetAccess
        do {
            access = try await NCEndToEndMetadata().resolveKeySetAccess(
                e2eMetadata,
                serverUrl: serverUrl,
                session: session
            )
        } catch {
            return NKError(
                errorCode: NCGlobal.shared.errorInternalError,
                errorDescription: error.localizedDescription
            )
        }

        let writeAccessError = access.writeAccessError
        nkLog(
            tag: NCGlobal.shared.logTagE2EE,
            message: "E2EE write access \(writeAccessError == .success ? "granted" : "denied") using the \(access.diagnosticDescription) key set."
        )
        return writeAccessError
    }

    func uploadMetadata(serverUrl: String,
                        ocIdServerUrl: String,
                        fileId: String,
                        e2eToken: String,
                        method: String,
                        addUserId: String? = nil,
                        addCertificate: String? = nil,
                        removeUserId: String? = nil,
                        session: NCSession.Session) async -> NKError {
        let resultsEncodeMetadata = await NCEndToEndMetadata().encodeMetadata(serverUrl: serverUrl, addUserId: addUserId, addCertificate: addCertificate, removeUserId: removeUserId, session: session)
        guard resultsEncodeMetadata.error == .success,
              let e2eMetadata = resultsEncodeMetadata.metadata else {
            // Client Diagnostic
            await self.database.addDiagnosticAsync(account: session.account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)
            return resultsEncodeMetadata.error
        }
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)

        let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadataAsync(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadata, signature: resultsEncodeMetadata.signature, method: method, account: session.account, options: NCNetworkingE2EE().getOptions(account: session.account, capabilities: capabilities)) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: session.account,
                                                                                            path: fileId,
                                                                                            name: "putE2EEMetadata")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        guard putE2EEMetadataResults.error == .success else {
            return putE2EEMetadataResults.error
        }

        // COUNTER
        //
        await self.database.updateCounterE2eMetadataAsync(account: session.account, ocIdServerUrl: ocIdServerUrl, counter: resultsEncodeMetadata.counter)

        return NKError()
    }

    // MARK: -

    func downloadMetadata(serverUrl: String,
                          fileId: String,
                          e2eToken: String,
                          session: NCSession.Session) async -> NKError {
        let resultsGetE2EEMetadata = await getMetadata(fileId: fileId, e2eToken: e2eToken, account: session.account)
        guard resultsGetE2EEMetadata.error == .success,
              let e2eMetadata = resultsGetE2EEMetadata.e2eMetadata else {
            if resultsGetE2EEMetadata.error.errorCode == NCGlobal.shared.errorResourceNotFound {
                do {
                    let storedAccess = try await NCEndToEndMetadata().resolveStoredRootKeySetAccess(
                        serverUrl: serverUrl,
                        session: session
                    )
                    guard storedAccess.writeAccessError == .success else {
                        return storedAccess.writeAccessError
                    }
                } catch {
                    return NKError(
                        errorCode: NCGlobal.shared.errorInternalError,
                        errorDescription: error.localizedDescription
                    )
                }
            }
            return resultsGetE2EEMetadata.error
        }

        let decodeResult = await NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: resultsGetE2EEMetadata.signature, serverUrl: serverUrl, session: session)
        guard decodeResult.error == .success else {
            // Client Diagnostic
            await self.database.addDiagnosticAsync(account: session.account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)
            return decodeResult.error
        }

        return decodeResult.access.writeAccessError
    }

    // MARK: -

    func lock(account: String,
              serverUrl: String) async -> (fileId: String?, e2eToken: String?, error: NKError) {
        var e2eToken: String?
        var e2eCounter = "1"
        guard let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return (nil, nil, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB,
                                      errorDescription: NSLocalizedString("_e2ee_no_dir_", comment: "")))
        }
        let capabilities = await NKCapabilities.shared.getCapabilities(for: account)

        if let tableLock = await self.database.getE2ETokenLockAsync(account: account, serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }

        if var counter = await self.database.getCounterE2eMetadataAsync(account: account, ocIdServerUrl: directory.ocId) {
            counter += 1
            e2eCounter = "\(counter)"
        }

        let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolderAsync(fileId: directory.fileId, e2eToken: e2eToken, e2eCounter: e2eCounter, method: "POST", account: account, options: NCNetworkingE2EE().getOptions(account: account, capabilities: capabilities)) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: directory.fileId,
                                                                                            name: "lockE2EEFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        if resultsLockE2EEFolder.error == .success, let e2eToken = resultsLockE2EEFolder.e2eToken {
            await self.database.setE2ETokenLockAsync(account: account, serverUrl: serverUrl, fileId: directory.fileId, e2eToken: e2eToken)
        }

        return (directory.fileId, resultsLockE2EEFolder.e2eToken, resultsLockE2EEFolder.error)
    }

    func unlock(account: String, serverUrl: String) async {
        guard let tableLock = await self.database.getE2ETokenLockAsync(account: account, serverUrl: serverUrl) else {
            return
        }
        let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
        let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolderAsync(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, e2eCounter: nil, method: "DELETE", account: account, options: NCNetworkingE2EE().getOptions(account: account, capabilities: capabilities)) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: tableLock.fileId,
                                                                                            name: "lockE2EEFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        if resultsLockE2EEFolder.error == .success {
            await self.database.deleteE2ETokenLockAsync(account: account, serverUrl: serverUrl)
        }

        return
    }

    func unlockAll(account: String) async {
        guard NCPreferences().isEndToEndEnabled(account: account) else { return }
        let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
        let results = await self.database.getE2EAllTokenLockAsync(account: account)
        for result in results {
            let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolderAsync(fileId: result.fileId, e2eToken: result.e2eToken, e2eCounter: nil, method: "DELETE", account: account, options: NCNetworkingE2EE().getOptions(account: account, capabilities: capabilities)) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                path: result.fileId,
                                                                                                name: "lockE2EEFolder")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            if resultsLockE2EEFolder.error == .success {
                await self.database.deleteE2ETokenLockAsync(account: account, serverUrl: result.serverUrl)
            }
        }
    }

    /// Extracts the validity dates from an X.509 certificate encoded in PEM format.
    ///
    /// - Parameter pemCertificate: The complete PEM certificate, including
    ///   `BEGIN CERTIFICATE` and `END CERTIFICATE` markers.
    /// - Returns: The certificate validity interval, or `nil` if the certificate
    ///   cannot be decoded.
    func getX509CertificateValidity(from pemCertificate: String) -> X509CertificateValidity? {
        let base64Certificate = pemCertificate
            .replacingOccurrences(
                of: "-----BEGIN CERTIFICATE-----",
                with: ""
            )
            .replacingOccurrences(
                of: "-----END CERTIFICATE-----",
                with: ""
            )
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()

        guard let certificateData = Data(base64Encoded: base64Certificate) else {
            return nil
        }

        var reader = ASN1Reader(data: certificateData)

        guard let certificateSequence = reader.readElement(expectedTag: 0x30) else {
            return nil
        }

        var certificateReader = ASN1Reader(data: certificateSequence)

        guard let tbsCertificateData = certificateReader.readElement(expectedTag: 0x30) else {
            return nil
        }

        var tbsReader = ASN1Reader(data: tbsCertificateData)

        // Optional explicit version field: [0] EXPLICIT Version.
        if tbsReader.peekTag() == 0xA0 {
            guard tbsReader.readElement() != nil else {
                return nil
            }
        }

        // serialNumber
        guard tbsReader.readElement(expectedTag: 0x02) != nil else {
            return nil
        }

        // signature
        guard tbsReader.readElement(expectedTag: 0x30) != nil else {
            return nil
        }

        // issuer
        guard tbsReader.readElement(expectedTag: 0x30) != nil else {
            return nil
        }

        // validity
        guard let validityData = tbsReader.readElement(expectedTag: 0x30) else {
            return nil
        }

        var validityReader = ASN1Reader(data: validityData)

        guard let notBefore = validityReader.readTime(),
              let notAfter = validityReader.readTime() else {
            return nil
        }

        return X509CertificateValidity(
            notBefore: notBefore,
            notAfter: notAfter
        )
    }

    private struct ASN1Reader {
        private let data: Data
        private var offset = 0

        init(data: Data) {
            self.data = data
        }

        mutating func peekTag() -> UInt8? {
            guard offset < data.count else {
                return nil
            }

            return data[offset]
        }

        mutating func readElement(
            expectedTag: UInt8? = nil
        ) -> Data? {
            guard offset < data.count else {
                return nil
            }

            let tag = data[offset]
            offset += 1

            if let expectedTag, tag != expectedTag {
                return nil
            }

            guard let length = readLength(),
                  length >= 0,
                  offset + length <= data.count else {
                return nil
            }

            let value = data.subdata(in: offset..<(offset + length))
            offset += length

            return value
        }

        mutating func readTime() -> Date? {
            guard let tag = peekTag(),
                  tag == 0x17 || tag == 0x18,
                  let value = readElement(expectedTag: tag),
                  let string = String(data: value, encoding: .ascii) else {
                return nil
            }

            switch tag {
            case 0x17:
                return Self.parseUTCTime(string)

            case 0x18:
                return Self.parseGeneralizedTime(string)

            default:
                return nil
            }
        }

        private mutating func readLength() -> Int? {
            guard offset < data.count else {
                return nil
            }

            let firstByte = data[offset]
            offset += 1

            if firstByte & 0x80 == 0 {
                return Int(firstByte)
            }

            let byteCount = Int(firstByte & 0x7F)

            guard byteCount > 0,
                  byteCount <= MemoryLayout<Int>.size,
                  offset + byteCount <= data.count else {
                return nil
            }

            var length = 0

            for _ in 0..<byteCount {
                guard length <= (Int.max >> 8) else {
                    return nil
                }

                length = (length << 8) | Int(data[offset])
                offset += 1
            }

            return length
        }

        private static func parseUTCTime(_ value: String) -> Date? {
            parseDate(
                value,
                formats: [
                    "yyMMddHHmmss'Z'",
                    "yyMMddHHmm'Z'"
                ]
            )
        }

        private static func parseGeneralizedTime(_ value: String) -> Date? {
            parseDate(
                value,
                formats: [
                    "yyyyMMddHHmmss'Z'",
                    "yyyyMMddHHmm'Z'"
                ]
            )
        }

        private static func parseDate(
            _ value: String,
            formats: [String]
        ) -> Date? {
            for format in formats {
                let formatter = DateFormatter()
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = format

                if let date = formatter.date(from: value) {
                    return date
                }
            }

            return nil
        }
    }

    /// Creates a new PKCS#10 certificate signing request using an existing
    /// RSA private key.
    ///
    /// The generated CSR preserves the existing key pair because the public key
    /// is derived directly from the supplied private key.
    ///
    /// - Parameters:
    ///   - privateKeyPEM: The existing private key encoded in PEM format.
    ///   - commonName: The certificate common name.
    ///   - country: The two-letter country code.
    ///   - state: The state or province.
    ///   - locality: The locality or city.
    ///   - organization: The organization name.
    /// - Returns: The PKCS#10 certificate signing request encoded in PEM format.
    func createCertificateSigningRequest(
        privateKeyPEM: String,
        commonName: String,
        country: String = "DE",
        state: String = "Baden-Wuerttemberg",
        locality: String = "Stuttgart",
        organization: String = "Nextcloud"
    ) throws -> String {
        let privateKeyBIO: OpaquePointer? = privateKeyPEM.withCString { pointer in
            BIO_new_mem_buf(
                pointer,
                Int32(privateKeyPEM.utf8.count)
            )
        }

        guard let privateKeyBIO else {
            throw E2EECSRError.invalidPrivateKey
        }

        defer {
            BIO_free(privateKeyBIO)
        }

        guard let privateKey = PEM_read_bio_PrivateKey(
            privateKeyBIO,
            nil,
            nil,
            nil
        ) else {
            throw E2EECSRError.invalidPrivateKey
        }

        defer {
            EVP_PKEY_free(privateKey)
        }

        guard let request = X509_REQ_new() else {
            throw E2EECSRError.unableToCreateRequest
        }

        defer {
            X509_REQ_free(request)
        }

        guard X509_REQ_set_version(request, 0) == 1,
              let subject = X509_REQ_get_subject_name(request) else {
            throw E2EECSRError.unableToCreateRequest
        }

        func addSubjectEntry(
            _ name: String,
            value: String
        ) -> Bool {
            name.withCString { namePointer in
                value.withCString { valuePointer in
                    X509_NAME_add_entry_by_txt(
                        subject,
                        namePointer,
                        MBSTRING_UTF8,
                        UnsafePointer<UInt8>(
                            OpaquePointer(valuePointer)
                        ),
                        -1,
                        -1,
                        0
                    ) == 1
                }
            }
        }

        guard addSubjectEntry("C", value: country),
              addSubjectEntry("ST", value: state),
              addSubjectEntry("L", value: locality),
              addSubjectEntry("O", value: organization),
              addSubjectEntry("CN", value: commonName) else {
            throw E2EECSRError.unableToSetSubject
        }

        guard X509_REQ_set_pubkey(request, privateKey) == 1 else {
            throw E2EECSRError.unableToSetPublicKey
        }

        guard X509_REQ_sign(
            request,
            privateKey,
            EVP_sha256()
        ) > 0 else {
            throw E2EECSRError.unableToSignRequest
        }

        guard let outputBIO = BIO_new(BIO_s_mem()) else {
            throw E2EECSRError.unableToEncodeRequest
        }

        defer {
            BIO_free(outputBIO)
        }

        guard PEM_write_bio_X509_REQ(outputBIO, request) == 1 else {
            throw E2EECSRError.unableToEncodeRequest
        }

        let length = BIO_ctrl_pending(outputBIO)

        guard length > 0 else {
            throw E2EECSRError.unableToEncodeRequest
        }

        var buffer = [UInt8](repeating: 0, count: Int(length))

        let bytesRead = BIO_read(
            outputBIO,
            &buffer,
            Int32(buffer.count)
        )

        guard bytesRead > 0,
              let csr = String(
                  bytes: buffer.prefix(Int(bytesRead)),
                  encoding: .utf8
              ) else {
            throw E2EECSRError.unableToEncodeRequest
        }

        return csr
    }
}
