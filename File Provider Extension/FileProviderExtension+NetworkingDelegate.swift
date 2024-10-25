//
//  FileProviderExtension+x.swift
//  File Provider Extension
//
//  Created by Marino Faggiana on 11/07/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

import Foundation
import UIKit
import UniformTypeIdentifiers
import FileProvider
import NextcloudKit
import Alamofire

extension FileProviderExtension: NCNetworkingDelegate {
    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: Date?, dateLastModified: Date?, length: Int64, task: URLSessionTask, error: NKError) { }
    func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) { }
    func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) { }

    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: Date?, size: Int64, task: URLSessionTask, error: NKError) {
        guard let url = task.currentRequest?.url,
              let metadata = NCManageDatabase.shared.getMetadata(from: url, sessionTaskIdentifier: task.taskIdentifier) else { return }

        if let ocId, !metadata.ocIdTransfer.isEmpty {
            let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer)
            let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId)
            self.utilityFileSystem.copyFile(atPath: atPath, toPath: toPath)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if error == .success, let ocId {
                /// SIGNAL
                fileProviderData.shared.signalEnumerator(ocId: metadata.ocIdTransfer, type: .delete)
                if !metadata.ocIdTransfer.isEmpty, ocId != metadata.ocIdTransfer {
                    NCManageDatabase.shared.deleteMetadataOcId(metadata.ocIdTransfer)
                }
                metadata.fileName = fileName
                metadata.serverUrl = serverUrl
                metadata.uploadDate = (date as? NSDate) ?? NSDate()
                metadata.etag = etag ?? ""
                metadata.ocId = ocId
                metadata.size = size
                if let fileId = NCUtility().ocIdToFileId(ocId: ocId) {
                    metadata.fileId = fileId
                }

                metadata.sceneIdentifier = nil
                metadata.session = ""
                metadata.sessionError = ""
                metadata.sessionSelector = ""
                metadata.sessionDate = nil
                metadata.sessionTaskIdentifier = 0
                metadata.status = NCGlobal.shared.metadataStatusNormal

                NCManageDatabase.shared.addMetadata(metadata)
                NCManageDatabase.shared.addLocalFile(metadata: metadata)

                /// SIGNAL
                fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .update)
            } else {
                NCManageDatabase.shared.deleteMetadataOcId(metadata.ocIdTransfer)
                /// SIGNAL
                fileProviderData.shared.signalEnumerator(ocId: metadata.ocIdTransfer, type: .delete)
            }
        }
    }
}
