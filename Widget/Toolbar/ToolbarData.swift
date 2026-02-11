// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WidgetKit
import NextcloudKit

struct ToolbarDataEntry: TimelineEntry {
    let date: Date
    let isPlaceholder: Bool
    let userId: String
    let url: String
    let account: String
    let footerImage: String
    let footerText: String
}

func getToolbarDataEntry(isPreview: Bool, completion: @escaping (_ entry: ToolbarDataEntry) -> Void) {
    var userId = ""
    var url = ""
    var account = ""
    let versionApp = NCUtility().getVersionMaintenance()

    if let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup),
          let lastVersion = groupDefaults.string(forKey: NCGlobal.shared.udLastVersion),
          lastVersion != versionApp {
        return completion(ToolbarDataEntry(date: Date(), isPlaceholder: true, userId: userId, url: url, account: account, footerImage: "xmark.icloud", footerText: NSLocalizedString("_version_mismatch_error_", comment: "")))
    }

    if isPreview {
        return completion(ToolbarDataEntry(date: Date(), isPlaceholder: true, userId: userId, url: url, account: account, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " toolbar"))
    }

    if let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount() {
        userId = activeTableAccount.userId
        url = activeTableAccount.urlBase
        account = activeTableAccount.account
    }

    if NCManageDatabase.shared.getActiveTableAccount() == nil {
        return completion(ToolbarDataEntry(date: Date(), isPlaceholder: true, userId: userId, url: url, account: account, footerImage: "xmark.icloud", footerText: NSLocalizedString("_no_active_account_", value: "No account found", comment: "")))
    }

    completion(ToolbarDataEntry(date: Date(), isPlaceholder: false, userId: userId, url: url, account: account, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " toolbar"))
}
