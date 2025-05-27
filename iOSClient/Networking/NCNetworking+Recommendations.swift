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

        var recommendationsToInsert: [NKRecommendation] = []
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        let results = await NextcloudKit.shared.getRecommendedFiles(account: session.account, options: options)
        var serverUrlFileName = ""

        if results.error == .success, let recommendations = results.recommendations {
            for recommendation in recommendations {
                if recommendation.directory.last == "/" {
                    serverUrlFileName = homeServer + recommendation.directory + recommendation.name
                } else {
                    serverUrlFileName = homeServer + recommendation.directory + "/" + recommendation.name
                }

                let result = await fileExists(serverUrlFileName: serverUrlFileName, account: session.account)

                if result.exists, let file = result.file {
                    let isDirectoryE2EE = self.utilityFileSystem.isDirectoryE2EE(file: file)
                    let metadata = self.database.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)
                    self.database.addMetadata(metadata, sync: false)

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
