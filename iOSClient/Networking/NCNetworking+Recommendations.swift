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
        let results = await NextcloudKit.shared.getRecommendedFilesAsync(account: session.account)
        var serverUrlFileName = ""

        if results.error == .success, let recommendations = results.recommendations {
            for recommendation in recommendations {
                serverUrlFileName = self.utilityFileSystem.createServerUrl(serverUrl: home + recommendation.directory, fileName: recommendation.name)

                let results = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: showHiddenFiles, account: session.account)

                if results.error == .success, let file = results.files?.first {
                    let metadata = await self.database.convertFileToMetadataAsync(file)
                    self.database.addMetadataIfNeededAsync(metadata, sync: false)

                    if metadata.isLivePhoto, metadata.isVideo {
                        continue
                    } else {
                        recommendationsToInsert.append(recommendation)
                    }
                }
            }

            await self.database.createRecommendedFilesAsync(account: session.account, recommendations: recommendationsToInsert)
            await collectionView.reloadData()
        }
    }
}
