//
//  NCManageDatabase+DirectEditing.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 13/11/23.
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

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableDirectEditingCreators: Object {
    @objc dynamic var account = ""
    @objc dynamic var editor = ""
    @objc dynamic var ext = ""
    @objc dynamic var identifier = ""
    @objc dynamic var mimetype = ""
    @objc dynamic var name = ""
    @objc dynamic var templates: Int = 0
}

class tableDirectEditingEditors: Object {
    @objc dynamic var account = ""
    @objc dynamic var editor = ""
    let mimetypes = List<String>()
    @objc dynamic var name = ""
    let optionalMimetypes = List<String>()
    @objc dynamic var secure: Int = 0
}

extension NCManageDatabase {
    func addDirectEditing(account: String, editors: [NKEditorDetailsEditors], creators: [NKEditorDetailsCreators]) {
        do {
            let realm = try Realm()
            try realm.write {
                let resultsCreators = realm.objects(tableDirectEditingCreators.self).filter("account == %@", account)
                realm.delete(resultsCreators)
                let resultsEditors = realm.objects(tableDirectEditingEditors.self).filter("account == %@", account)
                realm.delete(resultsEditors)

                for creator in creators {
                    let addObject = tableDirectEditingCreators()

                    addObject.account = account
                    addObject.editor = creator.editor
                    addObject.ext = creator.ext
                    addObject.identifier = creator.identifier
                    addObject.mimetype = creator.mimetype
                    addObject.name = creator.name
                    addObject.templates = creator.templates
                    realm.add(addObject)
                }

                for editor in editors {
                    let addObject = tableDirectEditingEditors()

                    addObject.account = account
                    for mimeType in editor.mimetypes {
                        addObject.mimetypes.append(mimeType)
                    }
                    addObject.name = editor.name
                    if editor.name.lowercased() == NCGlobal.shared.editorOnlyoffice {
                        addObject.editor = NCGlobal.shared.editorOnlyoffice
                    } else {
                        addObject.editor = NCGlobal.shared.editorText
                    }
                    for mimeType in editor.optionalMimetypes {
                        addObject.optionalMimetypes.append(mimeType)
                    }
                    addObject.secure = editor.secure
                    realm.add(addObject)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getDirectEditingCreators(account: String) -> [tableDirectEditingCreators]? {
        do {
            let realm = try Realm()
            let results = realm.objects(tableDirectEditingCreators.self).filter("account == %@", account)
            if results.isEmpty {
                return nil
            } else {
                return Array(results.map { tableDirectEditingCreators.init(value: $0) })
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access to database: \(error)")
        }
        return nil
    }

    func getDirectEditingCreators(predicate: NSPredicate) -> [tableDirectEditingCreators]? {
        do {
            let realm = try Realm()
            let results = realm.objects(tableDirectEditingCreators.self).filter(predicate)
            if results.isEmpty {
                return nil
            } else {
                return Array(results.map { tableDirectEditingCreators.init(value: $0) })
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access to database: \(error)")
        }
        return nil
    }

    func getDirectEditingEditors(account: String) -> [tableDirectEditingEditors]? {
        do {
            let realm = try Realm()
            let results = realm.objects(tableDirectEditingEditors.self).filter("account == %@", account)
            if results.isEmpty {
                return nil
            } else {
                return Array(results.map { tableDirectEditingEditors.init(value: $0) })
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access to database: \(error)")
        }
        return nil
    }
}
