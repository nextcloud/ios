// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud

@Suite("Auto Upload incremental date backup compatibility")
@MainActor
struct NCAutoUploadDateTests {
    @Test("Account backup preserves the incremental restart date")
    func backupRoundTrip() throws {
        let account = tableAccount()
        account.autoUploadSinceDate = Date(timeIntervalSince1970: 100)
        let data = try JSONEncoder().encode(account.tableAccountToCodable())
        let decoded = try JSONDecoder().decode(tableAccountCodable.self, from: data)
        #expect(tableAccount(codableObject: decoded).autoUploadSinceDate == account.autoUploadSinceDate)
    }

    @Test("A whole-library selection remains unfiltered after account restore")
    func wholeLibraryRoundTrip() throws {
        let account = tableAccount()
        let data = try JSONEncoder().encode(account.tableAccountToCodable())
        let decoded = try JSONDecoder().decode(tableAccountCodable.self, from: data)
        #expect(tableAccount(codableObject: decoded).autoUploadSinceDate == nil)
    }

    @Test("Backups with the removed discovery field preserve the restart date")
    func removedDiscoveryFieldCompatibility() throws {
        let account = tableAccount()
        account.autoUploadSinceDate = Date(timeIntervalSince1970: 100)
        let data = try JSONEncoder().encode(account.tableAccountToCodable())
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        // An obsolete discovery cursor must not override a user-selected restart date.
        json["autoUploadDiscoveryDate"] = Date(timeIntervalSince1970: 200).timeIntervalSinceReferenceDate
        let oldData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(tableAccountCodable.self, from: oldData)
        #expect(tableAccount(codableObject: decoded).autoUploadSinceDate == account.autoUploadSinceDate)
    }

    @Test("Whole-library selection survives backup with a nonempty progress date")
    func wholeLibrarySelectionWithProgress() throws {
        let account = tableAccount()
        account.autoUploadAllPhotos = true
        account.autoUploadSinceDate = Date(timeIntervalSince1970: 100)
        let data = try JSONEncoder().encode(account.tableAccountToCodable())
        let decoded = try JSONDecoder().decode(tableAccountCodable.self, from: data)
        let restored = tableAccount(codableObject: decoded)
        #expect(restored.autoUploadAllPhotos)
        #expect(restored.autoUploadSinceDate == account.autoUploadSinceDate)
    }

    @Test("Older backups infer the library selection from their existing date")
    func previousBackupSelectionCompatibility() throws {
        let dates: [Date?] = [nil, Date(timeIntervalSince1970: 100)]
        for date in dates {
            let account = tableAccount()
            account.autoUploadSinceDate = date
            let data = try JSONEncoder().encode(account.tableAccountToCodable())
            var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            json.removeValue(forKey: "autoUploadAllPhotos")
            let oldData = try JSONSerialization.data(withJSONObject: json)
            let decoded = try JSONDecoder().decode(tableAccountCodable.self, from: oldData)
            #expect(tableAccount(codableObject: decoded).autoUploadAllPhotos == (date == nil))
        }
    }
}
