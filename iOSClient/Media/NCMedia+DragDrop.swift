//
//  NCMedia+DragDrop.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/04/24.
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

import UIKit
import NextcloudKit

// MARK: - Drop

extension NCMedia: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: UIImage.self) || session.hasItemsConforming(toTypeIdentifiers: [UTType.movie.identifier])
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let account = NCManageDatabase.shared.getActiveAccount() else { return }
        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: account.urlBase, userId: account.userId, account: account.account)
        let serverUrl = utilityFileSystem.createGranularityPath(serverUrl: autoUploadPath)
        var counter: Int = 0
        for dragItem in coordinator.session.items {
            dragItem.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                if let error {
                    NCContentPresenter().showError(error: NKError(error: error))
                    return
                }
                if let url = url {
                    if counter == 0,
                       !NCNetworking.shared.createFolder(assets: nil, useSubFolder: account.autoUploadCreateSubfolder, account: account.account, urlBase: account.urlBase, userId: account.userId, withPush: false) {
                        return
                    }
                    do {
                        let data = try Data(contentsOf: url)
                        Task {
                            let ocId = NSUUID().uuidString
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: url.lastPathComponent, account: self.appDelegate.account, serverUrl: serverUrl)
                            let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)
                            try data.write(to: URL(fileURLWithPath: fileNamePath))
                            let metadataForUpload = NCManageDatabase.shared.createMetadata(account: self.appDelegate.account, user: self.appDelegate.user, userId: self.appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: ocId, serverUrl: serverUrl, urlBase: self.appDelegate.urlBase, url: "", contentType: "")
                            metadataForUpload.session = NCNetworking.shared.sessionUploadBackground
                            metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
                            metadataForUpload.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
                            metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
                            metadataForUpload.sessionDate = Date()

                            NCManageDatabase.shared.addMetadata(metadataForUpload)
                        }
                    } catch {
                        NCContentPresenter().showError(error: NKError(error: error))
                        return
                    }
                    counter += 1
                }
            }
        }
    }
}
