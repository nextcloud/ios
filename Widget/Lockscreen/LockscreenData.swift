// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WidgetKit
import NextcloudKit

struct LockscreenData: TimelineEntry {
    let date: Date
    let isPlaceholder: Bool
    let activity: String
    let link: URL?
    let quotaRelative: Double
    let quotaUsed: String
    let quotaTotal: String
    let error: Bool
    var quotaTotalAccessibilityLabel: String?
}

func getLockscreenDataEntry(configuration: AccountIntent?, family: WidgetFamily, completion: @escaping (_ entry: LockscreenData) -> Void) {
    let utilityFileSystem = NCUtilityFileSystem()
    var activeTableAccount: tableAccount?
    let versionApp = NCUtility().getVersionMaintenance()

    if let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup),
          let lastVersion = groupDefaults.string(forKey: NCGlobal.shared.udLastVersion),
          lastVersion != versionApp {
        return completion(LockscreenData(date: Date(), isPlaceholder: true, activity: "", link: nil, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: false))
    }

    let accountIdentifier: String = configuration?.accounts?.identifier ?? "active"
    if accountIdentifier == "active" {
        activeTableAccount = NCManageDatabase.shared.getActiveTableAccount()
    } else {
        activeTableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", accountIdentifier))
    }

    guard let activeTableAccount else {
        return completion(LockscreenData(date: Date(), isPlaceholder: true, activity: "", link: nil, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: false))
    }

    // NETWORKING
    let password = NCPreferences().getPassword(account: activeTableAccount.account)

    NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup, delegate: NCNetworking.shared)
    NextcloudKit.shared.appendSession(account: activeTableAccount.account,
                                      urlBase: activeTableAccount.urlBase,
                                      user: activeTableAccount.user,
                                      userId: activeTableAccount.userId,
                                      password: password,
                                      userAgent: userAgent,
                                      httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                      httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                      httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                      groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

    let options = NKRequestOptions(timeout: 90, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

    if family == .accessoryCircular {
        NextcloudKit.shared.getUserMetadata(account: activeTableAccount.account, userId: activeTableAccount.userId, options: options) { _, userProfile, _, error in
            guard error == .success, let userProfile else {
                completion(LockscreenData(date: Date(), isPlaceholder: false, activity: "", link: nil, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: true))
                return
            }

            let percentage = userProfile.quotaRelative
            let total = userProfile.quotaTotal
            let progress = total > 0 && percentage.isFinite ? min(max(percentage / 100, 0), 1) : 0
            let quotaUsed = utilityFileSystem.transformedSize(userProfile.quotaUsed)
            let quotaTotal: String
            let quotaTotalAccessibilityLabel: String?

            switch total {
            case -3:
                quotaTotal = "∞"
                quotaTotalAccessibilityLabel = NSLocalizedString("_quota_space_unlimited_", comment: "")
            case -1:
                quotaTotal = utilityFileSystem.transformedSize(0)
                quotaTotalAccessibilityLabel = nil
            case ..<0:
                quotaTotal = "—"
                quotaTotalAccessibilityLabel = NSLocalizedString("_quota_space_unknown_", comment: "")
            default:
                quotaTotal = utilityFileSystem.transformedSize(total)
                quotaTotalAccessibilityLabel = nil
            }

            completion(LockscreenData(date: Date(),
                                      isPlaceholder: false,
                                      activity: "",
                                      link: nil,
                                      quotaRelative: progress,
                                      quotaUsed: quotaUsed,
                                      quotaTotal: quotaTotal,
                                      error: false,
                                      quotaTotalAccessibilityLabel: quotaTotalAccessibilityLabel))
        }
    } else if family == .accessoryRectangular {
        let baseURL = URL(string: activeTableAccount.urlBase)
        NextcloudKit.shared.getDashboardWidgetsApplication("activity", account: activeTableAccount.account, options: options) { _, results, _, error in
            guard error == .success else {
                completion(LockscreenData(date: Date(), isPlaceholder: false, activity: "", link: nil, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: true))
                return
            }

            let item = results?.first(where: { $0.application == "activity" })?.items?.first
            let activity = item?.title ?? NSLocalizedString("_no_data_available_", comment: "")
            let link = activityURL(item?.link, relativeTo: baseURL)
            completion(LockscreenData(date: Date(), isPlaceholder: false, activity: activity, link: link, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: false))
        }
    } else {
        completion(LockscreenData(date: Date(), isPlaceholder: true, activity: "", link: nil, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: false))
    }
}

private func activityURL(_ value: String?, relativeTo baseURL: URL?) -> URL? {
    guard let value, !value.isEmpty else { return nil }
    let url = value.hasPrefix("/") ? URL(string: value, relativeTo: baseURL)?.absoluteURL : URL(string: value)
    guard let url, let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          let host = url.host, !host.isEmpty else { return nil }
    return url
}
