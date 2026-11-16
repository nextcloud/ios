// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WidgetKit
import Intents
import NextcloudKit

struct DashboardDataEntry: TimelineEntry {
    let date: Date
    let rows: [DashboardData]
    let totalRows: Int
    let buttons: [DashboardAction]
    let webURL: URL?
    let isPlaceholder: Bool
    let allowsRefresh: Bool
    let titleImage: UIImage
    let title: String
    let footerImage: String
    let footerText: String
}

struct DashboardData: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let link: URL?
    let icon: UIImage?
    let isRound: Bool
    let calendarColor: UIColor?
}

struct DashboardAction: Identifiable, Sendable {
    let id: String
    let title: String
    let url: URL
    let isMore: Bool
}

private struct DashboardModuleItem: Decodable {
    let title: String?
    let subtitle: String?
    let link: String?
    let iconUrl: String?
}

private struct DashboardItemsResponse: Decodable {
    struct OCS: Decodable {
        struct Meta: Decodable {
            let statuscode: Int
            let message: String?
        }

        struct Module: Decodable {
            let items: [DashboardModuleItem]
        }

        let meta: Meta
        let data: [String: Module]

        private enum CodingKeys: String, CodingKey {
            case meta, data
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            meta = try container.decode(Meta.self, forKey: .meta)
            if !(200..<300).contains(meta.statuscode) {
                data = [:]
            } else if let modules = try? container.decode([Module].self, forKey: .data), modules.isEmpty {
                // OCS may encode an empty module map as a JSON array.
                data = [:]
            } else {
                data = try container.decode([String: Module].self, forKey: .data)
            }
        }
    }

    let ocs: OCS
}

func dashboardPlaceholder(height: CGFloat,
                          title: String = "Dashboard",
                          titleImage: UIImage? = UIImage(systemName: "rectangle.grid.2x2"),
                          footerText: String = NCBrandOptions.shared.brand,
                          isError: Bool = false) -> DashboardDataEntry {
    let count = DashboardWidgetLayout.rowCount(for: height, hasActions: false)
    let rows = (0..<count).map { index in
        DashboardData(id: index,
                      title: "Nextcloud Dashboard",
                      subtitle: "Recent activity",
                      link: nil,
                      icon: nil,
                      isRound: false,
                      calendarColor: nil)
    }
    return DashboardDataEntry(date: Date(),
                              rows: rows,
                              totalRows: count,
                              buttons: [],
                              webURL: nil,
                              isPlaceholder: true,
                              allowsRefresh: isError,
                              titleImage: titleImage ?? UIImage(),
                              title: title,
                              footerImage: isError ? "xmark.icloud" : "checkmark.icloud",
                              footerText: footerText)
}

func getDashboardDataEntry(configuration: DashboardIntent, displaySize: CGSize) async -> DashboardDataEntry {
    let height = displaySize.height
    let utility = NCUtility()

    guard let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup),
          groupDefaults.string(forKey: NCGlobal.shared.udLastVersion) == utility.getVersionMaintenance() else {
        return dashboardPlaceholder(height: height,
                                    footerText: NSLocalizedString("_version_mismatch_error_", comment: ""),
                                    isError: true)
    }

    let accountIdentifier = configuration.accounts?.identifier ?? "active"
    let database = NCManageDatabase.shared
    let selectedAccount = accountIdentifier == "active"
        ? database.getActiveTableAccount()
        : database.getTableAccount(account: accountIdentifier)

    guard let account = selectedAccount else {
        return dashboardPlaceholder(height: height,
                                    footerText: NSLocalizedString("_no_active_account_", comment: ""),
                                    isError: true)
    }

    NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup, delegate: NCNetworking.shared)
    NextcloudKit.shared.appendSession(account: account.account,
                                      urlBase: account.urlBase,
                                      user: account.user,
                                      userId: account.userId,
                                      password: NCPreferences().getPassword(account: account.account),
                                      userAgent: userAgent,
                                      httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                      httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                      httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                      groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

    NextcloudKit.configureLogger(logLevel: NCBrandOptions.shared.disable_log ? .disabled : NCPreferences().log,
                                 logDirectory: NCPreferences.sharedLogDirectory)
    defer { NextcloudKit.flushLogger() }

    let version = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, utility.getVersionBuild())
    nkLog(debug: "Start \(NCBrandOptions.shared.brand) dashboard widget session " + version)

    let moduleId = configuration.applications?.identifier
        ?? database.getDashboardWidgetApplications(account: account.account).first?.id
        ?? "recommendations"
    let (module, moduleButtons) = database.getDashboardWidget(account: account.account, id: moduleId)
    let title = module?.title ?? moduleId
    let baseURL = URL(string: account.urlBase)
    let actions = (moduleButtons ?? []).compactMap { button -> DashboardAction? in
        guard moduleId != "notes" || button.type != "new" else { return nil }

        let isMore = button.type == "more"
        let url: URL?
        if moduleId == "files-favorites", isMore {
            var components = URLComponents()
            components.scheme = NCGlobal.shared.appScheme
            components.host = "openFavorites"
            components.queryItems = [URLQueryItem(name: "account", value: account.account)]
            url = components.url
        } else {
            url = dashboardWebURL(button.link, relativeTo: baseURL)
        }
        guard let url else { return nil }
        return DashboardAction(id: button.index, title: button.text, url: url, isMore: isMore)
    }

    let titleImage: UIImage?
    if let iconClass = module?.iconClass {
        let fileSystem = NCUtilityFileSystem()
        let path = fileSystem.createServerUrl(serverUrl: fileSystem.directoryUserData, fileName: iconClass + ".png")
        titleImage = UIImage(contentsOfFile: path)
    } else {
        titleImage = nil
    }
    let moduleImage = titleImage ?? UIImage(systemName: "rectangle.grid.2x2") ?? UIImage()
    let roundIcons = module?.itemIconsRound ?? false

    let isOnThisDay = moduleId == "photos-onthisday"
    let itemAPIVersion = module?.preferredItemAPIVersion ?? (isOnThisDay ? .unsupported : nil)
    let webURL: URL?
    if itemAPIVersion == .unsupported {
        let defaultURL = isOnThisDay ? account.urlBase + "/index.php/apps/photos/thisday" : nil
        webURL = dashboardWebURL(module?.widgetUrl, relativeTo: baseURL) ?? dashboardWebURL(defaultURL, relativeTo: baseURL)
    } else {
        webURL = nil
    }

    let options = NKRequestOptions(timeout: 90, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
    let result = await getDashboardModuleItems(moduleId,
                                               version: itemAPIVersion,
                                               account: account.account,
                                               options: options)
    guard result.error == .success else {
        return dashboardPlaceholder(height: height,
                                    title: title,
                                    titleImage: moduleImage,
                                    footerText: result.error.localizedGenericMessage,
                                    isError: true)
    }

    let items = result.items
    let visibleActions = DashboardWidgetLayout.visibleActions(actions, totalRows: items.count, height: height)
    let rowCount = DashboardWidgetLayout.rowCount(for: height, hasActions: !visibleActions.isEmpty)
    var rows: [DashboardData] = []

    for (index, item) in items.prefix(rowCount).enumerated() {
        var icon: UIImage?
        var isRound = roundIcons
        var calendarColor: UIColor?

        if let iconURL = dashboardWebURL(item.iconUrl, relativeTo: baseURL) {
            isRound = isRound || iconURL.pathComponents.contains("avatar")
            if iconURL.pathComponents.suffix(2).elementsEqual(["filetypes", "folder.svg"]) {
                icon = utility.loadImage(named: NKTypeIconFile.directory.rawValue,
                                         size: DashboardWidgetLayout.iconSize,
                                         useTypeIconFile: true,
                                         account: account.account)
                isRound = false
            } else if iconURL.pathComponents.contains("getCalendarDotSvg") {
                calendarColor = UIColor(hex: (iconURL.lastPathComponent as NSString).deletingPathExtension)
            } else {
                let preview = await NextcloudKit.shared.downloadPreviewAsync(url: iconURL, account: account.account, options: options)
                if preview.error == .success, let data = preview.responseData?.data {
                    icon = UIImage(data: data)
                }
            }
        }

        rows.append(DashboardData(id: index,
                                  title: item.title ?? "",
                                  subtitle: item.subtitle ?? "",
                                  link: dashboardWebURL(item.link, relativeTo: baseURL),
                                  icon: icon,
                                  isRound: isRound,
                                  calendarColor: calendarColor))
    }

    let accountName = account.alias.isEmpty ? account.displayName : "\(account.displayName) (\(account.alias))"
    return DashboardDataEntry(date: Date(),
                              rows: rows,
                              totalRows: items.count,
                              buttons: actions,
                              webURL: webURL,
                              isPlaceholder: false,
                              allowsRefresh: webURL == nil,
                              titleImage: moduleImage,
                              title: title,
                              footerImage: "checkmark.icloud",
                              footerText: accountName)
}

private func getDashboardModuleItems(_ moduleId: String,
                                     version: DashboardItemAPIVersion?,
                                     account: String,
                                     options: NKRequestOptions) async -> (items: [DashboardModuleItem], error: NKError) {
    if version == .unsupported {
        return ([], .success)
    }

    if version != .v2 {
        let result = await NextcloudKit.shared.getDashboardWidgetsApplicationAsync(moduleId, account: account, options: options)
        guard result.error == .success else { return ([], result.error) }

        if let items = result.dashboardApplications?.first(where: { $0.application == moduleId })?.items {
            return (items.map { DashboardModuleItem(title: $0.title, subtitle: $0.subtitle, link: $0.link, iconUrl: $0.iconUrl) }, .success)
        }
        if version == .v1 {
            return ([], .success)
        }
    }

    // A catalog without version metadata keeps the v1-to-v2 fallback.
    var components = URLComponents()
    components.path = "ocs/v2.php/apps/dashboard/api/v2/widget-items"
    components.queryItems = [
        URLQueryItem(name: "widgets[]", value: moduleId),
        URLQueryItem(name: "format", value: "json")
    ]
    guard let endpoint = components.string else { return ([], .urlError) }

    let response = await NextcloudKit.shared.generalWithEndpointAsync(endpoint, account: account, method: "GET", options: options)
    if version == nil, response.error.errorCode == 404 {
        return ([], .success)
    }
    guard response.error == .success else { return ([], response.error) }
    guard let data = response.responseData?.data,
          let payload = try? JSONDecoder().decode(DashboardItemsResponse.self, from: data) else {
        return ([], .invalidResponseError)
    }

    let meta = payload.ocs.meta
    guard (200..<300).contains(meta.statuscode) else {
        return ([], NKError(errorCode: meta.statuscode, errorDescription: meta.message ?? ""))
    }

    return (payload.ocs.data[moduleId]?.items ?? [], .success)
}

private func dashboardWebURL(_ value: String?, relativeTo baseURL: URL?) -> URL? {
    guard let value, !value.isEmpty else { return nil }
    let url = value.hasPrefix("/") ? URL(string: value, relativeTo: baseURL)?.absoluteURL : URL(string: value)
    guard let url, let scheme = url.scheme?.lowercased(),
          scheme == "https" || scheme == "http",
          let host = url.host, !host.isEmpty else { return nil }
    return url
}
