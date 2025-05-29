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
    @Persisted var titleButtonHeader: String = "_sorted_by_name_a_z_"
    @Persisted var columnGrid: Int = 3
    @Persisted var columnPhoto: Int = 3
}

extension NCManageDatabase {

    // MARK: - Realm write

    @discardableResult
    func setLayoutForView(account: String,
                          key: String,
                          serverUrl: String,
                          layout: String? = nil,
                          sort: String? = nil,
                          ascending: Bool? = nil,
                          groupBy: String? = nil,
                          titleButtonHeader: String? = nil,
                          columnGrid: Int? = nil,
                          columnPhoto: Int? = nil) -> NCDBLayoutForView? {
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

            if let layout { finalObject.layout = layout }
            if let sort { finalObject.sort = sort }
            if let ascending { finalObject.ascending = ascending }
            if let groupBy { finalObject.groupBy = groupBy }
            if let titleButtonHeader { finalObject.titleButtonHeader = titleButtonHeader }
            if let columnGrid { finalObject.columnGrid = columnGrid }
            if let columnPhoto { finalObject.columnPhoto = columnPhoto }

            realm.add(finalObject, update: .all)
        }

        return finalObject
    }

    @discardableResult
    func setLayoutForView(layoutForView: NCDBLayoutForView, sync: Bool = true) -> NCDBLayoutForView? {
        let object = NCDBLayoutForView(value: layoutForView)

        performRealmWrite(sync: sync) { realm in
            realm.add(object, update: .all)
        }

        return NCDBLayoutForView(value: object)
    }

    // MARK: - Realm read

    func getLayoutForView(account: String, key: String, serverUrl: String) -> NCDBLayoutForView? {
        let keyStore = serverUrl.isEmpty ? key : serverUrl
        let index = account + " " + keyStore

        return performRealmRead {
            $0.objects(NCDBLayoutForView.self)
                .filter("index == %@", index)
                .first
                .map { NCDBLayoutForView(value: $0) }
        } ?? setLayoutForView(account: account, key: key, serverUrl: serverUrl)
    }
}
