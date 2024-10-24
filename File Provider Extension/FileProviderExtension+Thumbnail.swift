//
//  FileProviderExtension+Thumbnail.swift
//  PickerFileProvider
//
//  Created by Marino Faggiana on 28/05/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import FileProvider
import NextcloudKit
import Alamofire

extension FileProviderExtension {
    override func fetchThumbnails(for itemIdentifiers: [NSFileProviderItemIdentifier], requestedSize size: CGSize, perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, Error?) -> Void, completionHandler: @escaping (Error?) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: Int64(itemIdentifiers.count))
        var counterProgress: Int64 = 0

        for itemIdentifier in itemIdentifiers {
            guard let metadata = providerUtility.getTableMetadataFromItemIdentifier(itemIdentifier), metadata.hasPreview else {
                counterProgress += 1
                if counterProgress == progress.totalUnitCount { completionHandler(nil) }
                continue
            }

            NextcloudKit.shared.downloadPreview(fileId: metadata.fileId,
                                                width: Int(size.width),
                                                height: Int(size.height),
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
