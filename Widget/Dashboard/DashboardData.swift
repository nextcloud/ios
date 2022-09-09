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

let dashboaardItems = 6

struct DashboardDataEntry: TimelineEntry {
    let date: Date
    let datas: [DashboardData]
    let isPlaceholder: Bool
    let titleImage: UIImage
    let title: String
    let footerImage: String
    let footerText: String
}

struct DashboardData: Identifiable, Hashable {
    let id: Int
    let title: String
    let subTitle: String
    let link: URL
    let icon: UIImage
}

let dashboardDatasTest: [DashboardData] = [
    .init(id: 0, title: "title0", subTitle: "subTitle-description0", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "nextcloud")!),
    .init(id: 1, title: "title1", subTitle: "subTitle-description1", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "nextcloud")!),
    .init(id: 2, title: "title2", subTitle: "subTitle-description2", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "nextcloud")!),
    .init(id: 3, title: "title3", subTitle: "subTitle-description3", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "nextcloud")!),
    .init(id: 4, title: "title4", subTitle: "subTitle-description4", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "nextcloud")!),
    .init(id: 5, title: "title5", subTitle: "subTitle-description5", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "nextcloud")!),
    .init(id: 6, title: "title6", subTitle: "subTitle-description6", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "nextcloud")!),
    .init(id: 7, title: "title7", subTitle: "subTitle-description7", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "nextcloud")!),
    .init(id: 8, title: "title8", subTitle: "subTitle-description8", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "nextcloud")!),
    .init(id: 9, title: "title9", subTitle: "subTitle-description9", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "nextcloud")!)
]

func getDashboardDataEntry(isPreview: Bool, displaySize: CGSize, completion: @escaping (_ entry: DashboardDataEntry) -> Void) {

    let datasPlaceholder = Array(dashboardDatasTest[0...dashboaardItems - 1])
    var title = "Dashboard"
    var titleImage = UIImage(named: "nextcloud")!
    
    if isPreview {
        return completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, titleImage: titleImage, title: title, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " dashboard"))
    }

    guard let account = NCManageDatabase.shared.getActiveAccount() else {
        return completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, titleImage: titleImage, title: title, footerImage: "xmark.icloud", footerText: NSLocalizedString("_no_active_account_", value: "No account found", comment: "")))
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
    
    title = "recommendations"
    
    NextcloudKit.shared.getDashboardWidgetsApplication(title) { account, results, error in
        
        var datas = [DashboardData]()
        
        if let results = results {
            for result in results {
                //let application = dashboardResult.application
                if let entries = result.items {
                    var counter: Int = 0
                    for entry in entries {
                        counter += 1
                        let title = entry.title ?? ""
                        let subtitle = entry.subtitle ?? ""
                        var link = URL(string: "https://")!
                        if let entryLink = entry.link, let url = URL(string: entryLink){
                            link = url
                        }
                        let iconUrl = entry.iconUrl ?? ""
                        let data = DashboardData(id: counter, title: title, subTitle: subtitle, link: link, icon: UIImage(named: "file")!)
                        datas.append(data)
                        if datas.count == dashboaardItems { break}
                    }
                }
            }
        }
        
        if error != .success {
            completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, titleImage: titleImage, title: title, footerImage: "xmark.icloud", footerText: error.errorDescription))
        } else if datas.isEmpty {
            completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, titleImage: titleImage, title: title, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " dashboard"))
        } else {
            completion(DashboardDataEntry(date: Date(), datas: datas, isPlaceholder: false, titleImage: titleImage, title: title, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " dashboard"))
        }
    }
}
