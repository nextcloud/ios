// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import Alamofire
import NextcloudKit

extension NCNetworking {
    func createRecommendations(account: String) async {
        guard let tblAccount = NCManageDatabase.shared.getTableAccount(account: account) else {
            return
        }
        let homeServer = self.utilityFileSystem.getHomeServer(urlBase: tblAccount.urlBase, userId: tblAccount.userId)
        var recommendationsToInsert: [NKRecommendation] = []
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let results = await NCNetworking.shared.getRecommendedFiles(account: account, options: options)
        if results.error == .success,
           let recommendations = results.recommendations {
            for recommendation in recommendations {
                var metadata = database.getResultMetadataFromFileId(recommendation.id)
                var serverUrlFileName = ""

                if metadata == nil || metadata?.fileName != recommendation.name {
                    if recommendation.directory.last == "/" {
                        serverUrlFileName = homeServer + recommendation.directory + recommendation.name
                    } else {
                        serverUrlFileName = homeServer + recommendation.directory + "/" + recommendation.name
                    }
                    let results = await NCNetworking.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: NCKeychain().showHiddenFiles, account: account)

                    if results.error == .success, let file = results.files?.first {
                        let isDirectoryE2EE = self.utilityFileSystem.isDirectoryE2EE(file: file)
                        let metadataConverted = self.database.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)
                        metadata = metadataConverted

                        self.database.addMetadata(metadataConverted)
                        recommendationsToInsert.append(recommendation)
                    }
                } else {
                    recommendationsToInsert.append(recommendation)
                }
            }
            self.database.createRecommendedFiles(account: account, recommendations: recommendationsToInsert)

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadRecommendedFiles, userInfo: nil)
        }
    }
}
