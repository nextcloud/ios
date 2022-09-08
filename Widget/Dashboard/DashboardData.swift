//
//  DashboardData.swift
//  Widget
//
//  Created by Marino Faggiana on 20/08/22.
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
import NextcloudKit

let dashboaardItems = 4

struct DashboardDataEntry: TimelineEntry {
    let date: Date
    let datas: [DashboardData]
    let isPlaceholder: Bool
    let title: String
    let footerImage: String
    let footerText: String
}

struct DashboardData: Identifiable, Hashable {
    var id: String
    var image: UIImage
    var title: String
    var subTitle: String
    var url: URL
}

let dashboardDatasTest: [DashboardData] = [
    .init(id: "1", image: UIImage(named: "nextcloud")!, title: "title1", subTitle: "subTitle-description1", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "2", image: UIImage(named: "nextcloud")!, title: "title2", subTitle: "subTitle-description2", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "3", image: UIImage(named: "nextcloud")!, title: "title3", subTitle: "subTitle-description3", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "4", image: UIImage(named: "nextcloud")!, title: "title4", subTitle: "subTitle-description4", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "5", image: UIImage(named: "nextcloud")!, title: "title5", subTitle: "subTitle-description5", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "6", image: UIImage(named: "nextcloud")!, title: "title6", subTitle: "subTitle-description6", url: URL(string: "https://nextcloud.com/")!)
]

func getTitleDashboard() -> String {

    let hour = Calendar.current.component(.hour, from: Date())
    var good = ""

    switch hour {
    case 6..<12: good = NSLocalizedString("_good_morning_", value: "Good morning", comment: "")
    case 12: good = NSLocalizedString("_good_noon_", value: "Good noon", comment: "")
    case 13..<17: good = NSLocalizedString("_good_afternoon_", value: "Good afternoon", comment: "")
    case 17..<22: good = NSLocalizedString("_good_evening_", value: "Good evening", comment: "")
    default: good = NSLocalizedString("_good_night_", value: "Good night", comment: "")
    }

    if let account = NCManageDatabase.shared.getActiveAccount() {
        return good + ", " + account.displayName
    } else {
        return good
    }
}

func getDashboardDataEntry(isPreview: Bool, displaySize: CGSize, completion: @escaping (_ entry: DashboardDataEntry) -> Void) {

    let datasPlaceholder = Array(dashboardDatasTest[0...dashboaardItems - 1])
    
    if isPreview {
        return completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, title: getTitleDashboard(), footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " dashboard"))
    }

    guard let account = NCManageDatabase.shared.getActiveAccount() else {
        return completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, title: getTitleDashboard(), footerImage: "xmark.icloud", footerText: NSLocalizedString("_no_active_account_", value: "No account found", comment: "")))
    }
    
    // NETWORKING
    let password = CCUtility.getPassword(account.account)!
    NKCommon.shared.setup(
        account: account.account,
        user: account.user,
        userId: account.userId,
        password: password,
        urlBase: account.urlBase,
        userAgent: CCUtility.getUserAgent(),
        nextcloudVersion: 0,
        delegate: NCNetworking.shared)

    // LOG
    let levelLog = CCUtility.getLogLevel()
    let isSimulatorOrTestFlight = NCUtility.shared.isSimulatorOrTestFlight()
    let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, NCUtility.shared.getVersionApp())

    NKCommon.shared.levelLog = levelLog
    if let pathDirectoryGroup = CCUtility.getDirectoryGroup()?.path {
        NKCommon.shared.pathLog = pathDirectoryGroup
    }
    if isSimulatorOrTestFlight {
        NKCommon.shared.writeLog("Start \(NCBrandOptions.shared.brand) dashboard widget session with level \(levelLog) " + versionNextcloudiOS + " (Simulator / TestFlight)")
    } else {
        NKCommon.shared.writeLog("Start \(NCBrandOptions.shared.brand) dashboard widget session with level \(levelLog) " + versionNextcloudiOS)
    }
    
    let datas = [DashboardData]()
    
    completion(DashboardDataEntry(date: Date(), datas: datas, isPlaceholder: false, title: getTitleDashboard(), footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " dashboard"))
    
}
