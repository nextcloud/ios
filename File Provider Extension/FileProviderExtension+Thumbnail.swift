// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import FileProvider
import NextcloudKit
import Alamofire

extension FileProviderExtension {
    override func fetchThumbnails(for itemIdentifiers: [NSFileProviderItemIdentifier], requestedSize size: CGSize, perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, Error?) -> Void, completionHandler: @escaping (Error?) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: Int64(itemIdentifiers.count))
        var counterProgress: Int64 = 0

        for itemIdentifier in itemIdentifiers {
            guard let metadata = providerUtility.getTableMetadataFromItemIdentifier(itemIdentifier),
                  metadata.hasPreview
            else {
                counterProgress += 1
                if counterProgress == progress.totalUnitCount {
                    completionHandler(nil)
                }
                continue
            }

            NextcloudKit.shared.downloadPreview(fileId: metadata.fileId,
                                                width: Int(NCGlobal.shared.size512.width),
                                                height: Int(NCGlobal.shared.size512.height),
                                                etag: metadata.etag,
                                                account: metadata.account) { _ in
            } completion: { _, _, _, _, responseData, error in
                if error == .success, let data = responseData?.data {
                    perThumbnailCompletionHandler(itemIdentifier, data, nil)
                } else {
                    perThumbnailCompletionHandler(itemIdentifier, nil, NSFileProviderError(.serverUnreachable))
                }
                counterProgress += 1
                if counterProgress == progress.totalUnitCount {
                    completionHandler(nil)
                }
            }
        }

        return progress
    }
}
