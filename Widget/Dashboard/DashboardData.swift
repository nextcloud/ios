// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WidgetKit
import Intents
import NextcloudKit
import RealmSwift

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
    let circle: Bool
    let imageSystem: Bool
    let imageColor: UIColor?
}

let dashboardDatasTest: [DashboardData] = [
    .init(id: 0, title: "title0", subTitle: "subTitle-description0", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(systemName: "document")!, circle: false, imageSystem: true, imageColor: nil),
    .init(id: 1, title: "title1", subTitle: "subTitle-description1", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(systemName: "document")!, circle: false, imageSystem: true, imageColor: nil),
    .init(id: 2, title: "title2", subTitle: "subTitle-description2", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(systemName: "document")!, circle: true, imageSystem: false, imageColor: nil),
    .init(id: 3, title: "title3", subTitle: "subTitle-description3", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(systemName: "document")!, circle: false, imageSystem: false, imageColor: nil),
    .init(id: 4, title: "title4", subTitle: "subTitle-description4", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(systemName: "circle.fill")!, circle: false, imageSystem: false, imageColor: nil),
    .init(id: 5, title: "title5", subTitle: "subTitle-description5", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(systemName: "circle.fill")!, circle: false, imageSystem: false, imageColor: nil),
    .init(id: 6, title: "title6", subTitle: "subTitle-description6", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(systemName: "circle.fill")!, circle: false, imageSystem: false, imageColor: nil),
    .init(id: 7, title: "title7", subTitle: "subTitle-description7", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(systemName: "circle.fill")!, circle: false, imageSystem: false, imageColor: nil),
    .init(id: 8, title: "title8", subTitle: "subTitle-description8", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(systemName: "circle.fill")!, circle: false, imageSystem: false, imageColor: nil),
    .init(id: 9, title: "title9", subTitle: "subTitle-description9", link: URL(string: "https://nextcloud.com/")!, icon: UIImage(systemName: "circle.fill")!, circle: false, imageSystem: false, imageColor: nil)
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

func getDashboardDataEntry(configuration: DashboardIntent?, isPreview: Bool, displaySize: CGSize) async -> DashboardDataEntry {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let dashboardItems = getDashboardItems(displaySize: displaySize, withButton: false)
    let datasPlaceholder = Array(dashboardDatasTest[0...dashboardItems - 1])
    var activeTableAccount: tableAccount?
    let versionApp = NCUtility().getVersionMaintenance()

    guard let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup),
          let lastVersion = groupDefaults.string(forKey: NCGlobal.shared.udLastVersion),
          lastVersion == versionApp else {
        return (DashboardDataEntry(date: Date(), datas: datasPlaceholder, dashboard: nil, buttons: nil, isPlaceholder: true, isEmpty: false, titleImage: UIImage(systemName: "circle.fill") ?? UIImage(), title: "Dashboard", footerImage: "checkmark.icloud", footerText: NSLocalizedString("_version_mismatch_error_", comment: ""), account: ""))
    }

    if isPreview,
        let image = UIImage(systemName: "circle.fill") {
        return (DashboardDataEntry(date: Date(), datas: datasPlaceholder, dashboard: nil, buttons: nil, isPlaceholder: true, isEmpty: false, titleImage: image, title: "Dashboard", footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " dashboard", account: ""))
    }

    let accountIdentifier: String = configuration?.accounts?.identifier ?? "active"
    if accountIdentifier == "active" {
        activeTableAccount = NCManageDatabase.shared.getActiveTableAccount()
    } else {
        activeTableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", accountIdentifier))
    }

    guard let activeTableAccount else {
        return (DashboardDataEntry(date: Date(), datas: datasPlaceholder, dashboard: nil, buttons: nil, isPlaceholder: true, isEmpty: false, titleImage: UIImage(systemName: "circle.fill") ?? UIImage(), title: "Dashboard", footerImage: "xmark.icloud", footerText: NSLocalizedString("_no_active_account_", comment: ""), account: ""))
    }
    NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup, delegate: NCNetworking.shared)
    NextcloudKit.shared.appendSession(account: activeTableAccount.account,
                                      urlBase: activeTableAccount.urlBase,
                                      user: activeTableAccount.user,
                                      userId: activeTableAccount.userId,
                                      password: NCPreferences().getPassword(account: activeTableAccount.account),
                                      userAgent: userAgent,
                                      httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                      httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                      httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                      groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

    // LOG
    let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, utility.getVersionBuild())
    NextcloudKit.configureLogger(logLevel: (NCBrandOptions.shared.disable_log ? .disabled : NCPreferences().log))
    nkLog(debug: "Start \(NCBrandOptions.shared.brand) dashboard widget session " + versionNextcloudiOS)

    // Widget
    let widgetApplication = NCManageDatabase.shared.getDashboardWidgetApplications(account: activeTableAccount.account).first
    let widgetApplicationId: String = configuration?.applications?.identifier ?? (widgetApplication?.id ?? "recommendations")

    let (tableDashboard, tableButton) = NCManageDatabase.shared.getDashboardWidget(account: activeTableAccount.account, id: widgetApplicationId)
    let existsButton = (tableButton?.isEmpty ?? true) ? false : true
    let title = tableDashboard?.title ?? widgetApplicationId

    var titleImage: UIImage = UIImage(systemName: "circle.fill") ?? UIImage()
    if let fileName = tableDashboard?.iconClass {
        let fileNamePath: String = utilityFileSystem.createServerUrl(serverUrl: utilityFileSystem.directoryUserData, fileName: fileName + ".png")
        if let image = UIImage(contentsOfFile: fileNamePath) {
            titleImage = image.withTintColor(NCBrandColor.shared.iconImageColor, renderingMode: .alwaysOriginal)
        }
    }
    let options = NKRequestOptions(timeout: 90, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
    let resultsDashboardWidget = await NextcloudKit.shared.getDashboardWidgetsApplicationAsync(widgetApplicationId, account: activeTableAccount.account, options: options)

    var datas = [DashboardData]()
    var numberItems = 0

    if resultsDashboardWidget.error == .success,
       let dashboardApplications = resultsDashboardWidget.dashboardApplications {
        for dashboardApplication in dashboardApplications {
            if let items = dashboardApplication.items {
                numberItems = dashboardApplication.items?.count ?? 0
                var counter: Int = 0
                let dashboardItems = getDashboardItems(displaySize: displaySize, withButton: existsButton)
                for item in items {
                    counter += 1

                    let title = item.title ?? ""
                    let subtitle = item.subtitle ?? ""

                    var link: URL = URL(string: "https://")!
                    if let entryLink = item.link,
                        let url = URL(string: entryLink) {
                        link = url
                    }
                    var iconImage = UIImage(systemName: "document") ?? UIImage()
                    var imageCircle: Bool = false
                    var imageColorized: Bool = false
                    var imageSystem: Bool = false
                    var imageColor: UIColor?

                    if let iconUrl = item.iconUrl, let url = URL(string: iconUrl) {
                        if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                            let path = (urlComponents.path as NSString)
                            let pathComponents = path.components(separatedBy: "/")

                            if pathComponents.contains("avatar") {
                                imageCircle = true
                            } else if pathComponents.contains("getCalendarDotSvg") {
                                imageColorized = true
                            }
                        }
                        // Color
                        if imageColorized, let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                            let path = (urlComponents.path as NSString)
                            let colorString = ((path.lastPathComponent) as NSString).deletingPathExtension
                            imageColor = UIColor(hex: colorString)
                        } else {
                            let results = await NextcloudKit.shared.downloadPreviewAsync(url: url, account: activeTableAccount.account)
                            if results.error == .success,
                               let data = results.responseData?.data {
                                if let image = UIImage(data: data) {
                                    iconImage = image
                                } else {
                                    imageSystem = true
                                }
                                /* NO MEMORY
                                else if let image = try? await NCSVGRenderer().renderSVGToUIImage(svgData: data) {
                                    iconImage = image
                                }
                                */
                            }
                        }
                    }

                    let data = DashboardData(id: counter, title: title, subTitle: subtitle, link: link, icon: iconImage, circle: imageCircle, imageSystem: imageSystem, imageColor: imageColor)
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

    if resultsDashboardWidget.error != .success {
        return(DashboardDataEntry(date: Date(), datas: datasPlaceholder, dashboard: tableDashboard, buttons: buttons, isPlaceholder: true, isEmpty: false, titleImage: titleImage, title: title, footerImage: "xmark.icloud", footerText: resultsDashboardWidget.error.errorDescription, account: activeTableAccount.account))
    } else {
        return(DashboardDataEntry(date: Date(), datas: datas, dashboard: tableDashboard, buttons: buttons, isPlaceholder: false, isEmpty: datas.isEmpty, titleImage: titleImage, title: title, footerImage: "checkmark.icloud", footerText: footerText, account: activeTableAccount.account))
    }
}
