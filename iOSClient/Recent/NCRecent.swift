//
//  NCRecent.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 29/09/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

class NCRecent: NCCollectionViewCommon {

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_recent_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewRecent
        enableSearchBar = false
        headerMenuButtonsCommand = false
        headerMenuButtonsView = false
        headerRichWorkspaceDisable = true
        emptyImage = NCUtility.shared.loadImage(named: "clock.arrow.circlepath", color: .gray, size: UIScreen.main.bounds.width)
        emptyTitle = "_files_no_files_"
        emptyDescription = ""
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setFileAppreance()
    }

    // MARK: - DataSource + NC Endpoint

    override func reloadDataSource(forced: Bool = true) {
        super.reloadDataSource()

        DispatchQueue.global().async {
            let metadatas = NCManageDatabase.shared.getAdvancedMetadatas(predicate: NSPredicate(format: "account == %@", self.appDelegate.account), page: 1, limit: 100, sorted: "date", ascending: false)
            self.dataSource = NCDataSource(metadatas: metadatas,
                                           account: self.appDelegate.account,
                                           directoryOnTop: false,
                                           favoriteOnTop: false,
                                           groupByField: self.groupByField,
                                           providers: self.providers,
                                           searchResults: self.searchResults)

            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()
            }
        }
    }

    override func reloadDataSourceNetwork(forced: Bool = false) {
        super.reloadDataSourceNetwork(forced: forced)

        let requestBodyRecent =
        """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:basicsearch>
            <d:select>
                <d:prop>
                    <d:displayname/>
                    <d:getcontenttype/>
                    <d:resourcetype/>
                    <d:getcontentlength/>
                    <d:getlastmodified/>
                    <d:getetag/>
                    <d:quota-used-bytes/>
                    <d:quota-available-bytes/>
                    <permissions xmlns=\"http://owncloud.org/ns\"/>
                    <id xmlns=\"http://owncloud.org/ns\"/>
                    <fileid xmlns=\"http://owncloud.org/ns\"/>
                    <size xmlns=\"http://owncloud.org/ns\"/>
                    <favorite xmlns=\"http://owncloud.org/ns\"/>
                    <creation_time xmlns=\"http://nextcloud.org/ns\"/>
                    <upload_time xmlns=\"http://nextcloud.org/ns\"/>
                    <is-encrypted xmlns=\"http://nextcloud.org/ns\"/>
                    <mount-type xmlns=\"http://nextcloud.org/ns\"/>
                    <owner-id xmlns=\"http://owncloud.org/ns\"/>
                    <owner-display-name xmlns=\"http://owncloud.org/ns\"/>
                    <comments-unread xmlns=\"http://owncloud.org/ns\"/>
                    <has-preview xmlns=\"http://nextcloud.org/ns\"/>
                    <trashbin-filename xmlns=\"http://nextcloud.org/ns\"/>
                    <trashbin-original-location xmlns=\"http://nextcloud.org/ns\"/>
                    <trashbin-deletion-time xmlns=\"http://nextcloud.org/ns\"/>
                </d:prop>
            </d:select>
        <d:from>
            <d:scope>
                <d:href>%@</d:href>
                <d:depth>infinity</d:depth>
            </d:scope>
        </d:from>
        <d:where>
            <d:lt>
                <d:prop>
                    <d:getlastmodified/>
                </d:prop>
                <d:literal>%@</d:literal>
            </d:lt>
        </d:where>
        <d:orderby>
            <d:order>
                <d:prop>
                    <d:getlastmodified/>
                </d:prop>
                <d:descending/>
            </d:order>
        </d:orderby>
        <d:limit>
            <d:nresults>100</d:nresults>
        </d:limit>
        </d:basicsearch>
        </d:searchrequest>
        """

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let lessDateString = dateFormatter.string(from: Date())
        let requestBody = String(format: requestBodyRecent, "/files/"+appDelegate.userId, lessDateString)

        isReloadDataSourceNetworkInProgress = true
        collectionView?.reloadData()

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.searchBodyRequest(serverUrl: appDelegate.urlBase, requestBody: requestBody, showHiddenFiles: CCUtility.getShowHiddenFiles(), options: options) { account, files, data, error in

            if error == .success {
                NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, metadatasFolder, metadatas in

                    // Update sub directories
                    for metadata in metadatasFolder {
                        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                        NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrl, account: account)
                    }
                    // Add metadatas
                    NCManageDatabase.shared.addMetadatas(metadatas)

                    self.reloadDataSource()
                }
            } else {
                DispatchQueue.main.async {
                    self.collectionView?.reloadData()
                }
            }

            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.isReloadDataSourceNetworkInProgress = false
            }
        }
    }
}
