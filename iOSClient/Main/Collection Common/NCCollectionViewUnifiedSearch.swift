// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import Queuer
import NextcloudKit
import RealmSwift

class NCCollectionViewUnifiedSearch: ConcurrentOperation, @unchecked Sendable {
    var collectionViewCommon: NCCollectionViewCommon
    var metadatas: [tableMetadata]
    var searchResult: NKSearchResult

    init(collectionViewCommon: NCCollectionViewCommon, metadatas: [tableMetadata], searchResult: NKSearchResult) {
        self.collectionViewCommon = collectionViewCommon
        self.metadatas = metadatas
        self.searchResult = searchResult
    }

    override func start() {
        guard !isCancelled else { return self.finish() }

        self.collectionViewCommon.dataSource.addSection(metadatas: metadatas, searchResult: searchResult)
        self.collectionViewCommon.searchResults?.append(self.searchResult)
        self.finish()

        Task {
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferReloadData(serverUrl: nil)
            }
        }
    }
}
