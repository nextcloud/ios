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
import Queuer
import RealmSwift

let dashboaardItems = 5

struct DashboardDataEntry: TimelineEntry {
    let date: Date
    let datas: [DashboardData]
    let tableDashboard: tableDashboardWidget?
    let tableButton: Results<tableDashboardWidgetButton>?
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

struct DashboardDataButton: Hashable {
    let type: String
    let Text: String
    let link: String
}

let dashboardDatasTest: [DashboardData] = [
    .init(id: 0, title: "title0", subTitle: "subTitle-description0", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!),
    .init(id: 1, title: "title1", subTitle: "subTitle-description1", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!),
    .init(id: 2, title: "title2", subTitle: "subTitle-description2", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!),
    .init(id: 3, title: "title3", subTitle: "subTitle-description3", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!),
    .init(id: 4, title: "title4", subTitle: "subTitle-description4", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!),
    .init(id: 5, title: "title5", subTitle: "subTitle-description5", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!),
    .init(id: 6, title: "title6", subTitle: "subTitle-description6", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!),
    .init(id: 7, title: "title7", subTitle: "subTitle-description7", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!),
    .init(id: 8, title: "title8", subTitle: "subTitle-description8", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!),
    .init(id: 9, title: "title9", subTitle: "subTitle-description9", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!)
]

func getDashboardDataEntry(intent: Applications, isPreview: Bool, displaySize: CGSize, completion: @escaping (_ entry: DashboardDataEntry) -> Void) {

    let datasPlaceholder = Array(dashboardDatasTest[0...dashboaardItems - 1])
    var id = "recommendations"
    switch intent {
    case .unknown:
        id = "recommendations"
    case .notes:
        id = "notes"
    case .deck:
        id = "deck"
    case .recommendations:
        id = "recommendations"
    case .activity:
        id = "activity"
    case .user_status:
        id = "user_status"
    }
    
    if isPreview {
        return completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, tableDashboard: nil, tableButton: nil, isPlaceholder: true, titleImage: UIImage(named: "widget")!, title: "Dashboard", footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " dashboard"))
    }

    guard let account = NCManageDatabase.shared.getActiveAccount() else {
        return completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, tableDashboard: nil, tableButton: nil, isPlaceholder: true, titleImage: UIImage(named: "widget")!, title: "Dashboard", footerImage: "xmark.icloud", footerText: NSLocalizedString("_no_active_account_", value: "No account found", comment: "")))
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
    
    let (tableDashboard, tableButton) = NCManageDatabase.shared.getDashboardWidget(account: account.account, id: id)
    let existsButton: Int = tableButton == nil ? 0 : 1
    let options = NKRequestOptions(queue: NKCommon.shared.backgroundQueue)
    let title = tableDashboard?.title ?? id
    var titleImage = UIImage(named: "widget")!

    if let fileName = tableDashboard?.iconClass {
        let fileNamePath: String = CCUtility.getDirectoryUserData() + "/" + fileName + ".png"
        if let image = UIImage(contentsOfFile: fileNamePath) {
            titleImage = image.imageColor(NCBrandColor.shared.label)
        }
    }
        
    NextcloudKit.shared.getDashboardWidgetsApplication(id, options: options) { account, results, data, error in
        
        var datas = [DashboardData]()
        
        if let results = results {
            for result in results {
                if let items = result.items {
                    var counter: Int = 0
                    let maxCounter = dashboaardItems - existsButton
                    for item in items {
                        counter += 1
                        let title = item.title ?? ""
                        let subtitle = item.subtitle ?? ""
                        var link = URL(string: "https://")!
                        if let entryLink = item.link, let url = URL(string: entryLink){ link = url }
                        var icon = UIImage(named: "file")!
                        var iconFileName: String?

                        if let iconUrl = item.iconUrl, let url = URL(string: iconUrl) {
                            if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                                let queryItems = urlComponents.queryItems
                                if let item = CCUtility.value(forKey: "fileId", fromQueryItems: queryItems) {
                                    iconFileName = item
                                } else {
                                    let path = (urlComponents.path as NSString)
                                    iconFileName = ((path.lastPathComponent) as NSString).deletingPathExtension
                                }
                            }
                            let semaphore = Semaphore()
                            NCUtility.shared.getImageUserData(url: url, fileName: iconFileName , size: 128) { image in
                                if let image = image {
                                    icon = image
                                }
                                semaphore.continue()
                            }
                            semaphore.wait()
                        }
                        
                        let data = DashboardData(id: counter, title: title, subTitle: subtitle, link: link, icon: icon)
                        datas.append(data)
                        
                        if datas.count == maxCounter { break }
                    }
                }
            }
        }
        
        if error != .success {
            completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, tableDashboard: tableDashboard, tableButton: tableButton, isPlaceholder: true, titleImage: titleImage, title: title, footerImage: "xmark.icloud", footerText: error.errorDescription))
        } else if datas.isEmpty {
            completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, tableDashboard: tableDashboard, tableButton: tableButton, isPlaceholder: true, titleImage: titleImage, title: title, footerImage: "checkmark.icloud", footerText: NSLocalizedString("_no_data_available_", comment: "")))
        } else {
            completion(DashboardDataEntry(date: Date(), datas: datas, tableDashboard: tableDashboard, tableButton: tableButton, isPlaceholder: false, titleImage: titleImage, title: title, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " dashboard"))
        }
    }
}
