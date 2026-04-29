// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import NextcloudKit

@MainActor
final class NCMoreModel: ObservableObject {
    @Published var sections: [Section] = []
    @Published var quotaDescription: String = ""
    @Published var quotaProgress: Double = 0
    @Published var quotaExternalSiteTitle: String = ""
    @Published var quotaExternalSiteUrl: String?

    let account: String

    private let database = NCManageDatabase.shared
    private let utilityFileSystem = NCUtilityFileSystem()

    init(account: String) {
        self.account = account
    }

    struct Section: Identifiable {
        let identifier = UUID()
        let type: SectionType
        let items: [Item]

        var id: UUID {
            identifier
        }
    }

    enum SectionType {
        case moreApps
        case regular
    }

    struct Item {
        let identifier = UUID()
        let titleKey: String
        let systemImage: String
        let action: Action
    }

    enum Action {
        case moreApps
        case segue(String)
        case storyboard(String)
        case browser(url: String, title: String)
        case settings
        case logout

        @MainActor
        func perform(controller: NCMainTabBarController?) {
            guard let controller,
                  let navigationController = controller.currentNavigationController() else {
                return
            }

            switch self {
            case .moreApps:
                break

            case let .segue(identifier):
                navigationController.performSegue(withIdentifier: identifier, sender: controller)

            case let .storyboard(name):
                let storyboard = UIStoryboard(name: name, bundle: nil)

                guard let presentedController = storyboard.instantiateInitialViewController() else {
                    return
                }

                if let scanController = presentedController.topMostViewController() as? NCScan {
                    scanController.controller = controller
                }

                presentedController.modalPresentationStyle = .pageSheet
                controller.present(presentedController, animated: true)

            case let .browser(url, title):
                guard url.contains("//"),
                      let browserWebController = UIStoryboard(
                        name: "NCBrowserWeb",
                        bundle: nil
                      ).instantiateInitialViewController() as? NCBrowserWeb else {
                    return
                }

                browserWebController.urlBase = url
                browserWebController.isHiddenButtonExit = true
                browserWebController.titleBrowser = title

                navigationController.pushViewController(browserWebController, animated: true)
                navigationController.navigationBar.isHidden = false

            case .settings:
                let settingsView = NCSettingsView(
                    model: NCSettingsModel(controller: controller)
                )

                let settingsController = UIHostingController(rootView: settingsView)
                settingsController.title = NSLocalizedString("_settings_", comment: "")

                navigationController.pushViewController(settingsController, animated: true)

            case .logout:
                break
            }
        }
    }

    func loadItems() async {
        guard let tableAccount = database.getTableAccount(
            predicate: NSPredicate(format: "account == %@", account)
        ),
        let capabilities = NCNetworking.shared.capabilities[tableAccount.account] else {
            return
        }

        var functionItems: [Item] = []
        var externalSiteItems: [Item] = []
        var settingsItems: [Item] = []

        sections.removeAll()
        quotaExternalSiteTitle = ""
        quotaExternalSiteUrl = nil

        functionItems.append(
            Item(
                titleKey: "_recent_",
                systemImage: "clock.arrow.circlepath",
                action: .segue("segueRecent")
            )
        )

        if capabilities.assistantEnabled,
           NCBrandOptions.shared.disable_show_more_nextcloud_apps_in_settings {
            functionItems.append(
                Item(
                    titleKey: "_assistant_",
                    systemImage: "sparkles",
                    action: .moreApps
                )
            )
        }

        if capabilities.fileSharingApiEnabled {
            functionItems.append(
                Item(
                    titleKey: "_list_shares_",
                    systemImage: "person.badge.plus",
                    action: .segue("segueShares")
                )
            )
        }

        functionItems.append(
            Item(
                titleKey: "_manage_file_offline_",
                systemImage: "icloud.and.arrow.down",
                action: .segue("segueOffline")
            )
        )

        if capabilities.groupfoldersEnabled {
            functionItems.append(
                Item(
                    titleKey: "_group_folders_",
                    systemImage: "person.2",
                    action: .segue("segueGroupfolders")
                )
            )
        }

        functionItems.append(
            Item(
                titleKey: "_scanned_images_",
                systemImage: "doc.text.viewfinder",
                action: .storyboard("NCScan")
            )
        )

        functionItems.append(
            Item(
                titleKey: "_trash_view_",
                systemImage: "trash",
                action: .segue("segueTrash")
            )
        )

        settingsItems.append(
            Item(
                titleKey: "_settings_",
                systemImage: "gear",
                action: .settings
            )
        )

        configureQuota(tableAccount: tableAccount)

        if !NCBrandOptions.shared.disable_more_external_site,
           capabilities.externalSites,
           let externalSites = database.getAllExternalSites(account: account) {
            for externalSite in externalSites {
                guard !externalSite.name.isEmpty,
                      !externalSite.url.isEmpty,
                      let urlEncoded = externalSite.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    continue
                }

                externalSiteItems.append(
                    Item(
                        titleKey: externalSite.name,
                        systemImage: externalSite.type == "settings" ? "gear" : "network",
                        action: .browser(
                            url: urlEncoded,
                            title: externalSite.name
                        )
                    )
                )
            }
        }

        if !NCBrandOptions.shared.disable_show_more_nextcloud_apps_in_settings {
            sections.append(
                Section(
                    type: .moreApps,
                    items: [
                        Item(
                            titleKey: "_more_apps_",
                            systemImage: "square.grid.2x2.fill",
                            action: .moreApps
                        )
                    ]
                )
            )
        }

        if !functionItems.isEmpty {
            sections.append(
                Section(
                    type: .regular,
                    items: functionItems
                )
            )
        }

        if !externalSiteItems.isEmpty {
            sections.append(
                Section(
                    type: .regular,
                    items: externalSiteItems
                )
            )
        }

        if !settingsItems.isEmpty {
            sections.append(
                Section(
                    type: .regular,
                    items: settingsItems
                )
            )
        }
    }

    private func configureQuota(tableAccount: tableAccount) {
        if tableAccount.quotaRelative > 0 {
            quotaProgress = Double(tableAccount.quotaRelative) / 100
        } else {
            quotaProgress = 0
        }

        let quota: String

        switch tableAccount.quotaTotal {
        case -1:
            quota = "0"

        case -2:
            quota = NSLocalizedString("_quota_space_unknown_", comment: "")

        case -3:
            quota = NSLocalizedString("_quota_space_unlimited_", comment: "")

        default:
            quota = utilityFileSystem.transformedSize(tableAccount.quotaTotal)
        }

        let quotaUsed = utilityFileSystem.transformedSize(tableAccount.quotaUsed)

        quotaDescription = String.localizedStringWithFormat(
            NSLocalizedString("_quota_using_", comment: ""),
            quotaUsed,
            quota
        )
    }
}
