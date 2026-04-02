// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import LucidBanner

@MainActor
class NCNetworkingE2EEMarkFolder: NSObject {
    let database = NCManageDatabase.shared

    func markFolderE2ee(account: String, serverUrlFileName: String, userId: String, sceneIdentifier: String?) async -> NKError {
        var banner: LucidBanner?
        var token: Int?
        var error = NKError()

        defer {
            if let banner, let token {
                if error == .success {
                    completeHudIndeterminateBannerSuccess(token: token, banner: banner)
                } else {
                    banner.dismiss()
                }
            }
        }

        // BANNER
        //
#if !EXTENSION
        if let sceneIdentifier,
           let windowScene = SceneManager.shared.getWindow(sceneIdentifier: sceneIdentifier)?.windowScene {
            (banner, token) = showHudIndeterminateBanner(windowScene: windowScene, title: "_e2ee_encrypt_folder_")
        }
#endif

        let resultsReadFileOrFolder = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName, depth: "0", account: account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "readFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        guard resultsReadFileOrFolder.error == .success,
              var file = resultsReadFileOrFolder.files?.first else {
            error = resultsReadFileOrFolder.error
            return error
        }
        let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
        let resultsMarkE2EEFolder = await NextcloudKit.shared.markE2EEFolderAsync(fileId: file.fileId, delete: false, account: account, options: NCNetworkingE2EE().getOptions(account: account, capabilities: capabilities)) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: file.fileId,
                                                                                            name: "markE2EEFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        guard resultsMarkE2EEFolder.error == .success else {
            error = resultsMarkE2EEFolder.error
            return error
        }

        file.e2eEncrypted = true

        let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)
        await self.database.createDirectory(metadata: metadata)

        await self.database.deleteE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, serverUrlFileName))
        await self.database.updateCounterE2eMetadataAsync(account: account, ocIdServerUrl: metadata.ocId, counter: 0)

        // upload e2ee metadata
        error = await NCNetworkingE2EE().uploadMetadata(serverUrl: serverUrlFileName, account: account)
        guard error == .success else {
            return error
        }

        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(status: NCGlobal.shared.networkingStatusCreateFolder,
                                    account: metadata.account,
                                    fileName: metadata.fileName,
                                    serverUrl: metadata.serverUrl,
                                    selector: metadata.sessionSelector,
                                    ocId: metadata.ocId,
                                    destination: nil,
                                    error: .success)
        }

        return error
    }
}
