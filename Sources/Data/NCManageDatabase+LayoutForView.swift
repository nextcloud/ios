//
//  NCManageDatabase+LayoutForView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/11/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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
    @Persisted var directoryOnTop: Bool = true
    @Persisted var titleButtonHeader: String = "_sorted_by_name_a_z_"
    @Persisted var itemForLine: Int = 3
}

extension NCManageDatabase {

    @discardableResult
    func setLayoutForView(account: String, key: String, serverUrl: String, layout: String? = nil, sort: String? = nil, ascending: Bool? = nil, groupBy: String? = nil, directoryOnTop: Bool? = nil, titleButtonHeader: String? = nil, itemForLine: Int? = nil) -> NCDBLayoutForView? {

        let realm = try! Realm()

        var keyStore = key
        if !serverUrl.isEmpty { keyStore = serverUrl}
        let index = account + " " + keyStore

        var addObject = NCDBLayoutForView()

        do {
            try realm.write {
                if let result = realm.objects(NCDBLayoutForView.self).filter("index == %@", index).first {
                    addObject = result
                } else {
                    addObject.index = index
                }
                addObject.account = account
                addObject.keyStore = keyStore
                if let layout = layout {
                    addObject.layout = layout
                }
                if let sort = sort {
                    addObject.sort = sort
                }
                if let sort = sort {
                    addObject.sort = sort
                }
                if let ascending = ascending {
                    addObject.ascending = ascending
                }
                if let groupBy = groupBy {
                    addObject.groupBy = groupBy
                }
                if let directoryOnTop = directoryOnTop {
                    addObject.directoryOnTop = directoryOnTop
                }
                if let titleButtonHeader = titleButtonHeader {
                    addObject.titleButtonHeader = titleButtonHeader
                }
                if let itemForLine = itemForLine {
                    addObject.itemForLine = itemForLine
                }
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }

        return NCDBLayoutForView.init(value: addObject)
    }

    @discardableResult
    func setLayoutForView(layoutForView: NCDBLayoutForView) -> NCDBLayoutForView? {

        let realm = try! Realm()
        let result = NCDBLayoutForView.init(value: layoutForView)

        do {
            try realm.write {
                realm.add(result, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
            return nil
        }
        return NCDBLayoutForView.init(value: result)
    }

    func getLayoutForView(account: String, key: String, serverUrl: String) -> NCDBLayoutForView? {

        let realm = try! Realm()

        var keyStore = key
        if !serverUrl.isEmpty { keyStore = serverUrl}
        let index = account + " " + keyStore

        if let result = realm.objects(NCDBLayoutForView.self).filter("index == %@", index).first {
            return NCDBLayoutForView.init(value: result)
        } else {
            return setLayoutForView(account: account, key: key, serverUrl: serverUrl)
        }
    }
}
