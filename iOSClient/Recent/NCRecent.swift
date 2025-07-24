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

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_recent_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewRecent
        enableSearchBar = false
        headerRichWorkspaceDisable = true
        emptyImageName = "clock.arrow.circlepath"
        emptyTitle = "_files_no_files_"
        emptyDescription = ""
    }

    // MARK: - View Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        Task {
            await reloadDataSource()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task {
            await getServerData()
        }
    }

    // MARK: - DataSource

    override func reloadDataSource() async {

        if let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND fileName != %@", session.account, NextcloudKit.shared.nkCommonInstance.rootFileName), sortedByKeyPath: "date", ascending: false) {

            self.dataSource = NCCollectionViewDataSource(metadatas: metadatas, layoutForView: layoutForView, account: session.account)

            cachingAsync(metadatas: metadatas)
        }

        layoutForView?.sort = "date"
        layoutForView?.ascending = false

        await super.reloadDataSource()
    }

    override func getServerData(refresh: Bool = false) async {
        await super.getServerData()

        defer {
            restoreDefaultTitle()
        }

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
        /Users/marinofaggiana/Developer/ios/iOSClient/Assistant                 <d:getlastmodified/>
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
        let requestBody = String(format: requestBodyRecent, "/files/" + session.userId, lessDateString)
        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: session.account)

        showLoadingTitle()

        let resultsSearch = await NextcloudKit.shared.searchBodyRequestAsync(serverUrl: session.urlBase,
                                                                             requestBody: requestBody,
                                                                             showHiddenFiles: showHiddenFiles,
                                                                             account: session.account) { task in
            self.dataSourceTask = task
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        }

        guard resultsSearch.error == .success, let files = resultsSearch.files else {
            return
        }

        let (_, metadatas) = await self.database.convertFilesToMetadatasAsync(files)

        await self.database.addMetadatasAsync(metadatas)
        await self.reloadDataSource()
    }
}
