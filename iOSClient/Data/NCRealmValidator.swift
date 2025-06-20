// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import RealmSwift

enum NCRealmError: Error, CustomStringConvertible {
    case missingDatabase
    case unreadableRealm
    case invalidSchema(missingClasses: [String])

    var description: String {
        switch self {
        case .missingDatabase:
            return "Realm file is missing in App Group directory."
        case .unreadableRealm:
            return "Unable to open Realm in readonly mode."
        case .invalidSchema(let missing):
            return "Realm schema is invalid. Missing types: \(missing.joined(separator: ", "))"
        }
    }
}

// MARK: - Realm validator for App Extensions

final class NCRealmValidator {
    /// Opens Realm in readonly mode and validates schema against the expected object types.
    /// - Parameters:
    ///   - expectedTypes: All the Object subclasses expected in this Realm schema.
    /// - Returns: A valid, readonly Realm instance.
    /// - Throws: `NCRealmError` if the Realm is missing, unreadable, or has incomplete schema.
    static func openValidatedReadonlyRealm(expectedTypes: [Object.Type]) throws -> Realm {
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

        guard let databaseFileUrlPath = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName) else {
            throw NCRealmError.missingDatabase
        }

        guard FileManager.default.fileExists(atPath: databaseFileUrlPath.path) else {
            throw NCRealmError.missingDatabase
        }

        let config = Realm.Configuration(fileURL: databaseFileUrlPath, readOnly: true, schemaVersion: databaseSchemaVersion)

        guard let realm = try? Realm(configuration: config) else {
            throw NCRealmError.unreadableRealm
        }

        let existingSchema = Set(realm.schema.objectSchema.map(\.className))
        let requiredSchema = Set(expectedTypes.map { $0.className() })
        let missing = requiredSchema.subtracting(existingSchema)

        if !missing.isEmpty {
            throw NCRealmError.invalidSchema(missingClasses: Array(missing).sorted())
        }

        return realm
    }
}
