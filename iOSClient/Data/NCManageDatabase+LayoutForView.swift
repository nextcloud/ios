// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class NCDBLayoutForView: Object {
    @Persisted(primaryKey: true) var index = ""
    @Persisted var account = ""
    @Persisted var keyStore = ""
    @Persisted var layout: String = NCGlobal.shared.layoutList
    @Persisted var sort: String = "fileName"
    @Persisted var ascending: Bool = true
    @Persisted var groupBy: String = "none"
    @Persisted var columnGrid: Int = 3
    @Persisted var columnPhoto: Int = 3
}

extension NCManageDatabase {

    // MARK: - Realm write

    func setLayoutForView(account: String,
                          key: String,
                          serverUrl: String,
                          layout: String? = nil) {
        let keyStore = serverUrl.isEmpty ? key : serverUrl
        let indexKey = account + " " + keyStore
        var finalObject = NCDBLayoutForView()

        performRealmWrite { realm in
            if let existing = realm.objects(NCDBLayoutForView.self).filter("index == %@", indexKey).first {
                finalObject = existing
            } else {
                finalObject.index = indexKey
                finalObject.account = account
                finalObject.keyStore = keyStore
            }
            if let layout {
                finalObject.layout = layout
            }

            realm.add(finalObject, update: .all)
        }
    }

    @discardableResult
    func setLayoutForView(layoutForView: NCDBLayoutForView, withSubFolders subFolders: Bool = false) -> NCDBLayoutForView? {
        let object = NCDBLayoutForView(value: layoutForView)

        if subFolders {
            let keyStore = layoutForView.keyStore
            if let layouts = performRealmRead({
                $0.objects(NCDBLayoutForView.self)
                    .filter("keyStore BEGINSWITH %@", keyStore)
                    .map { NCDBLayoutForView(value: $0) }
            }) {
                for layout in layouts {
                    layout.layout = layoutForView.layout
                    layout.sort = layoutForView.sort
                    layout.ascending = layoutForView.ascending
                    layout.groupBy = layoutForView.groupBy
                    layout.columnGrid = layoutForView.columnGrid
                    layout.columnPhoto = layoutForView.columnPhoto

                    performRealmWrite { realm in
                        realm.add(layout, update: .all)
                    }
                }
            }
        } else {
            performRealmWrite { realm in
                realm.add(object, update: .all)
            }
        }

        return NCDBLayoutForView(value: object)
    }

    // MARK: - Realm read

    func getLayoutForView(account: String, key: String, serverUrl: String, layout: String? = nil) -> NCDBLayoutForView {
        let keyStore = serverUrl.isEmpty ? key : serverUrl
        let index = account + " " + keyStore

        if let layout = performRealmRead({
            $0.objects(NCDBLayoutForView.self)
                .filter("index == %@", index)
                .first
                .map { NCDBLayoutForView(value: $0) }
        }) {
            return layout
        }

        let tblAccount = performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first
        }

        if let tblAccount {
            let home = utilityFileSystem.getHomeServer(urlBase: tblAccount.urlBase, userId: tblAccount.userId)
            let defaultServerUrlAutoUpload = home + "/" + NCBrandOptions.shared.folderDefaultAutoUpload
            var serverUrlAutoUpload = tblAccount.autoUploadDirectory.isEmpty ? home : tblAccount.autoUploadDirectory

            if tblAccount.autoUploadFileName.isEmpty {
                serverUrlAutoUpload += "/" + NCBrandOptions.shared.folderDefaultAutoUpload
            } else {
                serverUrlAutoUpload += "/" + tblAccount.autoUploadFileName
            }

            if serverUrl == defaultServerUrlAutoUpload || serverUrl == serverUrlAutoUpload {

                // AutoUpload serverUrl / Photo
                let photosLayoutForView = NCDBLayoutForView()
                photosLayoutForView.index = index
                photosLayoutForView.account = account
                photosLayoutForView.keyStore = keyStore
                photosLayoutForView.layout = NCGlobal.shared.layoutPhotoSquare
                photosLayoutForView.sort = "date"
                photosLayoutForView.ascending = false

                DispatchQueue.global(qos: .utility).async {
                    self.setLayoutForView(layoutForView: photosLayoutForView)
                }

                return photosLayoutForView

            } else if !serverUrl.isEmpty,
                      let serverDirectoryUp = NCUtilityFileSystem().serverDirectoryUp(serverUrl: serverUrl, home: home) {

                // Get previus serverUrl
                let index = account + " " + serverDirectoryUp
                if let previusLayoutForView = performRealmRead({
                    $0.objects(NCDBLayoutForView.self)
                        .filter("index == %@", index)
                        .first
                        .map { NCDBLayoutForView(value: $0) }
                }) {
                    previusLayoutForView.index = account + " " + serverUrl
                    previusLayoutForView.keyStore = serverUrl

                    DispatchQueue.global(qos: .utility).async {
                        self.setLayoutForView(layoutForView: previusLayoutForView)
                    }

                    return previusLayoutForView
                }
            }
        }

        // Standatd layout
        let layout = layout ?? NCGlobal.shared.layoutList
        DispatchQueue.global(qos: .utility).async {
            self.setLayoutForView(account: account, key: key, serverUrl: serverUrl, layout: layout)
        }

        let placeholder = NCDBLayoutForView()
        placeholder.index = index
        placeholder.account = account
        placeholder.keyStore = keyStore
        placeholder.layout = layout

        return placeholder
    }

    func updatePhotoLayoutForView(account: String,
                                  key: String,
                                  serverUrl: String,
                                  updateBlock: @escaping (inout NCDBLayoutForView) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let keyStore = serverUrl.isEmpty ? key : serverUrl
            let index = account + " " + keyStore

            var layout: NCDBLayoutForView

            if let existing = self.performRealmRead({
                $0.objects(NCDBLayoutForView.self)
                    .filter("index == %@", index)
                    .first
            }) {
                layout = existing
            } else {
                layout = NCDBLayoutForView()
                layout.index = index
                layout.account = account
                layout.keyStore = keyStore
            }

            self.performRealmWrite { realm in
                updateBlock(&layout)
                realm.add(layout, update: .all)
            }
        }
    }
}
