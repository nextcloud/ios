//
//  NCGroupfolders.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/04/2023.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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

class NCGroupfolders: NCCollectionViewCommon {

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        titleCurrentFolder = NSLocalizedString("_group_folders_", comment: "")
        layoutKey = NCGlobal.shared.layoutViewGroupfolders
        enableSearchBar = false
        headerMenuButtonsCommand = false
        headerMenuButtonsView = true
        headerRichWorkspaceDisable = true
        emptyImage = UIImage(named: "folder_group")?.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width)
        emptyTitle = "_files_no_files_"
        emptyDescription = "_tutorial_groupfolders_view_"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setFileAppreance()

        NotificationCenter.default.addObserver(self, selector: #selector(readFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterOperationReadFile), object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterOperationReadFile), object: nil)
    }

    // MARK: - NotificationCenter

    @objc func readFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else {
            return
        }

        dataSource.addMetadata(metadata)
        self.collectionView?.reloadData()
    }

    // MARK: - DataSource + NC Endpoint

    override func reloadDataSource(forced: Bool = true) {
        super.reloadDataSource()

        DispatchQueue.global().async {

            var metadatas: [tableMetadata] = []

            if self.serverUrl.isEmpty {
                metadatas = NCManageDatabase.shared.getMetadatasFromGroupfolders(account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId)
            } else {
                metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
            }

            self.dataSource = NCDataSource(
                metadatas: metadatas,
                account: self.appDelegate.account,
                sort: self.layoutForView?.sort,
                ascending: self.layoutForView?.ascending,
                directoryOnTop: self.layoutForView?.directoryOnTop,
                favoriteOnTop: true,
                filterLivePhoto: true,
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

        isReloadDataSourceNetworkInProgress = true
        collectionView?.reloadData()

        if serverUrl.isEmpty {

            let homeServerUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: self.appDelegate.urlBase, userId: self.appDelegate.userId)
            let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

            NextcloudKit.shared.getGroupfolders(options: options) { account, results, _, error in

                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.isReloadDataSourceNetworkInProgress = false
                }

                if error == .success, let groupfolders = results {
                    NCManageDatabase.shared.addGroupfolders(account: account, groupfolders: groupfolders)
                    for groupfolder in groupfolders {
                        let serverUrlFileName = homeServerUrl + groupfolder.mountPoint
                        if NCManageDatabase.shared.getMetadataFromDirectory(account: self.appDelegate.account, serverUrl: serverUrlFileName) == nil {
                            NCOperationQueue.shared.readFile(serverUrlFileName: serverUrlFileName)
                        }
                    }
                } else if error != .success {
                    NCContentPresenter.shared.showError(error: error)
                }
                self.reloadDataSource()
            }
        } else {

            networkReadFolder(forced: forced) { _, _, metadatasUpdate, metadatasDelete, _ in

                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.isReloadDataSourceNetworkInProgress = false

                    if !(metadatasUpdate?.isEmpty ?? true) || !(metadatasDelete?.isEmpty ?? true) || forced {
                        self.reloadDataSource()
                    } else {
                        self.collectionView?.reloadData()
                    }
                }
            }
        }
    }
}
