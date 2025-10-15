// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

extension NCNetworking {
    func createRecommendations(session: NCSession.Session, serverUrl: String, collectionView: UICollectionView) async {
        let home = self.utilityFileSystem.getHomeServer(urlBase: session.urlBase, userId: session.userId)
        guard home == serverUrl else {
            return
        }

        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: session.account)
        var recommendationsToInsert: [NKRecommendation] = []
        let results = await NextcloudKit.shared.getRecommendedFilesAsync(account: session.account, taskHandler: { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: session.account,
                                                                                            name: "getRecommendedFiles")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        })
        var serverUrlFileName = ""

        if results.error == .success, let recommendations = results.recommendations {
            for recommendation in recommendations {
                serverUrlFileName = self.utilityFileSystem.createServerUrl(serverUrl: home + recommendation.directory, fileName: recommendation.name)

                let results = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: showHiddenFiles, account: session.account) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: session.account,
                                                                                                    path: serverUrlFileName,
                                                                                                    name: "readFileOrFolder")
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                }

                if results.error == .success, let file = results.files?.first {
                    let metadata = await NCManageDatabase.shared.convertFileToMetadataAsync(file)
                    await NCManageDatabase.shared.addMetadataIfNotExistsAsync(metadata)

                    if metadata.isLivePhoto, metadata.isVideo {
                        continue
                    } else {
                        recommendationsToInsert.append(recommendation)
                    }
                }
            }

            await NCManageDatabase.shared.createRecommendedFilesAsync(account: session.account, recommendations: recommendationsToInsert)
            await collectionView.reloadData()
        }
    }
}
