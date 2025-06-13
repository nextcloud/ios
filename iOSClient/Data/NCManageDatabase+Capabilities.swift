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

    @discardableResult
    func setNKCapabilitiesAsync(account: String) async -> NCCapabilities.Capabilities? {
        let data = await performRealmReadAsync { realm in
            realm.object(ofType: tableCapabilities.self, forPrimaryKey: account)?.jsondata
        }
        do {
            return try await NextcloudKit.shared.setCapabilitiesAsync(account: account, data: data)
        } catch {
        }

        return nil
    }

    /// Synchronously retrieves and parses capabilities JSON from Realm for the given account.
    /// - Important: This blocks the current thread. Do not call from an async context.
    @discardableResult
    public func setNKCapabilitiesBlocking(account: String) -> NCCapabilities.Capabilities? {
        var result: NCCapabilities.Capabilities?
        let group = DispatchGroup()

        group.enter()
        Task {
            let data = await performRealmReadAsync { realm in
                realm.object(ofType: tableCapabilities.self, forPrimaryKey: account)?.jsondata
            }

            if let data {
                do {
                    let caps = try await NextcloudKit.shared.setCapabilitiesAsync(account: account, data: data)
                    result = caps
                } catch {
                    nkLog(debug: "Error decoding capabilities from JSON: \(error)")
                }
            }

            group.leave()
        }
        group.wait()
        return result
    }
}
