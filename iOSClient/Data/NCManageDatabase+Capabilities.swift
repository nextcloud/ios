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
    func addCapabilitiesAsync(data: Data, account: String) async {
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
        do {
            _ = try await NextcloudKit.shared.setCapabilitiesAsync(account: account, data: data)
        } catch {
            nkLog(error: "Error storing capabilities JSON in Realm \(error)")
        }
    }

    /// Stores the raw JSON editors data in Realm associated with an account.
    /// - Parameters:
    ///   - data: The raw JSON data returned from the text editors endpoint.
    ///   - account: The account identifier.
    /// - Throws: Rethrows any error encountered during the Realm write operation.
    func addCapabilitiesEditorsAsync(data: Data, account: String) async {
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
        do {
            _ = try await NextcloudKit.shared.setCapabilitiesAsync(account: account, data: data)
        } catch {
            nkLog(error: "Error storing capabilities JSON in Realm \(error)")
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
    func applyCachedCapabilitiesAsync(account: String) async {
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
                    capabilities = await NKCapabilities.shared.getCapabilitiesAsync(for: account)
                }

                capabilities?.directEditingEditors = editors
                capabilities?.directEditingCreators = creators

                if let updatedCapabilities = capabilities {
                    await NKCapabilities.shared.appendCapabilitiesAsync(for: account, capabilities: updatedCapabilities)
                }
            }
        } catch {
            nkLog(error: "Error reading capabilities JSON in Realm \(error)")
        }

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
                realm.object(ofType: tableCapabilities.self, forPrimaryKey: account)?.capabilities
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
