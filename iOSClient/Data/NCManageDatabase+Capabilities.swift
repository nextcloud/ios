// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableCapabilities: Object {
    @Persisted(primaryKey: true) var account = ""
    @Persisted var capabilities: Data?
    @Persisted var editors: Data?
}

extension NCManageDatabase {

    // MARK: - Realm write

    /// Stores the raw JSON capabilities in Realm associated with an account.
    /// - Parameters:
    ///   - data: The raw JSON data returned from the capabilities endpoint.
    ///   - account: The account identifier.
    /// - Throws: Rethrows any error encountered during the Realm write operation.
    func setDataCapabilities(data: Data, account: String) async {
        await performRealmWriteAsync { realm in
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

    /// Stores the raw JSON editors data in Realm associated with an account.
    /// - Parameters:
    ///   - data: The raw JSON data returned from the text editors endpoint.
    ///   - account: The account identifier.
    /// - Throws: Rethrows any error encountered during the Realm write operation.
    func setDataCapabilitiesEditors(data: Data, account: String) async {
        await performRealmWriteAsync { realm in
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

    /// Applies cached capabilities and editors from Realm for a given account.
    ///
    /// This function reads the cached `capabilities` and `editors` JSON `Data`
    /// from the local Realm `tableCapabilities` object associated with the specified account.
    ///
    /// - If `capabilities` is found, it is applied using `NextcloudKit.shared.setCapabilitiesAsync`.
    /// - If `editors` is found, the data is decoded via `NKEditorDetailsConverter` into
    ///   `[NKEditorDetailsEditor]` and `[NKEditorDetailsCreator]`, then injected into the shared `NKCapabilities` object.
    ///
    /// The combined updated capabilities are then re-appended via `appendCapabilitiesAsync`.
    /// Errors during decoding or async storage are caught and logged.
    ///
    /// - Parameter account: The identifier of the account whose cached capabilities should be applied.
    @discardableResult
    func getCapabilities(account: String) async -> NKCapabilities.Capabilities? {
        let results = await performRealmReadAsync { realm in
            realm.object(ofType: tableCapabilities.self, forPrimaryKey: account)
                .map { tableCapabilities(value: $0) }
        }
        var capabilities: NKCapabilities.Capabilities?

        do {
            if let data = results?.capabilities {
                capabilities = try await NextcloudKit.shared.setCapabilitiesAsync(account: account, data: data)
            }
            if let data = results?.editors {
                let (editors, creators) = try NKEditorDetailsConverter.from(data: data)

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
