// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud

@Suite("Auto Upload dates shared by legacy and PhotoKit")
@MainActor
struct NCAutoUploadDateTests {
    @Test("A whole-library backup starts without a date filter")
    func wholeLibrary() {
        let account = tableAccount()
        #expect(account.autoUploadSinceDate == nil)
        #expect(account.autoUploadDiscoveryStartDate == nil)
    }

    @Test("Discovery progress does not change the user's selected date")
    func progressPreservesSelection() {
        let account = tableAccount()
        let selectedDate = Date(timeIntervalSince1970: 100)
        let progressDate = Date(timeIntervalSince1970: 200)
        account.autoUploadSinceDate = selectedDate
        account.autoUploadDiscoveryDate = progressDate
        #expect(account.autoUploadDiscoveryStartDate == progressDate)
        #expect(account.autoUploadSinceDate == selectedDate)
    }

    @Test("Recovering older queued work cannot go below the user's cutoff")
    func cutoffProtectsOlderPhotos() {
        let account = tableAccount()
        let selectedDate = Date(timeIntervalSince1970: 200)
        account.autoUploadSinceDate = selectedDate
        account.autoUploadDiscoveryDate = Date(timeIntervalSince1970: 100)
        #expect(account.autoUploadDiscoveryStartDate == selectedDate)
    }

    @Test("A whole-library backup can resume at its earliest unfinished photo")
    func wholeLibraryRecovery() {
        let account = tableAccount()
        let unfinishedDate = Date(timeIntervalSince1970: 100)
        account.autoUploadDiscoveryDate = unfinishedDate
        #expect(account.autoUploadDiscoveryStartDate == unfinishedDate)
        #expect(account.autoUploadSinceDate == nil)
    }

    @Test("Account backup preserves the selected cutoff and discovery progress separately")
    func backupRoundTrip() throws {
        let account = tableAccount()
        account.autoUploadSinceDate = Date(timeIntervalSince1970: 100)
        account.autoUploadDiscoveryDate = Date(timeIntervalSince1970: 200)
        let data = try JSONEncoder().encode(account.tableAccountToCodable())
        let decoded = try JSONDecoder().decode(tableAccountCodable.self, from: data)
        let restored = tableAccount(codableObject: decoded)
        #expect(restored.autoUploadSinceDate == account.autoUploadSinceDate)
        #expect(restored.autoUploadDiscoveryDate == account.autoUploadDiscoveryDate)
    }

    @Test("Old account backups without a discovery date remain readable")
    func oldBackupCompatibility() throws {
        let account = tableAccount()
        account.autoUploadSinceDate = Date(timeIntervalSince1970: 100)
        let data = try JSONEncoder().encode(account.tableAccountToCodable())
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "autoUploadDiscoveryDate")
        let oldData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(tableAccountCodable.self, from: oldData)
        let restored = tableAccount(codableObject: decoded)
        #expect(restored.autoUploadSinceDate == account.autoUploadSinceDate)
        #expect(restored.autoUploadDiscoveryDate == account.autoUploadSinceDate)
    }
}
