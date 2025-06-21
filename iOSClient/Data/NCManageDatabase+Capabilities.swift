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
    func addCapabilitiesAsync(data: Data, account: String) async {
        await performRealmWriteAsync { realm in
            let addObject = tableCapabilities()

            addObject.account = account
            addObject.jsondata = data

            realm.add(addObject, update: .all)
        }
        do {
            _ = try await NextcloudKit.shared.setCapabilitiesAsync(account: account, data: data)
        } catch {
            nkLog(error: "Error storing capabilities JSON in Realm \(error)")
        }
    }

    @discardableResult
    func applyCachedCapabilitiesAsync(account: String) async -> NKCapabilities.Capabilities? {
        let data = await performRealmReadAsync { realm in
            realm.object(ofType: tableCapabilities.self, forPrimaryKey: account)?.jsondata
        }
        if let data {
            do {
                return try await NextcloudKit.shared.setCapabilitiesAsync(account: account, data: data)
            } catch {
                nkLog(error: "Error reading capabilities JSON in Realm \(error)")
            }
        }
        return nil
    }

    /// Synchronously retrieves and parses capabilities JSON from Realm for the given account.
    /// - Important: This blocks the current thread. Do not call from an async context.
    @discardableResult
    public func applyCachedCapabilitiesBlocking(account: String) -> NKCapabilities.Capabilities? {
        var result: NKCapabilities.Capabilities?
        let group = DispatchGroup()

        group.enter()
        Task {
            let data = await performRealmReadAsync { realm in
                realm.object(ofType: tableCapabilities.self, forPrimaryKey: account)?.jsondata
            }

            if let data {
                do {
                    let capabilities = try await NextcloudKit.shared.setCapabilitiesAsync(account: account, data: data)
                    result = capabilities
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
