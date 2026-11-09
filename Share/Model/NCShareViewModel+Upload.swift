// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// The unit-test target compiles only the pure name planner below.
#if EXTENSION_SHARE || SHARE_PREVIEWS
import UIKit
import NextcloudKit
import LucidBanner

// MARK: - Upload
extension NCShareViewModel {
    /// Upload flow: inspect the destination, resolve name conflicts if needed,
    /// stage local copies, then transfer. Keep editing disabled throughout this flow.
    func upload() {
        guard isUploadDestinationReady, isAuthenticated, !isPreparingInput, inputErrorMessage.isEmpty, !isPreparingUpload,
              !isSwitchingAccount, !isLoadingAccounts, !isLoading, !fileNames.isEmpty else { return }
        guard let capabilities = serverCapabilities else { return }
        isPreparingUpload = true
        uploadTask = Task { @MainActor in
            defer { if pendingUploadConfirmation == nil { isPreparingUpload = false } }
            do {
                let plan = try await prepareUploadPlan(capabilities: capabilities)
                try Task.checkCancellation()
                guard !isClosing, isAuthenticated else { return }
                if plan.requiresConfirmation {
                    pendingUploadConfirmation = plan
                    uploadConfirmation = plan
                } else {
                    try await stageAndUpload(plan: plan, replacing: false, capabilities: capabilities)
                }
            } catch is CancellationError {
                // The extension was closed; do not present another screen.
            } catch {
                if !Task.isCancelled, !isClosing { showAlert(description: error.localizedDescription) }
            }
        }
    }

    // Store the choice and dismiss the sheet first. Starting the transfer here
    // would overlap sheet dismissal with the upload banner presentation.
    func resolveUploadConfirmation(_ choice: NCShareUploadChoice?) {
        guard pendingUploadConfirmation != nil else { return }
        uploadChoice = choice
        uploadConfirmation = nil
    }

    func uploadConfirmationDismissed() {
        guard let plan = pendingUploadConfirmation else { return }
        let choice = uploadChoice
        pendingUploadConfirmation = nil
        uploadChoice = nil
        guard let choice, let capabilities = serverCapabilities, isAuthenticated, !isClosing else {
            isPreparingUpload = false
            return
        }
        uploadTask = Task { @MainActor in
            defer { isPreparingUpload = false }
            do {
                try await stageAndUpload(plan: plan, replacing: choice == .replace, capabilities: capabilities)
            } catch is CancellationError {
                // No upload after cancellation or a destination change.
            } catch {
                if !Task.isCancelled, !isClosing { showAlert(description: error.localizedDescription) }
            }
        }
    }

    /// Builds a plan from a fresh server listing without renaming the input files.
    /// Multiple files receive unique copy names; a single file may also be replaced
    /// when the existing resource is a file with a usable ETag.
    private func prepareUploadPlan(capabilities: NKCapabilities.Capabilities) async throws -> NCShareUploadConfirmation {
        let session = sessionStore.getSession()
        guard let destination = selectedFolder?.serverUrl else { throw CancellationError() }
        let sourceNames = fileNames
        guard !sourceNames.isEmpty else { throw NCShareRequestError.noFiles }
        let renamer = FileAutoRenamer(capabilities: capabilities)
        let requestedNames = try sourceNames.map { name in
            let candidate = renamer.rename(filename: name).trimmingCharacters(in: .whitespacesAndNewlines)
            if let error = FileNameValidator.checkFileName(candidate, account: session.account, capabilities: capabilities) {
                throw NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: name + ": " + error.errorDescription)
            }
            return candidate
        }

        // Read the server, not the browser cache. Hidden files also reserve names.
        let result = await NextcloudKit.shared.readFileOrFolderAsync(
            serverUrlFileName: destination, depth: "1", showHiddenFiles: true, account: session.account)
        try Task.checkCancellation()
        guard result.error == .success else { throw result.error }
        guard let files = result.files else {
            throw NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_share_conflict_read_failed_", comment: ""))
        }
        guard !isClosing, sessionStore.getSession().account == session.account, selectedFolder?.serverUrl == destination else { throw CancellationError() }
        let converter = NCManageDatabaseCreateMetadata()
        var listing = await converter.convertFilesToMetadatasAsync(files, serverUrlMetadataFolder: destination)
        guard !listing.metadataFolder.ocId.isEmpty else {
            throw NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_share_conflict_read_failed_", comment: ""))
        }
        // Encrypted server names cannot be compared with the user-visible names.
        // Decode the mapping and verify write access before allocating upload names.
        if listing.metadataFolder.e2eEncrypted {
            let networking = NCNetworkingE2EE()
            await NCNetworkingE2EE.beginNewServerKeyValidationCycle()
            let keyError = await networking.validateCurrentServerKey(account: session.account)
            guard keyError == .success else { throw keyError }
            let encrypted = await networking.getMetadata(fileId: listing.metadataFolder.ocId, e2eToken: nil, account: session.account)
            if encrypted.error == .success, let metadata = encrypted.e2eMetadata {
                let decoded = await NCEndToEndMetadata().decodeMetadata(metadata, signature: encrypted.signature, serverUrl: destination, session: session)
                guard decoded.error == .success else { throw decoded.error }
                guard decoded.access.writeAccessError == .success else { throw decoded.access.writeAccessError }
                listing = await converter.convertFilesToMetadatasAsync(files, serverUrlMetadataFolder: destination)
            } else if encrypted.error == .success {
                throw NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_share_conflict_read_failed_", comment: ""))
            } else if encrypted.error.errorCode != NCGlobal.shared.errorResourceNotFound || !listing.metadatas.isEmpty {
                throw encrypted.error
            }
            guard !listing.metadatas.contains(where: { $0.fileNameView == NSLocalizedString("_e2e_file_encrypted_", comment: "") }) else {
                throw NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_share_conflict_read_failed_", comment: ""))
            }
        }
        try Task.checkCancellation()
        // Retain the current encrypted-name mapping for the shared E2EE service.
        await NCManageDatabase.shared.createDirectory(metadata: listing.metadataFolder)
        await NCManageDatabase.shared.updateMetadatasFilesAsync(listing.metadatas, serverUrl: destination, account: session.account)
        let names = Set(listing.metadatas.map(\.fileNameView))
        let allocated = NCShareUploadNamePlanner.fileNames(for: requestedNames, existingNames: names)
        let items = zip(sourceNames, allocated).map { NCShareUploadItem(sourceName: $0.0, fileName: $0.1) }
        let existing = requestedNames.count == 1 ? listing.metadatas.first(where: { $0.fileNameView == requestedNames[0] }) : nil
        let canReplace = existing.map { !$0.directory && !$0.etag.isEmpty && !$0.etag.hasPrefix("W/") } ?? false
        return NCShareUploadConfirmation(
            account: session.account, serverUrl: destination, items: items,
            replacementFileName: canReplace ? existing?.fileNameView : nil,
            replacementETag: canReplace ? existing?.etag : nil,
            requiresConfirmation: allocated != requestedNames)
    }

    /// Copies inputs into the storage expected by the upload services. If staging
    /// fails, remove those copies; retain the originals so the user can retry.
    private func stageAndUpload(plan: NCShareUploadConfirmation, replacing: Bool, capabilities: NKCapabilities.Capabilities) async throws {
        try Task.checkCancellation()
        guard !isOffline else { throw URLError(.notConnectedToInternet) }
        let session = sessionStore.getSession()
        guard !isClosing, isAuthenticated, plan.account == session.account, plan.serverUrl == selectedFolder?.serverUrl else { throw CancellationError() }
        var uploadMetadata: [tableMetadata] = []
        let replacementETag: String?
        if replacing, let etag = plan.replacementETag {
            replacementETag = etag.hasPrefix("\"") || etag.hasPrefix("W/") ? etag : "\"" + etag + "\""
        } else {
            replacementETag = nil
        }
        var stagedDirectories: [String] = []
        var staged = false
        defer {
            if !staged {
                for directory in stagedDirectories { try? FileManager.default.removeItem(atPath: directory) }
            }
        }
        for item in plan.items {
            try Task.checkCancellation()
            let fileName = replacing ? (plan.replacementFileName ?? item.fileName) : item.fileName
            if let error = FileNameValidator.checkFileName(fileName, account: session.account, capabilities: capabilities) {
                throw NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: fileName + ": " + error.errorDescription)
            }
            let ocId = UUID().uuidString
            let directory = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, userId: session.userId, urlBase: session.urlBase)
            stagedDirectories.append(directory)
            let path = URL(fileURLWithPath: directory).appendingPathComponent(fileName).path
            try FileManager.default.copyItem(at: inputFileURL(named: item.sourceName), to: URL(fileURLWithPath: path))
            let metadata = await NCManageDatabaseCreateMetadata().createMetadataAsync(
                fileName: fileName, ocId: ocId, serverUrl: plan.serverUrl, session: session, sceneIdentifier: nil)
            metadata.nativeFormat = true
            metadata.session = NCNetworking.shared.sessionUpload
            metadata.sessionSelector = NCGlobal.shared.selectorUploadFileShareExtension
            metadata.size = utilityFileSystem.getFileSize(filePath: path)
            metadata.status = NCGlobal.shared.metadataStatusWaitUpload
            metadata.sessionDate = Date()
            uploadMetadata.append(metadata)
        }
        try Task.checkCancellation()
        guard !isClosing, isAuthenticated, sessionStore.getSession().account == plan.account, selectedFolder?.serverUrl == plan.serverUrl else { throw CancellationError() }
        staged = true
        await uploadAndExit(uploadMetadata, replacementETag: replacementETag)
    }

    private func uploadAndExit(_ uploadMetadata: [tableMetadata], replacementETag: String?) async {
        // A Share extension process can be reused by the system. Treat each
        // explicit share operation as a new server-key validation cycle.
        await NCNetworkingE2EE.beginNewServerKeyValidationCycle()

        var error: NKError?
        var errorContext: NCErrorContext = .generic
        guard !Task.isCancelled, !isClosing, let window = presenter?.view.window else {
            return
        }
        let payload = LucidBannerPayload(stage: .button,
                                         vPosition: .center,
                                         blocksTouches: true)
        let (uploadBanner, token) = showUploadBanner(windowScene: window.windowScene,
                                                    payload: payload,
                                                    allowMinimizeOnTap: false,
                                                    onButtonTap: { self.cancel() })
        banner = uploadBanner

        for (index, metadata) in uploadMetadata.enumerated() {
            guard !Task.isCancelled, !isClosing else { return }
            // BANNER
            let payloadUpdate = LucidBannerPayload.Update(
                title: NSLocalizedString("_upload_file_", comment: "") + " \(index + 1) " + NSLocalizedString("_of_", comment: "") + " \(uploadMetadata.count)",
                systemImage: "arrowshape.up.circle",
                imageAnimation: .breathe,
                progress: 0)
            banner?.update(payload: payloadUpdate)

            error = await self.upload(metadata: metadata, replacementETag: replacementETag, token: token)
            guard !Task.isCancelled, !isClosing else { return }
            if error != .success {
                errorContext = .upload(fileName: NCShareFilenameView.displayName(metadata.fileNameView))
                break
            }
        }

        if error == .success {
            if let uploaded = uploadMetadata.first, let folder = selectedFolder,
               uploaded.serverUrl == folder.serverUrl {
                recentFoldersStore.record(.init(
                    serverUrl: folder.serverUrl, name: folder.name, ocId: folder.ocId, isEncrypted: folder.isEncrypted),
                    account: uploaded.account)
            }
            banner?.update(payload: LucidBannerPayload.Update(stage: .success, horizontalLayout: .centered(width: 100)), for: token)
        } else {
            let payload = LucidBannerPayload.Update(
                title: errorContext.failureTitle ?? NSLocalizedString("_error_", comment: ""),
                subtitle: error?.userFriendlyMessage(for: errorContext) ?? "", stage: .error)
            banner?.update(payload: payload, for: token)
        }

        guard !Task.isCancelled, !isClosing else { return }
        do {
            try await Task.sleep(for: .seconds(2))
        } catch {
            return
        }
        guard !isClosing else { return }
        banner?.dismiss()
        cancel()
    }

    private func upload(metadata: tableMetadata, replacementETag: String?, token: Int?) async -> NKError {
        let session = sessionStore.getSession()

        let results = await NKTypeIdentifiers.shared.getInternalType(fileName: metadata.fileNameView, mimeType: metadata.contentType, directory: false, account: session.account)
        guard !Task.isCancelled, !isClosing else {
            return NKError(errorCode: NSURLErrorCancelled, errorDescription: "Transfer was cancelled.")
        }
        metadata.contentType = results.mimeType
        metadata.iconName = results.iconName
        metadata.classFile = results.classFile
        metadata.typeIdentifier = results.typeIdentifier
        metadata.serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)

        let chunkSize = NCGlobal.shared.chunkSize
        metadata.chunk = metadata.size > chunkSize ? chunkSize : 0
        // E2EE
        metadata.e2eEncrypted = metadata.isDirectoryE2EE

        if metadata.isDirectoryE2EE {
            return await NCNetworkingE2EEUpload().upload(metadata: metadata,
                                                          session: session,
                                                          controller: presenter,
                                                          banner: banner,
                                                          stageBanner: nil,
                                                          tokenBanner: token)
        } else if metadata.chunk > 0 {
            banner?.update(payload: LucidBannerPayload.Update(systemImage: "gearshape.arrow.triangle.2.circlepath",
                                                              imageAnimation: .rotate),
                                      for: token)
            // Await directly so cancellation belongs to the main upload task.
            // Final MOVE must not overwrite a file created after conflict checking,
            // unless the user chose replacement and its ETag still matches.
            let results = await NCNetworking.shared.uploadChunkFile(
                metadata: metadata,
                overwrite: replacementETag != nil,
                ifMatch: replacementETag) { total, counter in
                Task {@MainActor in
                    self.banner?.update(payload: LucidBannerPayload.Update(progress: Double(counter) / Double(total)), for: token)
                }
            } uploadStart: { _ in
                Task {@MainActor in
                    let payload = LucidBannerPayload.Update(
                        systemImage: "arrowshape.up.circle",
                        imageAnimation: .breathe
                    )
                    self.banner?.update(payload: payload, for: token)
                }
            } uploadProgressHandler: { _, _, progress in
                Task {@MainActor in
                    self.banner?.update(payload: LucidBannerPayload.Update(progress: progress), for: token)
                }
            } assembling: {
                Task {@MainActor in
                    let payload = LucidBannerPayload.Update(
                        systemImage: "gearshape.arrow.triangle.2.circlepath",
                        imageAnimation: .rotate
                    )
                    self.banner?.update(payload: payload, for: token)
                }
            }
            return results.error
        } else {
            let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                      fileName: metadata.fileName,
                                                                                      userId: metadata.userId,
                                                                                      urlBase: metadata.urlBase)

            // The server enforces the final decision: a free name must still be
            // free, and a replacement must still match the ETag we inspected.
            let results = await NCNetworking.shared.uploadFile(account: metadata.account,
                                                               fileNameLocalPath: fileNameLocalPath,
                                                               serverUrlFileName: metadata.serverUrlFileName,
                                                               creationDate: metadata.creationDate as Date,
                                                               dateModificationFile: metadata.date as Date,
                                                               customHeaders: replacementETag.map { ["If-Match": $0] } ?? ["If-None-Match": "*"],
                                                               progressHandler: { _, _, fractionCompleted in
                Task {@MainActor in
                    self.banner?.update(payload: LucidBannerPayload.Update(progress: fractionCompleted),
                                        for: token)
                }
            })
            return results.error
        }

    }
}
#endif

/// Reserves the entire batch before allocating copies, so an earlier conflict
/// cannot consume the unchanged name of a later attachment.
struct NCShareUploadNamePlanner {
    static func fileNames(for names: [String], existingNames: Set<String>) -> [String] {
        var occupied = existingNames
        let reserved = Set(names)
        return names.map { name in
            if !occupied.contains(name) {
                occupied.insert(name)
                return name
            }
            let filename = name as NSString
            let ext = filename.pathExtension
            var stem = ext.isEmpty ? name : filename.deletingPathExtension
            var number = 1
            if let range = stem.range(of: #" \([0-9]+\)$"#, options: .regularExpression),
               let value = Int(stem[range].dropFirst(2).dropLast()), value > 0, value < Int.max / 2 {
                number = value + 1
                stem = String(stem[..<range.lowerBound])
            }
            let suffix = ext.isEmpty ? "" : "." + ext
            var candidate = stem + " (\(number))" + suffix
            while occupied.contains(candidate) || reserved.contains(candidate) {
                number += 1
                candidate = stem + " (\(number))" + suffix
            }
            occupied.insert(candidate)
            return candidate
        }
    }
}
