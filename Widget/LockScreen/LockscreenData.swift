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

import WidgetKit

struct LockscreenData: TimelineEntry {
    let date: Date
    let isPlaceholder: Bool
    let displayName: String
    let quotaRelative: Float
    let quotaUsed: String
    let quotaTotal: String
}

func getLockscreenDataEntry(isPreview: Bool, completion: @escaping (_ entry: LockscreenData) -> Void) {

    if isPreview {
        return completion(LockscreenData(date: Date(), isPlaceholder: true, displayName: "", quotaRelative: 0, quotaUsed: "", quotaTotal: ""))
    }

    guard let account = NCManageDatabase.shared.getActiveAccount() else {
        return completion(LockscreenData(date: Date(), isPlaceholder: true, displayName: "", quotaRelative: 0, quotaUsed: "", quotaTotal: ""))
    }

    var quotaRelative: Float = 0
    if account.quotaRelative > 0 {
        quotaRelative = Float(account.quotaRelative) / 100
    }
    let quotaUsed: String = CCUtility.transformedSize(account.quotaUsed)
    var quotaTotal: String = ""

    switch account.quotaTotal {
    case -1:
        quotaTotal = ""
    case -2:
        quotaTotal = ""
    case -3:
        quotaTotal = ""
    default:
        quotaTotal = CCUtility.transformedSize(account.quotaTotal)
    }

    completion(LockscreenData(date: Date(), isPlaceholder: false, displayName: account.displayName, quotaRelative: quotaRelative, quotaUsed: quotaUsed, quotaTotal: quotaTotal))
}
