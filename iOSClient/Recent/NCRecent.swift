// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        Task {
            await NCNetworking.shared.networkingTasks.cancel(identifier: "NCRecent")
        }
    }

    // MARK: - DataSource

    override func reloadDataSource() async {
        var metadatas: [tableMetadata] = []
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "account == %@", session.account),
            NSPredicate(format: "fileName != %@", NextcloudKit.shared.nkCommonInstance.rootFileName),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "directory == %@", NSNumber(value: false)),
                NSPredicate(format: "%K == %lld", "size", 0)
            ]),
            NSPredicate(format: "date >= %@", fourteenDaysAgo as NSDate)
        ])
        if let results = await self.database.getMetadatasAsync(predicate: predicate,
                                                               limit: 100) {
            metadatas = await self.database.sortedMetadata(layoutForView: layoutForView,
                                                           account: session.account,
                                                           metadatas: results)
        }

        self.dataSource = NCCollectionViewDataSource(metadatas: metadatas,
                                                     layoutForView: layoutForView,
                                                     account: session.account)
        await super.reloadDataSource()
    }

    override func getServerData(forced: Bool = false) async {
        defer {
            stopGUIGetServerData()
        }

        // If is already in-flight, do nothing
        if await NCNetworking.shared.networkingTasks.isReading(identifier: "NCRecent") {
            return
        }

        let requestBodyRecent =
        """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\" xmlns:ns=\"http://nextcloud.org/ns\">
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
            <d:and>
                <d:or>
                    <d:not>
                        <d:eq>
                            <d:prop>
                                <d:getcontenttype/>
                            </d:prop>
                            <d:literal>httpd/unix-directory</d:literal>
                        </d:eq>
                    </d:not>
                    <d:eq>
                        <d:prop>
                            <oc:size/>
                        </d:prop>
                        <d:literal>0</d:literal>
                    </d:eq>
                </d:or>
                <d:gt>
                    <d:prop>
                        <d:getlastmodified/>
                    </d:prop>
                    <d:literal>%@</d:literal>
                </d:gt>
            </d:and>
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
            <ns:firstresult>0</ns:firstresult>
        </d:limit>
        </d:basicsearch>
        </d:searchrequest>
        """

        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let greaterDateString = String(Int(fourteenDaysAgo.timeIntervalSince1970))
        let requestBody = String(format: requestBodyRecent, "/files/" + session.userId, greaterDateString)
        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: session.account)

        startGUIGetServerData()

        let resultsSearch = await NextcloudKit.shared.searchBodyRequestAsync(serverUrl: session.urlBase,
                                                                             requestBody: requestBody,
                                                                             showHiddenFiles: showHiddenFiles,
                                                                             account: session.account) { task in
            Task {
                await NCNetworking.shared.networkingTasks.track(identifier: "NCRecent", task: task)
            }
            if self.dataSource.isEmpty() {
                self.collectionView.reloadData()
            }
        }

        guard resultsSearch.error == .success, let files = resultsSearch.files else {
            return
        }

        let results = await NCManageDatabaseCreateMetadata().convertFilesToMetadatasAsync(files)
        await self.database.addMetadatasAsync(results.metadatas)

        if results.metadatas.isEmpty {
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferReloadData(serverUrl: self.serverUrl)
            }
        } else {
            await self.reloadDataSource()
        }
    }
}
