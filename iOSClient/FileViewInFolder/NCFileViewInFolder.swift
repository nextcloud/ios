//
//  NCFileViewInFolder.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/10/2020.
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
import NCCommunication

class NCFileViewInFolder: NCCollectionViewCommon {

    internal var fileName: String?

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        appDelegate.activeFileViewInFolder = self
        titleCurrentFolder = NCBrandOptions.shared.brand
        layoutKey = NCGlobal.shared.layoutViewViewInFolder
        enableSearchBar = false
        emptyImage = UIImage(named: "folder")?.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width)
        emptyTitle = "_files_no_files_"
        emptyDescription = "_no_file_pull_down_"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDelegate.activeViewController = self

        if serverUrl == NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account) {
            self.navigationItem.title = NCBrandOptions.shared.brand
        } else {
            self.navigationItem.title = (serverUrl as NSString).lastPathComponent
        }

        presentationController?.delegate = self

        layoutForView = NCUtility.shared.getLayoutForView(key: layoutKey, serverUrl: serverUrl)
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView?.collectionViewLayout = listLayout
        } else {
            collectionView?.collectionViewLayout = gridLayout
        }

        self.navigationItem.leftBarButtonItem = nil
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""), style: .plain, target: self, action: #selector(tapClose(sender:)))
    }

    // MARK: - TAP EVENT

    @objc func tapClose(sender: Any) {
        dismiss(animated: true)
    }

    // MARK: - DataSource + NC Endpoint

    override func reloadDataSource() {
        super.reloadDataSource()

        DispatchQueue.global().async {

            if !self.isSearching {
                self.metadatasSource = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, self.serverUrl))
                if self.metadataFolder == nil {
                    self.metadataFolder = NCManageDatabase.shared.getMetadataFolder(account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, serverUrl: self.serverUrl)
                }
            }

            self.dataSource = NCDataSource(metadatasSource: self.metadatasSource, sort: self.layoutForView?.sort, ascending: self.layoutForView?.ascending, directoryOnTop: self.layoutForView?.directoryOnTop, favoriteOnTop: true, filterLivePhoto: true)

            DispatchQueue.main.async {

                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()

                // Blink file
                if self.fileName != nil {
                    if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", self.appDelegate.account, self.serverUrl, self.fileName!)) {
                        if let row = self.dataSource.getIndexMetadata(ocId: metadata.ocId) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                UIView.animate(withDuration: 0.3) {
                                    self.collectionView.scrollToItem(at: IndexPath(row: row, section: 0), at: .centeredVertically, animated: false)
                                } completion: { _ in
                                    if let cell = self.collectionView.cellForItem(at: IndexPath(row: row, section: 0)) {
                                        cell.backgroundColor = .darkGray
                                        UIView.animate(withDuration: 2) {
                                            cell.backgroundColor = .clear
                                            self.fileName = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    override func reloadDataSourceNetwork(forced: Bool = false) {
        super.reloadDataSourceNetwork(forced: forced)

        if isSearching {
            networkSearch()
            return
        }

        isReloadDataSourceNetworkInProgress = true
        collectionView?.reloadData()

        networkReadFolder(forced: forced) { tableDirectory, metadatas, _, _, errorCode, _ in
            if errorCode == 0 {
                for metadata in metadatas ?? [] {
                    if !metadata.directory {
                        if NCManageDatabase.shared.isDownloadMetadata(metadata, download: false) {
                            NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorDownloadFile)
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.isReloadDataSourceNetworkInProgress = false
                self.richWorkspaceText = tableDirectory?.richWorkspace
                self.reloadDataSource()
            }
        }
    }
}
