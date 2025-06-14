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
    func setLayoutForView(layoutForView: NCDBLayoutForView) -> NCDBLayoutForView? {
        let object = NCDBLayoutForView(value: layoutForView)

        performRealmWrite { realm in
            realm.add(object, update: .all)
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

        DispatchQueue.global(qos: .utility).async {
            _ = self.setLayoutForView(account: account, key: key, serverUrl: serverUrl, layout: layout)
        }

        let placeholder = NCDBLayoutForView()
        placeholder.index = index
        placeholder.account = account
        placeholder.keyStore = keyStore
        if let layout {
            placeholder.layout = layout
        }
        return placeholder
    }

    func updateLayoutForView(account: String,
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

            // Applica la modifica in modo sicuro
            self.performRealmWrite { realm in
                updateBlock(&layout)
                realm.add(layout, update: .all)
            }
        }
    }
}
