//
//  LockscreenData.swift
//  Widget
//
//  Created by Marino Faggiana on 13/10/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import WidgetKit
import NextcloudKit

struct LockscreenData: TimelineEntry {
    let date: Date
    let isPlaceholder: Bool
    let activity: String
    let link: URL
    let quotaRelative: Float
    let quotaUsed: String
    let quotaTotal: String
    let error: Bool
}

func getLockscreenDataEntry(configuration: AccountIntent?, isPreview: Bool, family: WidgetFamily, completion: @escaping (_ entry: LockscreenData) -> Void) {
    let utilityFileSystem = NCUtilityFileSystem()
    var activeTableAccount: tableAccount?
    var quotaRelative: Float = 0

    if isPreview {
        return completion(LockscreenData(date: Date(), isPlaceholder: true, activity: "", link: URL(string: "https://")!, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: false))
    }

    let accountIdentifier: String = configuration?.accounts?.identifier ?? "active"
    if accountIdentifier == "active" {
        activeTableAccount = NCManageDatabase.shared.getActiveTableAccount()
    } else {
        activeTableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", accountIdentifier))
    }

    guard let activeTableAccount,
          let capabilities = NCManageDatabase.shared.setCapabilities(account: activeTableAccount.account) else {
        return completion(LockscreenData(date: Date(), isPlaceholder: true, activity: "", link: URL(string: "https://")!, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: false))
    }

    if capabilities.capabilityServerVersionMajor < NCGlobal.shared.nextcloudVersion25 {
        completion(LockscreenData(date: Date(), isPlaceholder: false, activity: NSLocalizedString("_widget_available_nc25_", comment: ""), link: URL(string: "https://")!, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: true))
    }

    // NETWORKING
    let password = NCKeychain().getPassword(account: activeTableAccount.account)

    NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup, delegate: NCNetworking.shared)
    NextcloudKit.shared.appendSession(account: activeTableAccount.account,
                                      urlBase: activeTableAccount.urlBase,
                                      user: activeTableAccount.user,
                                      userId: activeTableAccount.userId,
                                      password: password,
                                      userAgent: userAgent,
                                      nextcloudVersion: capabilities.capabilityServerVersionMajor,
                                      httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                      httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                      httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                      groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

    let options = NKRequestOptions(timeout: 90, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
    if #available(iOSApplicationExtension 16.0, *) {
        if family == .accessoryCircular {
            NextcloudKit.shared.getUserMetadata(account: activeTableAccount.account, userId: activeTableAccount.userId, options: options) { _, userProfile, _, error in
                if error == .success, let userProfile = userProfile {
                    if userProfile.quotaRelative > 0 {
                        quotaRelative = Float(userProfile.quotaRelative) / 100
                    }
                    let quotaUsed: String = utilityFileSystem.transformedSize(userProfile.quotaUsed)
                    var quotaTotal: String = ""

                    switch userProfile.quotaTotal {
                    case -1:
                        quotaTotal = ""
                    case -2:
                        quotaTotal = ""
                    case -3:
                        quotaTotal = ""
                    default:
                        quotaTotal = utilityFileSystem.transformedSize(userProfile.quotaTotal)
                    }
                    completion(LockscreenData(date: Date(), isPlaceholder: false, activity: "", link: URL(string: "https://")!, quotaRelative: quotaRelative, quotaUsed: quotaUsed, quotaTotal: quotaTotal, error: false))
                } else {
                    completion(LockscreenData(date: Date(), isPlaceholder: false, activity: "", link: URL(string: "https://")!, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: true))
                }
            }
        } else if family == .accessoryRectangular {
            NextcloudKit.shared.getDashboardWidgetsApplication("activity", account: activeTableAccount.account, options: options) { _, results, _, error in
                var activity: String = NSLocalizedString("_no_data_available_", comment: "")
                var link = URL(string: "https://")!
                if error == .success, let result = results?.first {
                    if let item = result.items?.first {
                        if let title = item.title {  activity = title }
                        if let itemLink = item.link, let url = URL(string: itemLink) { link = url }
                    }
                    completion(LockscreenData(date: Date(), isPlaceholder: false, activity: activity, link: link, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: false))
                } else {
                    completion(LockscreenData(date: Date(), isPlaceholder: false, activity: "", link: URL(string: "https://")!, quotaRelative: 0, quotaUsed: "", quotaTotal: "", error: true))
                }
            }
        }
    }
}
