// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit
import SwiftyJSON

class tableActivity: Object, DateCompareable {
    var dateKey: Date { date as Date }

    @objc dynamic var account = ""
    @objc dynamic var idPrimaryKey = ""
    @objc dynamic var action = "Activity"
    @objc dynamic var date = NSDate()
    @objc dynamic var idActivity: Int = 0
    @objc dynamic var app = ""
    @objc dynamic var type = ""
    @objc dynamic var user = ""
    @objc dynamic var subject = ""
    @objc dynamic var subjectRich = ""
    let subjectRichItem = List<tableActivitySubjectRich>()
    @objc dynamic var icon = ""
    @objc dynamic var link = ""
    @objc dynamic var message = ""
    @objc dynamic var objectType = ""
    @objc dynamic var objectId: Int = 0
    @objc dynamic var objectName = ""
    @objc dynamic var note = ""
    @objc dynamic var selector = ""
    @objc dynamic var verbose: Bool = false

    override static func primaryKey() -> String {
        return "idPrimaryKey"
    }
}

class tableActivityLatestId: Object {
    @objc dynamic var account = ""
    @objc dynamic var activityFirstKnown: Int = 0
    @objc dynamic var activityLastGiven: Int = 0

    override static func primaryKey() -> String {
        return "account"
    }
}

class tableActivityPreview: Object {
    @objc dynamic var account = ""
    @objc dynamic var filename = ""
    @objc dynamic var idPrimaryKey = ""
    @objc dynamic var idActivity: Int = 0
    @objc dynamic var source = ""
    @objc dynamic var link = ""
    @objc dynamic var mimeType = ""
    @objc dynamic var fileId: Int = 0
    @objc dynamic var view = ""
    @objc dynamic var isMimeTypeIcon: Bool = false

    override static func primaryKey() -> String {
        return "idPrimaryKey"
    }
}

class tableActivitySubjectRich: Object {
    @objc dynamic var account = ""
    @objc dynamic var idActivity: Int = 0
    @objc dynamic var idPrimaryKey = ""
    @objc dynamic var id = ""
    @objc dynamic var key = ""
    @objc dynamic var link = ""
    @objc dynamic var name = ""
    @objc dynamic var path = ""
    @objc dynamic var type = ""

    override static func primaryKey() -> String {
        return "idPrimaryKey"
    }
}

extension NCManageDatabase {

    // MARK: - Realm write

    func addActivity(_ activities: [NKActivity], account: String) {
        performRealmWrite { realm in
            for activity in activities {
                let addObjectActivity = tableActivity()

                addObjectActivity.account = account
                addObjectActivity.idActivity = activity.idActivity
                addObjectActivity.idPrimaryKey = account + String(activity.idActivity)
                addObjectActivity.date = activity.date as NSDate
                addObjectActivity.app = activity.app
                addObjectActivity.type = activity.type
                addObjectActivity.user = activity.user
                addObjectActivity.subject = activity.subject

                if let subjectRich = activity.subjectRich,
                   let json = JSON(subjectRich).array {

                    addObjectActivity.subjectRich = json[0].stringValue
                    if json.count > 1,
                       let dict = json[1].dictionary {

                        for (key, value) in dict {
                            let addObjectActivitySubjectRich = tableActivitySubjectRich()
                            let dict = value as JSON
                            addObjectActivitySubjectRich.account = account

                            if dict["id"].intValue > 0 {
                                addObjectActivitySubjectRich.id = String(dict["id"].intValue)
                            } else {
                                addObjectActivitySubjectRich.id = dict["id"].stringValue
                            }

                            addObjectActivitySubjectRich.name = dict["name"].stringValue
                            addObjectActivitySubjectRich.idPrimaryKey = account
                            + String(activity.idActivity)
                            + addObjectActivitySubjectRich.id
                            + addObjectActivitySubjectRich.name

                            addObjectActivitySubjectRich.key = key
                            addObjectActivitySubjectRich.idActivity = activity.idActivity
                            addObjectActivitySubjectRich.link = dict["link"].stringValue
                            addObjectActivitySubjectRich.path = dict["path"].stringValue
                            addObjectActivitySubjectRich.type = dict["type"].stringValue

                            realm.add(addObjectActivitySubjectRich, update: .all)
                        }
                    }
                }

                if let previews = activity.previews,
                   let json = JSON(previews).array {
                    for preview in json {
                        let addObjectActivityPreview = tableActivityPreview()

                        addObjectActivityPreview.account = account
                        addObjectActivityPreview.idActivity = activity.idActivity
                        addObjectActivityPreview.fileId = preview["fileId"].intValue
                        addObjectActivityPreview.filename = preview["filename"].stringValue
                        addObjectActivityPreview.idPrimaryKey = account + String(activity.idActivity) + String(addObjectActivityPreview.fileId)
                        addObjectActivityPreview.source = preview["source"].stringValue
                        addObjectActivityPreview.link = preview["link"].stringValue
                        addObjectActivityPreview.mimeType = preview["mimeType"].stringValue
                        addObjectActivityPreview.view = preview["view"].stringValue
                        addObjectActivityPreview.isMimeTypeIcon = preview["isMimeTypeIcon"].boolValue

                        realm.add(addObjectActivityPreview, update: .all)
                    }
                }

                addObjectActivity.icon = activity.icon
                addObjectActivity.link = activity.link
                addObjectActivity.message = activity.message
                addObjectActivity.objectType = activity.objectType
                addObjectActivity.objectId = activity.objectId
                addObjectActivity.objectName = activity.objectName

                realm.add(addObjectActivity, update: .all)
            }
        }
    }

    func updateLatestActivityId(activityFirstKnown: Int, activityLastGiven: Int, account: String) {
        performRealmWrite { realm in
            let object = tableActivityLatestId()
            object.activityFirstKnown = activityFirstKnown
            object.activityLastGiven = activityLastGiven
            object.account = account
            realm.add(object, update: .all)
        }
    }

    // MARK: - Realm read

    func getActivity(predicate: NSPredicate, filterFileId: String?) -> (all: [tableActivity], filter: [tableActivity]) {
        var allActivity: [tableActivity] = []
        var filteredActivity: [tableActivity] = []

        performRealmRead { realm in
            let results = realm.objects(tableActivity.self)
                .filter(predicate)
                .sorted(byKeyPath: "idActivity", ascending: false)

            allActivity = Array(results.map { tableActivity.init(value: $0) })

            if let filterFileId = filterFileId {
                filteredActivity = allActivity.filter {
                    String($0.objectId) == filterFileId && $0.type != "comments"
                }
            } else {
                filteredActivity = allActivity
            }
        }

        return (all: allActivity, filter: filteredActivity)
    }

    func getActivitySubjectRich(account: String, idActivity: Int, key: String) -> tableActivitySubjectRich? {
        performRealmRead { realm in
            realm.objects(tableActivitySubjectRich.self)
                .filter("account == %@ AND idActivity == %d AND key == %@", account, idActivity, key)
                .first
                .map { .init(value: $0) }
        }
    }

    func getActivitySubjectRich(account: String, idActivity: Int, id: String) -> tableActivitySubjectRich? {
        performRealmRead { realm in
            let results = realm.objects(tableActivitySubjectRich.self)
                .filter("account == %@ && idActivity == %d && id == %@", account, idActivity, id)

            let selected = (results.count == 2) ? results.first(where: { $0.key == "newfile" }) ?? results.first : results.first

            return selected.map { .init(value: $0) }
        }
    }

    func getLatestActivityId(account: String) -> tableActivityLatestId? {
        performRealmRead { realm in
            realm.objects(tableActivityLatestId.self)
                .filter("account == %@", account)
                .first
        }
    }
}
