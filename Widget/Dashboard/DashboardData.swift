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

import UIKit
import WidgetKit
import Intents
import NextcloudKit
import RealmSwift
import SVGKit

struct DashboardDataEntry: TimelineEntry {
    let date: Date
    let datas: [DashboardData]
    let dashboard: tableDashboardWidget?
    let buttons: [tableDashboardWidgetButton]?
    let isPlaceholder: Bool
    let isEmpty: Bool
    let titleImage: UIImage
    let title: String
    let footerImage: String
    let footerText: String
    let account: String
}

struct DashboardData: Identifiable, Hashable {
    let id: Int
    let title: String
    let subTitle: String
    let link: URL
    let icon: UIImage
    let template: Bool
    let avatar: Bool
    let imageColor: UIColor?
}

let dashboardDatasTest: [DashboardData] = [
    .init(id: 0, title: "title0", subTitle: "subTitle-description0", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!, template: true, avatar: false, imageColor: nil),
    .init(id: 1, title: "title1", subTitle: "subTitle-description1", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!, template: true, avatar: false, imageColor: nil),
    .init(id: 2, title: "title2", subTitle: "subTitle-description2", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!, template: true, avatar: false, imageColor: nil),
    .init(id: 3, title: "title3", subTitle: "subTitle-description3", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!, template: true, avatar: false, imageColor: nil),
    .init(id: 4, title: "title4", subTitle: "subTitle-description4", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!, template: true, avatar: false, imageColor: nil),
    .init(id: 5, title: "title5", subTitle: "subTitle-description5", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!, template: true, avatar: false, imageColor: nil),
    .init(id: 6, title: "title6", subTitle: "subTitle-description6", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!, template: true, avatar: false, imageColor: nil),
    .init(id: 7, title: "title7", subTitle: "subTitle-description7", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!, template: true, avatar: false, imageColor: nil),
    .init(id: 8, title: "title8", subTitle: "subTitle-description8", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!, template: true, avatar: false, imageColor: nil),
    .init(id: 9, title: "title9", subTitle: "subTitle-description9", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(named: "widget")!, template: true, avatar: false, imageColor: nil)
]

func getDashboardItems(displaySize: CGSize, withButton: Bool) -> Int {
    if withButton {
        let items = Int((displaySize.height - 90) / 55)
        return items
    } else {
        let items = Int((displaySize.height - 50) / 55)
        return items
    }
}

func convertDataToImage(data: Data?, size: CGSize, fileNameToWrite: String?) -> UIImage? {
    guard let data = data else { return nil }
    var imageData: UIImage?

    if let image = UIImage(data: data), let image = image.resizeImage(size: size) {
        imageData = image
    } else if let image = SVGKImage(data: data) {
        image.size = size
        imageData = image.uiImage
    } else {
        print("error")
    }
    if let fileName = fileNameToWrite, let image = imageData {
        do {
            let fileNamePath: String = NCUtilityFileSystem().directoryUserData + "/" + fileName + ".png"
            try image.pngData()?.write(to: URL(fileURLWithPath: fileNamePath), options: .atomic)
        } catch { }
    }
    return imageData
}

func getDashboardDataEntry(configuration: DashboardIntent?, isPreview: Bool, displaySize: CGSize, completion: @escaping (_ entry: DashboardDataEntry) -> Void) {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let dashboardItems = getDashboardItems(displaySize: displaySize, withButton: false)
    let datasPlaceholder = Array(dashboardDatasTest[0...dashboardItems - 1])
    var activeTableAccount: tableAccount?

    if isPreview {
        return completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, dashboard: nil, buttons: nil, isPlaceholder: true, isEmpty: false, titleImage: UIImage(named: "widget")!, title: "Dashboard", footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " dashboard", account: ""))
    }

    let accountIdentifier: String = configuration?.accounts?.identifier ?? "active"
    if accountIdentifier == "active" {
        activeTableAccount = NCManageDatabase.shared.getActiveTableAccount()
    } else {
        activeTableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", accountIdentifier))
    }

    guard let activeTableAccount else {
        return completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, dashboard: nil, buttons: nil, isPlaceholder: true, isEmpty: false, titleImage: UIImage(named: "widget")!, title: "Dashboard", footerImage: "xmark.icloud", footerText: NSLocalizedString("_no_active_account_", comment: ""), account: ""))
    }

    // Default widget
    let result = NCManageDatabase.shared.getDashboardWidgetApplications(account: activeTableAccount.account).first
    let id: String = configuration?.applications?.identifier ?? (result?.id ?? "recommendations")

    // NETWORKING
    let password = NCKeychain().getPassword(account: activeTableAccount.account)

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

    // LOG
    let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, utility.getVersionApp())

    NextcloudKit.configureLogger(logLevel: (NCBrandOptions.shared.disable_log ? .disabled : NCKeychain().log))

    nkLog(debug: "Start \(NCBrandOptions.shared.brand) dashboard widget session " + versionNextcloudiOS)

    let (tableDashboard, tableButton) = NCManageDatabase.shared.getDashboardWidget(account: activeTableAccount.account, id: id)
    let existsButton = (tableButton?.isEmpty ?? true) ? false : true
    let title = tableDashboard?.title ?? id

    var imagetmp = UIImage(named: "widget")!
    if let fileName = tableDashboard?.iconClass {
        let fileNamePath: String = utilityFileSystem.directoryUserData + "/" + fileName + ".png"
        if let image = UIImage(contentsOfFile: fileNamePath) {
            imagetmp = image.withTintColor(NCBrandColor.shared.iconImageColor, renderingMode: .alwaysOriginal)
        }
    }
    let titleImage = imagetmp

    let options = NKRequestOptions(timeout: 90, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
    NextcloudKit.shared.getDashboardWidgetsApplication(id, account: activeTableAccount.account, options: options) { account, results, responseData, error in
        Task {
            var datas = [DashboardData]()
            var numberItems = 0

            if let results = results {
                for result in results {
                    if let items = result.items {
                        numberItems = result.items?.count ?? 0
                        var counter: Int = 0
                        let dashboardItems = getDashboardItems(displaySize: displaySize, withButton: existsButton)
                        for item in items {
                            counter += 1
                            let title = item.title ?? ""
                            let subtitle = item.subtitle ?? ""
                            var link = URL(string: "https://")!
                            if let entryLink = item.link, let url = URL(string: entryLink) { link = url }
                            var icon = UIImage(named: "file")!
                            var iconFileName: String?

                            var imageTemplate: Bool = false
                            var imageAvatar: Bool = false
                            var imageColorized: Bool = false
                            var imageColor: UIColor?

                            if let iconUrl = item.iconUrl, let url = URL(string: iconUrl) {
                                if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {

                                    let path = (urlComponents.path as NSString)
                                    let pathComponents = path.components(separatedBy: "/")
                                    let queryItems = urlComponents.queryItems

                                    if (pathComponents.last as? NSString)?.pathExtension.lowercased() == "svg" {
                                        imageTemplate = true
                                    }
                                    if let item = queryItems?.filter({ $0.name == "fileId" }).first?.value {
                                        iconFileName = item
                                    } else if pathComponents.contains("avatar") {
                                        iconFileName = pathComponents[pathComponents.count - 2]
                                        imageAvatar = true
                                    } else if pathComponents.contains("getCalendarDotSvg") {
                                        imageColorized = true
                                    } else {
                                        iconFileName = ((path.lastPathComponent) as NSString).deletingPathExtension
                                    }
                                }
                                // Color
                                if imageColorized, let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                                    let path = (urlComponents.path as NSString)
                                    let colorString = ((path.lastPathComponent) as NSString).deletingPathExtension
                                    imageColor = UIColor(hex: colorString)
                                    icon = utility.loadImage(named: "circle.fill")
                                } else if let fileName = iconFileName {
                                    let fileNamePath: String = utilityFileSystem.directoryUserData + "/" + fileName + ".png"
                                    if FileManager().fileExists(atPath: fileNamePath), let image = UIImage(contentsOfFile: fileNamePath) {
                                        icon = image
                                    } else {
                                        let (_, _, error) = await NextcloudKit.shared.downloadPreviewAsync(url: url, account: activeTableAccount.account)
                                        if error == .success,
                                           let data = responseData?.data,
                                           let image = convertDataToImage(data: data, size: NCGlobal.shared.size256, fileNameToWrite: fileName) {
                                            icon = image
                                        }
                                    }
                                }
                            }

                            let data = DashboardData(id: counter, title: title, subTitle: subtitle, link: link, icon: icon, template: imageTemplate, avatar: imageAvatar, imageColor: imageColor)
                            datas.append(data)

                            if datas.count == dashboardItems { break }
                        }
                    }
                }
            }

            var buttons = tableButton
            if numberItems == datas.count, let tableButton = tableButton, tableButton.contains(where: { $0.type == "more"}) {
                buttons = tableButton.filter(({ $0.type != "more" }))
            }

            let alias = (activeTableAccount.alias.isEmpty) ? "" : (" (" + activeTableAccount.alias + ")")
            let footerText = "Dashboard " + NSLocalizedString("_of_", comment: "") + " " + activeTableAccount.displayName + alias

            if error != .success {
                completion(DashboardDataEntry(date: Date(), datas: datasPlaceholder, dashboard: tableDashboard, buttons: buttons, isPlaceholder: true, isEmpty: false, titleImage: titleImage, title: title, footerImage: "xmark.icloud", footerText: error.errorDescription, account: account))
            } else {
                completion(DashboardDataEntry(date: Date(), datas: datas, dashboard: tableDashboard, buttons: buttons, isPlaceholder: false, isEmpty: datas.isEmpty, titleImage: titleImage, title: title, footerImage: "checkmark.icloud", footerText: footerText, account: account))
            }
        }
    }

}
