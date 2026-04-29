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

    private weak var controller: NCMainTabBarController?

    private let database = NCManageDatabase.shared
    private let utilityFileSystem = NCUtilityFileSystem()

    init(account: String, controller: NCMainTabBarController?) {
        self.account = account
        self.controller = controller
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
        let destination: Destination
    }

    enum Destination {
        case storyboard(
            name: String,
            presentation: Presentation,
            configuration: StoryboardConfiguration = .none
        )

        case browser(
            url: String,
            title: String
        )

        case settings
        case moreApps
        case none
    }

    enum Presentation {
        case push
        case modalPageSheet
    }

    enum StoryboardConfiguration {
        case none
        case scan
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
                destination: .storyboard(
                    name: "NCRecent",
                    presentation: .push
                )
            )
        )

        if capabilities.assistantEnabled,
           NCBrandOptions.shared.disable_show_more_nextcloud_apps_in_settings {
            functionItems.append(
                Item(
                    titleKey: "_assistant_",
                    systemImage: "sparkles",
                    destination: .moreApps
                )
            )
        }

        if capabilities.fileSharingApiEnabled {
            functionItems.append(
                Item(
                    titleKey: "_list_shares_",
                    systemImage: "person.badge.plus",
                    destination: .storyboard(
                        name: "NCShares",
                        presentation: .push
                    )
                )
            )
        }

        functionItems.append(
            Item(
                titleKey: "_manage_file_offline_",
                systemImage: "icloud.and.arrow.down",
                destination: .storyboard(
                    name: "NCOffline",
                    presentation: .push
                )
            )
        )

        if capabilities.groupfoldersEnabled {
            functionItems.append(
                Item(
                    titleKey: "_group_folders_",
                    systemImage: "person.2",
                    destination: .storyboard(
                        name: "NCGroupfolders",
                        presentation: .push
                    )
                )
            )
        }

        functionItems.append(
            Item(
                titleKey: "_scanned_images_",
                systemImage: "doc.text.viewfinder",
                destination: .storyboard(
                    name: "NCScan",
                    presentation: .modalPageSheet,
                    configuration: .scan
                )
            )
        )

        functionItems.append(
            Item(
                titleKey: "_trash_view_",
                systemImage: "trash",
                destination: .storyboard(
                    name: "NCTrash",
                    presentation: .push
                )
            )
        )

        settingsItems.append(
            Item(
                titleKey: "_settings_",
                systemImage: "gear",
                destination: .settings
            )
        )

        configureQuota(tableAccount: tableAccount)
        loadExternalSites(
            sessionAccount: tableAccount.account,
            externalSiteItems: &externalSiteItems
        )

        if !NCBrandOptions.shared.disable_show_more_nextcloud_apps_in_settings {
            sections.append(
                Section(
                    type: .moreApps,
                    items: [
                        Item(
                            titleKey: "_more_apps_",
                            systemImage: "square.grid.2x2.fill",
                            destination: .moreApps
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

    func perform(_ destination: Destination) {
        switch destination {
        case let .storyboard(name, presentation, configuration):
            openStoryboard(
                name: name,
                presentation: presentation,
                configuration: configuration
            )

        case let .browser(url, title):
            openBrowser(
                url: url,
                title: title
            )

        case .settings:
            openSettings()

        case .moreApps:
            break

        case .none:
            break
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

    private func loadExternalSites(
        sessionAccount: String,
        externalSiteItems: inout [Item]
    ) {
        guard let capabilities = NCNetworking.shared.capabilities[sessionAccount],
              !NCBrandOptions.shared.disable_more_external_site,
              capabilities.externalSites,
              let externalSites = database.getAllExternalSites(account: sessionAccount) else {
            return
        }

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
                    destination: .browser(
                        url: urlEncoded,
                        title: externalSite.name
                    )
                )
            )
        }
    }

    private func openStoryboard(
        name: String,
        presentation: Presentation,
        configuration: StoryboardConfiguration
    ) {
        guard let controller,
              let destinationController = UIStoryboard(
                name: name,
                bundle: nil
              ).instantiateInitialViewController() else {
            return
        }

        configureStoryboardController(
            destinationController,
            configuration: configuration
        )

        switch presentation {
        case .push:
            guard let navigationController = controller.currentNavigationController() else {
                return
            }

            navigationController.pushViewController(destinationController, animated: true)

        case .modalPageSheet:
            destinationController.modalPresentationStyle = .pageSheet
            controller.present(destinationController, animated: true)
        }
    }

    private func configureStoryboardController(
        _ destinationController: UIViewController,
        configuration: StoryboardConfiguration
    ) {
        guard let controller else {
            return
        }

        switch configuration {
        case .none:
            break

        case .scan:
            if let scanController = destinationController.topMostViewController() as? NCScan {
                scanController.controller = controller
            }
        }
    }

    private func openBrowser(
        url: String,
        title: String
    ) {
        guard let controller,
              let navigationController = controller.currentNavigationController(),
              url.contains("//"),
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
    }

    private func openSettings() {
        guard let controller,
              let navigationController = controller.currentNavigationController() else {
            return
        }

        let settingsView = NCSettingsView(
            model: NCSettingsModel(controller: controller)
        )

        let settingsController = UIHostingController(rootView: settingsView)
        settingsController.title = NSLocalizedString("_settings_", comment: "")

        navigationController.pushViewController(settingsController, animated: true)
    }
}
