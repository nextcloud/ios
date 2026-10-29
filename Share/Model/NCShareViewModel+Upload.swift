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
    func actionUpload(capabilities: NKCapabilities.Capabilities) {
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
                if !isClosing { showAlert(description: error.localizedDescription) }
            }
        }
    }

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
                if !isClosing { showAlert(description: error.localizedDescription) }
            }
        }
    }

    private func prepareUploadPlan(capabilities: NKCapabilities.Capabilities) async throws -> NCShareUploadConfirmation {
        let session = sessionStore.getSession()
        let destination = serverUrl
        let sourceNames = filesName
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
        guard !isClosing, sessionStore.getSession().account == session.account, serverUrl == destination else { throw CancellationError() }
        let converter = NCManageDatabaseCreateMetadata()
        var listing = await converter.convertFilesToMetadatasAsync(files, serverUrlMetadataFolder: destination)
        guard !listing.metadataFolder.ocId.isEmpty else {
            throw NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_share_conflict_read_failed_", comment: ""))
        }
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
        metadataFolder = listing.metadataFolder
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

    private func stageAndUpload(plan: NCShareUploadConfirmation, replacing: Bool, capabilities: NKCapabilities.Capabilities) async throws {
        try Task.checkCancellation()
        let session = sessionStore.getSession()
        guard !isClosing, isAuthenticated, plan.account == session.account, plan.serverUrl == serverUrl else { throw CancellationError() }
        uploadMetadata.removeAll()
        replacementETags.removeAll()
        counterUploaded = 0
        var stagedDirectories: [String] = []
        var staged = false
        defer {
            if !staged {
                for directory in stagedDirectories { try? FileManager.default.removeItem(atPath: directory) }
                uploadMetadata.removeAll()
                replacementETags.removeAll()
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
                fileName: fileName, ocId: ocId, serverUrl: plan.serverUrl, session: session, sceneIdentifier: sceneIdentifier)
            metadata.nativeFormat = true
            metadata.session = NCNetworking.shared.sessionUpload
            metadata.sessionSelector = NCGlobal.shared.selectorUploadFileShareExtension
            metadata.size = utilityFileSystem.getFileSize(filePath: path)
            metadata.status = NCGlobal.shared.metadataStatusWaitUpload
            metadata.sessionDate = Date()
            uploadMetadata.append(metadata)
            if replacing, let etag = plan.replacementETag {
                replacementETags[ocId] = etag.hasPrefix("\"") || etag.hasPrefix("W/") ? etag : "\"" + etag + "\""
            }
        }
        try Task.checkCancellation()
        guard !isClosing, isAuthenticated, sessionStore.getSession().account == plan.account, serverUrl == plan.serverUrl else { throw CancellationError() }
        staged = true
        await uploadAndExit()
    }

    @MainActor
    func uploadAndExit() async {
        // A Share extension process can be reused by the system. Treat each
        // explicit share operation as a new server-key validation cycle.
        await NCNetworkingE2EE.beginNewServerKeyValidationCycle()

        var error: NKError?
        guard let window = presenter?.view.window else {
            return
        }
        let payload = LucidBannerPayload(stage: .button,
                                         vPosition: .center,
                                         blocksTouches: true)
        (banner, token) = showUploadBanner(windowScene: window.windowScene,
                                           payload: payload,
                                           allowMinimizeOnTap: false,
                                           onButtonTap: {
            self.cancel()
        })

        for metadata in self.uploadMetadata {
            guard !Task.isCancelled, !isClosing else { return }
            // BANNER
            let payloadUpdate = LucidBannerPayload.Update(
                title: NSLocalizedString("_upload_file_", comment: "") + " \(self.counterUploaded + 1) " + NSLocalizedString("_of_", comment: "") + " \(self.filesName.count)",
                systemImage: "arrowshape.up.circle",
                imageAnimation: .breathe,
                progress: 0)
            banner?.update(payload: payloadUpdate)

            error = await self.upload(metadata: metadata)
            if error != .success {
                break
            }
        }

        if error == .success {
            recordRecentDestination()
            banner?.update(payload: LucidBannerPayload.Update(stage: .success, horizontalLayout: .centered(width: 100)), for: self.token)
        } else {
            banner?.update(payload: LucidBannerPayload.Update(subtitle: error?.errorDescription, stage: .error), for: self.token)
        }

        guard !Task.isCancelled, !isClosing else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            banner?.dismiss()
            cancel()
        }
    }

    @MainActor
    func upload(metadata: tableMetadata) async -> NKError? {
        let session = sessionStore.getSession()
        var error: NKError = .success

        let results = await NKTypeIdentifiers.shared.getInternalType(fileName: metadata.fileNameView, mimeType: metadata.contentType, directory: false, account: session.account)
        metadata.contentType = results.mimeType
        metadata.iconName = results.iconName
        metadata.classFile = results.classFile
        metadata.typeIdentifier = results.typeIdentifier
        metadata.serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)

        // CHUNK
        if metadata.size > self.global.chunkSize {
            metadata.chunk = self.global.chunkSize
        } else {
            metadata.chunk = 0
        }
        // E2EE
        metadata.e2eEncrypted = metadata.isDirectoryE2EE

        self.counterUploaded += 1

        if metadata.isDirectoryE2EE {
            error = await NCNetworkingE2EEUpload().upload(metadata: metadata,
                                                          session: session,
                                                          controller: presenter,
                                                          banner: banner,
                                                          stageBanner: nil,
                                                          tokenBanner: self.token)
        } else if metadata.chunk > 0 {
            banner?.update(payload: LucidBannerPayload.Update(systemImage: "gearshape.arrow.triangle.2.circlepath",
                                                              imageAnimation: .rotate),
                                      for: self.token)
            let task = Task { () -> (account: String, file: NKFile?, error: NKError) in
                let results = await NCNetworking.shared.uploadChunkFile(
                    metadata: metadata,
                    overwrite: self.replacementETags[metadata.ocId] != nil,
                    ifMatch: self.replacementETags[metadata.ocId]) { total, counter in
                    Task {@MainActor in
                        self.banner?.update(payload: LucidBannerPayload.Update(progress: Double(counter) / Double(total)), for: self.token)
                    }
                } uploadStart: { _ in
                    Task {@MainActor in
                        let payload = LucidBannerPayload.Update(
                            systemImage: "arrowshape.up.circle",
                            imageAnimation: .breathe
                        )
                        self.banner?.update(payload: payload, for: self.token)
                    }
                } uploadProgressHandler: { _, _, progress in
                    Task {@MainActor in
                        self.banner?.update(payload: LucidBannerPayload.Update(progress: progress), for: self.token)
                    }
                } assembling: {
                    Task {@MainActor in
                        let payload = LucidBannerPayload.Update(
                            systemImage: "gearshape.arrow.triangle.2.circlepath",
                            imageAnimation: .rotate
                        )
                        self.banner?.update(payload: payload, for: self.token)
                    }
                }

                return results
            }

            let results = await task.value
            error = results.error
        } else {
            let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                      fileName: metadata.fileName,
                                                                                      userId: metadata.userId,
                                                                                      urlBase: metadata.urlBase)

            let results = await NCNetworking.shared.uploadFile(account: metadata.account,
                                                               fileNameLocalPath: fileNameLocalPath,
                                                               serverUrlFileName: metadata.serverUrlFileName,
                                                               creationDate: metadata.creationDate as Date,
                                                               dateModificationFile: metadata.date as Date,
                                                               customHeaders: replacementETags[metadata.ocId].map { ["If-Match": $0] } ?? ["If-None-Match": "*"]) { _ in
            } progressHandler: { _, _, fractionCompleted in
                Task {@MainActor in
                    self.banner?.update(payload: LucidBannerPayload.Update(progress: fractionCompleted),
                                        for: self.token)
                }
            }
            error = results.error
        }

        return error
    }
}
#endif

/// Reserves the entire batch before allocating copies, so an earlier conflict
/// cannot consume the unchanged name of a later attachment.
struct NCShareUploadNamePlanner {
    static func fileNames(for names: [String], existingNames: Set<String>) -> [String] {
        var occupied = existingNames
        var reserved = Set(names)
        var assigned: Set<String> = []
        return names.map { name in
            if !occupied.contains(name), !assigned.contains(name) {
                assigned.insert(name)
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
            reserved.insert(candidate)
            assigned.insert(candidate)
            return candidate
        }
    }
}
