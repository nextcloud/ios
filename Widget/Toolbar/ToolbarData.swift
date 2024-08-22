//
//  ToolbarData.swift
//  Widget
//
//  Created by Marino Faggiana on 25/08/22.
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

    if let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount() {
        userId = activeTableAccount.userId
        url = activeTableAccount.urlBase
        account = activeTableAccount.account
    }

    if isPreview {
        return completion(ToolbarDataEntry(date: Date(), isPlaceholder: true, userId: userId, url: url, account: account, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " toolbar"))
    }

    if NCManageDatabase.shared.getActiveTableAccount() == nil {
        return completion(ToolbarDataEntry(date: Date(), isPlaceholder: true, userId: userId, url: url, account: account, footerImage: "xmark.icloud", footerText: NSLocalizedString("_no_active_account_", value: "No account found", comment: "")))
    }

    completion(ToolbarDataEntry(date: Date(), isPlaceholder: false, userId: userId, url: url, account: account, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " toolbar"))
}
