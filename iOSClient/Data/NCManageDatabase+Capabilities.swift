// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

extension NCManageDatabase {

    // MARK: - Realm write

    /// Stores the raw JSON capabilities in Realm associated with an account.
    /// - Parameters:
    ///   - data: The raw JSON data returned from the capabilities endpoint.
    ///   - account: The account identifier.
    /// - Throws: Rethrows any error encountered during the Realm write operation.
    func setDataCapabilities(data: Data, account: String) async {
        await core.performRealmWriteAsync { realm in
            let object = realm.object(ofType: tableCapabilities.self, forPrimaryKey: account)
            let addObject: tableCapabilities

            if let existing = object {
                addObject = existing
            } else {
                let newObject = tableCapabilities()
                newObject.account = account
                addObject = newObject
            }

            addObject.capabilities = data

            realm.add(addObject, update: .all)
        }
    }

    /// Stores the raw Direct Editing capabilities JSON in Realm for an account.
    /// - Parameters:
    ///   - data: The raw JSON data returned from the Direct Editing capabilities endpoint, or `nil` to clear it.
    ///   - account: The account identifier.
    func setDataDirectEditingCapabilities(data: Data?, account: String) async {
        await core.performRealmWriteAsync { realm in
            let object = realm.object(ofType: tableCapabilities.self, forPrimaryKey: account)
            let addObject: tableCapabilities

            if let existing = object {
                addObject = existing
            } else {
                let newObject = tableCapabilities()
                newObject.account = account
                addObject = newObject
            }

            addObject.editors = data

            realm.add(addObject, update: .all)
        }
    }

    /// Applies cached server and Direct Editing capabilities for an account.
    ///
    /// The standard capabilities response includes Richdocuments legacy capabilities. The separately
    /// cached Direct Editing response provides `directEditingEditors` and `directEditingCreators`.
    ///
    /// - Parameter account: The identifier of the account whose cached capabilities should be applied.
    @discardableResult
    func getCapabilities(account: String) async -> NKCapabilities.Capabilities? {
        let results = await core.performRealmReadAsync { realm in
            realm.object(ofType: tableCapabilities.self, forPrimaryKey: account)
                .map { tableCapabilities(value: $0) }
        }
        var capabilities: NKCapabilities.Capabilities?

        do {
            if let data = results?.capabilities {
                capabilities = try await NextcloudKit.shared.setCapabilitiesAsync(account: account, data: data)
            }
            // `editors` is the legacy Realm field name used to persist Direct Editing capabilities.
            if let directEditingData = results?.editors {
                let (editors, creators) = try NKDirectEditingCapabilitiesConverter.from(data: directEditingData)

                if capabilities == nil {
                    capabilities = await NKCapabilities.shared.getCapabilities(for: account)
                }

                capabilities?.directEditingEditors = editors
                capabilities?.directEditingCreators = creators

                if let capabilities {
                    await NKCapabilities.shared.setCapabilities(for: account, capabilities: capabilities)
                }
            }
        } catch {
            nkLog(error: "Error reading capabilities JSON in Realm \(error)")
        }

        // use Networking
        NCNetworking.shared.capabilities[account] = capabilities

        return capabilities
    }
}
