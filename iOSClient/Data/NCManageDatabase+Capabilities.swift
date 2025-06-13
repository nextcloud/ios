// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableCapabilities: Object {
    @objc dynamic var account = ""
    @objc dynamic var jsondata: Data?

    override static func primaryKey() -> String {
        return "account"
    }
}

extension NCManageDatabase {

    // MARK: - Realm write

    /// Stores the raw JSON capabilities in Realm associated with an account.
    /// - Parameters:
    ///   - data: The raw JSON data returned from the capabilities endpoint.
    ///   - account: The account identifier.
    /// - Throws: Rethrows any error encountered during the Realm write operation.
    func addCapabilitiesJSONAsync(data: Data, account: String) async {
        await performRealmWriteAsync { realm in
            let addObject = tableCapabilities()

            addObject.account = account
            addObject.jsondata = data

            realm.add(addObject, update: .all)
        }
    }

    func getCapabilitiesJSONAsync(account: String) async -> NCCapabilities.Capabilities? {
        let data = await performRealmReadAsync { realm in
            realm.object(ofType: tableCapabilities.self, forPrimaryKey: account)?.jsondata
        }
        do {
            return try await NextcloudKit.shared.setCapabilitiesAsync(account: account, data: data)
        } catch {
        }

        return nil
    }
}
