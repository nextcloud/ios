// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI
import NextcloudKit

/// View model used by `NCMoreView` to build and handle the content of the More tab.
///
/// `NCMoreModel` replaces the old storyboard-driven `NCMore` controller logic with a
/// SwiftUI-friendly data model. It is responsible for:
///
/// - Building the visible sections of the More screen.
/// - Loading account quota information.
/// - Loading available feature entries based on server capabilities.
/// - Loading configured external sites.
/// - Building the app suggestion shortcut section.
/// - Describing each row through a generic `Destination`.
/// - Executing the selected destination using UIKit navigation.
///
/// The model intentionally keeps each menu item declarative. Instead of storing legacy
/// segue identifiers, each `Item` contains a `Destination` that describes how the row
/// should be opened. This allows the SwiftUI view to remain simple and only call
/// `model.perform(item.destination)` when a row is selected.
///
/// The actual navigation is still UIKit-based because the More tab is hosted inside
/// `NCMoreNavigationController`.
///
/// - Important: This model is `@MainActor` because it updates SwiftUI state and performs
///   UIKit navigation operations.
@MainActor
final class NCMoreModel: ObservableObject {
    @Published var sections: [Section] = []
    @Published var quotaDescription: String = ""
    @Published var quotaProgress: Double = 0
    @Published var quotaExternalSiteTitle: String = ""
    @Published var quotaExternalSiteUrl: String?

    private weak var controller: NCMainTabBarController?
    var account: String {
        controller?.account ?? ""
    }

    private let database = NCManageDatabase.shared
    private let utilityFileSystem = NCUtilityFileSystem()

    init(controller: NCMainTabBarController?) {
        self.controller = controller
    }

    /// A visible section in the More screen.
    ///
    /// Sections are rendered by `NCMoreView` as either:
    ///
    /// - `moreApps`: the app suggestion shortcut area.
    /// - `regular`: a standard rounded list section.
    struct Section: Identifiable {
        let identifier = UUID()
        let type: SectionType
        let items: [Item]

        var id: UUID {
            identifier
        }
    }

    /// Describes the visual style and semantic role of a More screen section.
    enum SectionType {
        /// Section used for Nextcloud app suggestions.

        case moreApps
        /// Standard menu section with tappable rows.
        case regular
    }

    /// A single row or shortcut displayed in the More screen.
    ///
    /// Each item contains only presentation data and a destination:
    ///
    /// - `titleKey`: localization key used for the visible title.
    /// - `image`: name used as row icon.
    /// - `destination`: generic navigation target executed by `perform(_:)`.
    struct Item {
        let identifier = UUID()
        let titleKey: String
        let image: String
        let destination: Destination
    }

    /// Generic navigation destination for an item in the More screen.
    ///
    /// This avoids hard-coding legacy segue identifiers in the SwiftUI view.
    /// Each case represents a type of action, not a specific menu entry.
    enum Destination {
        /// Opens the initial view controller of a storyboard.
        ///
        /// - Parameters:
        ///   - name: Storyboard file name without `.storyboard`.
        ///   - presentation: Presentation mode used to open the destination.
        ///   - configure: Optional closure used to configure the destination before presentation.
        case storyboard(
            name: String,
            presentation: Presentation,
            configure: (@MainActor (_ destinationController: UIViewController, _ controller: NCMainTabBarController) -> Void)? = nil
        )

        /// Opens an external or internal web URL using `NCBrowserWeb`.
        ///
        /// - Parameters:
        ///   - url: URL string to open.
        ///   - title: Browser title.
        case browser(
            url: String,
            title: String
        )

        /// Opens an app using a custom URL scheme, with a fallback URL if the app is not installed.
        ///
        /// - Parameters:
        ///   - schemeUrl: App URL scheme.
        ///   - fallbackUrl: Fallback URL opened when the app scheme cannot be handled.
        case openApp(
            schemeUrl: String,
            fallbackUrl: String
        )

        /// Opens an external URL using `UIApplication`.
        ///
        /// - Parameter url: URL string to open.
        case openUrl(String)

        /// Opens the SwiftUI settings screen.
        case settings

        /// No-op destination.
        case none
    }

    /// Presentation style used for storyboard-based destinations.
    enum Presentation {
        /// Pushes the destination on the current navigation controller.
        case push

        /// Presents the destination modally using `.pageSheet`.
        case modalPageSheet
    }

    /// Loads all More screen items for the current account.
    ///
    /// This method rebuilds the full screen state:
    ///
    /// - Clears existing sections.
    /// - Reads the current account from the local database.
    /// - Reads server capabilities from `NCNetworking`.
    /// - Adds feature rows such as Recent, Shares, Offline, Scan, Trash.
    /// - Adds Settings.
    /// - Loads quota information.
    /// - Loads external sites when enabled by branding options and server capabilities.
    ///
    /// The resulting sections are published through `sections` and rendered by `NCMoreView`.
    func loadItems() async {
        guard let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)),
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
                image: "clock.arrow.circlepath",
                destination: .storyboard(
                    name: "NCRecent",
                    presentation: .push
                )
            )
        )

        if !NCBrandOptions.shared.disable_show_more_nextcloud_apps_in_settings {
            sections.append(
                Section(
                    type: .moreApps,
                    items: [
                        Item(
                            titleKey: "Talk",
                            image: "talk-template",
                            destination: .openApp(
                                schemeUrl: NCGlobal.shared.talkSchemeUrl,
                                fallbackUrl: NCGlobal.shared.talkAppStoreUrl
                            )
                        ),
                        Item(
                            titleKey: "Notes",
                            image: "notes-template",
                            destination: .openApp(
                                schemeUrl: NCGlobal.shared.notesSchemeUrl,
                                fallbackUrl: NCGlobal.shared.notesAppStoreUrl
                            )
                        ),
                        Item(
                            titleKey: "More apps",
                            image: "more-apps-template",
                            destination: .openUrl(NCGlobal.shared.moreAppsUrl)
                        )
                    ]
                )
            )
        }

        if capabilities.fileSharingApiEnabled {
            functionItems.append(
                Item(
                    titleKey: "_list_shares_",
                    image: "person.badge.plus",
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
                image: "icloud.and.arrow.down",
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
                    image: "person.2",
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
                image: "doc.text.viewfinder",
                destination: .storyboard(
                    name: "NCScan",
                    presentation: .modalPageSheet,
                    configure: { destinationController, controller in
                        if let scanController = destinationController.topMostViewController() as? NCScan {
                            scanController.controller = controller
                        }
                    }
                )
            )
        )

        functionItems.append(
            Item(
                titleKey: "_trash_view_",
                image: "trash",
                destination: .storyboard(
                    name: "NCTrash",
                    presentation: .push
                )
            )
        )

        settingsItems.append(
            Item(
                titleKey: "_settings_",
                image: "gear",
                destination: .settings
            )
        )

        configureQuota(tableAccount: tableAccount)

        loadExternalSites(sessionAccount: tableAccount.account, externalSiteItems: &externalSiteItems)

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

    /// Executes the selected destination.
    ///
    /// The SwiftUI view calls this method when the user taps a row or shortcut.
    /// The method dispatches the destination to the correct UIKit navigation helper.
    ///
    /// - Parameter destination: The destination associated with the selected item.
    func perform(_ destination: Destination) {
        switch destination {
        case let .storyboard(name, presentation, configure):
            openStoryboard(name: name, presentation: presentation, configure: configure)

        case let .browser(url, title):
            openBrowser(url: url, title: title)

        case let .openApp(schemeUrl, fallbackUrl):
            openApp(schemeUrl: schemeUrl, fallbackUrl: fallbackUrl)

        case let .openUrl(url):
            openUrl(url)

        case .settings:
            openSettings()

        case .none:
            break
        }
    }

    /// Configures the visible quota text and progress value for the account.
    ///
    /// The quota text follows the same behavior as the old UIKit implementation:
    ///
    /// - `-1`: displayed as `0`.
    /// - `-2`: displayed as unknown quota.
    /// - `-3`: displayed as unlimited quota.
    /// - Any other value: formatted as a file size.
    ///
    /// - Parameter tableAccount: Account database object containing quota values.
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

    /// Loads external site entries configured for the account.
    ///
    /// External sites are shown only when:
    ///
    /// - Branding options do not disable them.
    /// - Server capabilities report external sites support.
    /// - The database contains valid external site records.
    ///
    /// - Parameters:
    ///   - sessionAccount: Account identifier used to read capabilities and database records.
    ///   - externalSiteItems: Destination array where valid external site items are appended.
    private func loadExternalSites(sessionAccount: String, externalSiteItems: inout [Item]) {
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
                    image: externalSite.type == "settings" ? "gear" : "network",
                    destination: .browser(
                        url: urlEncoded,
                        title: externalSite.name
                    )
                )
            )
        }
    }

    /// Opens a storyboard-based destination.
    ///
    /// The method instantiates the initial view controller from the provided storyboard,
    /// optionally configures it, and then either pushes or presents it.
    ///
    /// - Parameters:
    ///   - name: Storyboard file name without `.storyboard`.
    ///   - presentation: Presentation mode used for the destination.
    ///   - configure: Optional closure used to configure the destination before opening.
    private func openStoryboard(name: String, presentation: Presentation, configure: (@MainActor (_ destinationController: UIViewController, _ controller: NCMainTabBarController) -> Void)?) {
        guard let controller,
              let destinationController = UIStoryboard(
                name: name,
                bundle: nil
              ).instantiateInitialViewController() else {
            return
        }

        configure?(destinationController, controller)

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

    /// Opens a URL using `NCBrowserWeb`.
    ///
    /// The browser is pushed on the current navigation controller and configured to hide
    /// the exit button, matching the old More screen behavior.
    ///
    /// - Parameters:
    ///   - url: URL string to open.
    ///   - title: Browser title.
    private func openBrowser(url: String, title: String) {
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

    /// Opens the SwiftUI settings screen.
    ///
    /// The settings view is created with `NCSettingsModel` and pushed on the current
    /// navigation controller.
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

    /// Opens an app using a custom URL scheme.
    ///
    /// If the app is not installed or the scheme cannot be handled, the fallback URL is opened.
    ///
    /// - Parameters:
    ///   - schemeUrl: App URL scheme.
    ///   - fallbackUrl: Fallback URL opened when the app scheme cannot be handled.
    private func openApp(schemeUrl: String, fallbackUrl: String) {
        guard let appUrl = URL(string: schemeUrl) else {
            return
        }

        if UIApplication.shared.canOpenURL(appUrl) {
            UIApplication.shared.open(appUrl)
        } else if let fallbackUrl = URL(string: fallbackUrl) {
            UIApplication.shared.open(fallbackUrl)
        }
    }

    /// Opens an external URL using `UIApplication`.
    ///
    /// - Parameter url: URL string to open.
    private func openUrl(_ url: String) {
        guard let url = URL(string: url) else {
            return
        }

        UIApplication.shared.open(url)
    }
}
