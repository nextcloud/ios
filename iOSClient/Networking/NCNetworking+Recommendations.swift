// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

extension NCNetworking {
    func createRecommendations(session: NCSession.Session, serverUrl: String, collectionView: UICollectionView) async {
        let homeServer = self.utilityFileSystem.getHomeServer(urlBase: session.urlBase, userId: session.userId)
        guard homeServer == serverUrl else {
            return
        }

        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: session.account)
        var recommendationsToInsert: [NKRecommendation] = []
        let results = await NextcloudKit.shared.getRecommendedFilesAsync(account: session.account)
        var serverUrlFileName = ""

        if results.error == .success, let recommendations = results.recommendations {
            for recommendation in recommendations {
                if recommendation.directory.last == "/" {
                    serverUrlFileName = homeServer + recommendation.directory + recommendation.name
                } else {
                    serverUrlFileName = homeServer + recommendation.directory + "/" + recommendation.name
                }

                let results = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: showHiddenFiles, account: session.account)

                if results.error == .success, let file = results.files?.first {
                    let isDirectoryE2EE = self.utilityFileSystem.isDirectoryE2EE(file: file)
                    let metadata = self.database.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)
                    self.database.addMetadataIfNeeded(metadata, sync: false)

                    if metadata.isLivePhoto, metadata.isVideo {
                        continue
                    } else {
                        recommendationsToInsert.append(recommendation)
                    }
                }
            }
            self.database.createRecommendedFiles(account: session.account, recommendations: recommendationsToInsert, sync: false)

            await collectionView.reloadData()
        }
    }
}
