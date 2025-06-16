// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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

    // MARK: - Realm write

    func addDirectEditing(account: String,
                          editors: [NKEditorDetailsEditors],
                          creators: [NKEditorDetailsCreators],
                          sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let resultsCreators = realm.objects(tableDirectEditingCreators.self).filter("account == %@", account)
            realm.delete(resultsCreators)

            let resultsEditors = realm.objects(tableDirectEditingEditors.self).filter("account == %@", account)
            realm.delete(resultsEditors)

            creators.forEach { creator in
                let object = tableDirectEditingCreators()
                object.account = account
                object.editor = creator.editor
                object.ext = creator.ext
                object.identifier = creator.identifier
                object.mimetype = creator.mimetype
                object.name = creator.name
                object.templates = creator.templates
                realm.add(object)
            }

            editors.forEach { editor in
                let object = tableDirectEditingEditors()
                object.account = account
                object.name = editor.name
                object.editor = editor.name.lowercased() == NCGlobal.shared.editorOnlyoffice ? NCGlobal.shared.editorOnlyoffice : NCGlobal.shared.editorText
                object.mimetypes.append(objectsIn: editor.mimetypes)
                object.optionalMimetypes.append(objectsIn: editor.optionalMimetypes)
                object.secure = editor.secure
                realm.add(object)
            }
        }
    }

    /// Asynchronously updates the direct editing creators and editors for a given account in the Realm database.
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - editors: A list of editor definitions to store.
    ///   - creators: A list of creator definitions to store.
    ///   - async: Whether the Realm write should be executed asynchronously (default is true).
    func addDirectEditingAsync(account: String,
                               editors: [NKEditorDetailsEditors],
                               creators: [NKEditorDetailsCreators]) async {
        await performRealmWriteAsync { realm in
            // Remove existing creators and editors for the account
            let resultsCreators = realm.objects(tableDirectEditingCreators.self).filter("account == %@", account)
            realm.delete(resultsCreators)

            let resultsEditors = realm.objects(tableDirectEditingEditors.self).filter("account == %@", account)
            realm.delete(resultsEditors)

            // Add new creators
            for creator in creators {
                let object = tableDirectEditingCreators()
                object.account = account
                object.editor = creator.editor
                object.ext = creator.ext
                object.identifier = creator.identifier
                object.mimetype = creator.mimetype
                object.name = creator.name
                object.templates = creator.templates
                realm.add(object)
            }

            // Add new editors
            for editor in editors {
                let object = tableDirectEditingEditors()
                object.account = account
                object.name = editor.name
                object.editor = editor.name.lowercased() == NCGlobal.shared.editorOnlyoffice
                    ? NCGlobal.shared.editorOnlyoffice
                    : NCGlobal.shared.editorText
                object.mimetypes.append(objectsIn: editor.mimetypes)
                object.optionalMimetypes.append(objectsIn: editor.optionalMimetypes)
                object.secure = editor.secure
                realm.add(object)
            }
        }
    }

    // MARK: - Realm read

    func getDirectEditingCreators(account: String) -> [tableDirectEditingCreators]? {
        performRealmRead { realm in
            let results = realm.objects(tableDirectEditingCreators.self)
                .filter("account == %@", account)
            return results.isEmpty ? nil : results.map { tableDirectEditingCreators(value: $0) }
        }
    }

    func getDirectEditingCreators(account: String,
                                  dispatchOnMainQueue: Bool = true,
                                  completion: @escaping (_ tblDirectEditingCreators: [tableDirectEditingCreators]) -> Void) {
        var resultArray: [tableDirectEditingCreators] = []

        performRealmRead({ realm in
            let objects = realm.objects(tableDirectEditingCreators.self)
                .filter("account == %@", account)
            resultArray = objects.map { tableDirectEditingCreators(value: $0) }
        }, sync: false) { _ in
            if dispatchOnMainQueue {
                DispatchQueue.main.async {
                    completion(resultArray)
                }
            } else {
                completion(resultArray)
            }
        }
    }

    /// Asynchronously retrieves the list of `tableDirectEditingCreators` for the given account.
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - async: Whether the Realm read should be executed asynchronously (default is true).
    /// - Returns: An array of `tableDirectEditingCreators` objects.
    func getDirectEditingCreatorsAsync(account: String, async: Bool = true) async -> [tableDirectEditingCreators] {
        var resultArray: [tableDirectEditingCreators] = []

        await performRealmReadAsync { realm in
            let objects = realm.objects(tableDirectEditingCreators.self)
                .filter("account == %@", account)
            resultArray = objects.map { tableDirectEditingCreators(value: $0) }
        }

        return resultArray
    }

    func getDirectEditingCreators(predicate: NSPredicate) -> [tableDirectEditingCreators]? {
        performRealmRead { realm in
            let results = realm.objects(tableDirectEditingCreators.self)
                .filter(predicate)
            return results.isEmpty ? nil : results.map { tableDirectEditingCreators(value: $0) }
        }
    }

    func getDirectEditingEditors(account: String) -> [tableDirectEditingEditors]? {
        performRealmRead { realm in
            let results = realm.objects(tableDirectEditingEditors.self)
                .filter("account == %@", account)
            return results.isEmpty ? nil : results.map { tableDirectEditingEditors.init(value: $0) }
        }
    }
}
