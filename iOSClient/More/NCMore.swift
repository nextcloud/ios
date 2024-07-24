//
//  NCMore.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/04/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
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
import NextcloudKit
import SafariServices
import SwiftUI
import Foundation

class NCMore: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var labelQuota: UILabel!
    @IBOutlet weak var labelQuotaExternalSite: UILabel!
    @IBOutlet weak var progressQuota: UIProgressView!
    @IBOutlet weak var viewQuota: UIView!

    private var functionMenu: [NKExternalSite] = []
    private var externalSiteMenu: [NKExternalSite] = []
    private var settingsMenu: [NKExternalSite] = []
    private var quotaMenu: [NKExternalSite] = []
    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    private let applicationHandle = NCApplicationHandle()
    private var tabAccount: tableAccount?

    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    private struct Section {
        var items: [NKExternalSite]
        var type: SectionType

        enum SectionType {
            case moreApps
            case regular
        }
    }
    private var sections: [Section] = []

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("_more_", comment: "")
        view.backgroundColor = .systemGroupedBackground

        tableView.insetsContentViewsToSafeArea = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .systemGroupedBackground
        tableView.register(NCMoreAppSuggestionsCell.fromNib(), forCellReuseIdentifier: NCMoreAppSuggestionsCell.reuseIdentifier)

        // create tap gesture recognizer
        let tapQuota = UITapGestureRecognizer(target: self, action: #selector(tapLabelQuotaExternalSite))
        labelQuotaExternalSite.isUserInteractionEnabled = true
        labelQuotaExternalSite.addGestureRecognizer(tapQuota)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setGroupAppearance()
        loadItems()
        tableView.reloadData()
    }

    // MARK: -

    func loadItems() {
        var item = NKExternalSite()
        var quota: String = ""

        // Clear
        functionMenu.removeAll()
        externalSiteMenu.removeAll()
        settingsMenu.removeAll()
        quotaMenu.removeAll()
        sections.removeAll()
        labelQuotaExternalSite.text = ""
        progressQuota.progressTintColor = NCBrandColor.shared.brandElement

        // ITEM : Transfer
        item = NKExternalSite()
        item.name = "_transfers_"
        item.icon = "arrow.left.arrow.right"
        item.url = "segueTransfers"
        item.order = 10
        functionMenu.append(item)

        // ITEM : Recent
        item = NKExternalSite()
        item.name = "_recent_"
        item.icon = "clock.arrow.circlepath"
        item.url = "segueRecent"
        item.order = 20
        functionMenu.append(item)

        // ITEM : Activity
        item = NKExternalSite()
        item.name = "_activity_"
        item.icon = "bolt"
        item.url = "segueActivity"
        item.order = 30
        functionMenu.append(item)

        if NCGlobal.shared.capabilityAssistantEnabled, NCBrandOptions.shared.disable_show_more_nextcloud_apps_in_settings {
            // ITEM : Assistant
            item = NKExternalSite()
            item.name = "_assistant_"
            item.icon = "sparkles"
            item.url = "openAssistant"
            item.order = 40
            functionMenu.append(item)
        }

        // ITEM : Shares
        if NCGlobal.shared.capabilityFileSharingApiEnabled {
            item = NKExternalSite()
            item.name = "_list_shares_"
            item.icon = "person.badge.plus"
            item.url = "segueShares"
            item.order = 50
            functionMenu.append(item)
        }

        // ITEM : Offline
        item = NKExternalSite()
        item.name = "_manage_file_offline_"
        item.icon = "icloud.and.arrow.down"
        item.url = "segueOffline"
        item.order = 60
        functionMenu.append(item)

        // ITEM : Groupfolders
        if NCGlobal.shared.capabilityGroupfoldersEnabled {
            item = NKExternalSite()
            item.name = "_group_folders_"
            item.icon = "person.2"
            item.url = "segueGroupfolders"
            item.order = 61
            functionMenu.append(item)
        }

        // ITEM : Scan
        item = NKExternalSite()
        item.name = "_scanned_images_"
        item.icon = "doc.text.viewfinder"
        item.url = "openStoryboardNCScan"
        item.order = 70
        functionMenu.append(item)

        // ITEM : Trash
        if NCGlobal.shared.capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion15 {
            item = NKExternalSite()
            item.name = "_trash_view_"
            item.icon = "trash"
            item.url = "segueTrash"
            item.order = 80
            functionMenu.append(item)
        }

        // ITEM : HANDLE
        applicationHandle.loadItems(functionMenu: &functionMenu)

        // ORDER ITEM
        functionMenu = functionMenu.sorted(by: { $0.order < $1.order })

        // ITEM : Settings
        item = NKExternalSite()
        item.name = "_settings_"
        item.icon = "gear"
        item.url = "openSettings"
        settingsMenu.append(item)

        if !quotaMenu.isEmpty {
            let item = quotaMenu[0]
            labelQuotaExternalSite.text = item.name
        }

        // Display Name user & Quota
        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
            self.tabAccount = activeAccount

            if activeAccount.quotaRelative > 0 {
                progressQuota.progress = Float(activeAccount.quotaRelative) / 100
            } else {
                progressQuota.progress = 0
            }

            switch activeAccount.quotaTotal {
            case -1:
                quota = "0"
            case -2:
                quota = NSLocalizedString("_quota_space_unknown_", comment: "")
            case -3:
                quota = NSLocalizedString("_quota_space_unlimited_", comment: "")
            default:
                quota = utilityFileSystem.transformedSize(activeAccount.quotaTotal)
            }

            let quotaUsed: String = utilityFileSystem.transformedSize(activeAccount.quotaUsed)

            labelQuota.text = String.localizedStringWithFormat(NSLocalizedString("_quota_using_", comment: ""), quotaUsed, quota)
        }

        // ITEM : External
        if NCBrandOptions.shared.disable_more_external_site == false {
            if let externalSites = NCManageDatabase.shared.getAllExternalSites(account: appDelegate.account) {
                for externalSite in externalSites {
                    if !externalSite.name.isEmpty, !externalSite.url.isEmpty, let urlEncoded = externalSite.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                        item = NKExternalSite()
                        item.name = externalSite.name
                        item.url = urlEncoded
                        item.icon = "network"
                        if externalSite.type == "settings" {
                            item.icon = "gear"
                        }
                        externalSiteMenu.append(item)
                    }
                }
            }
        }

        loadSections()
    }

    private func loadSections() {
        if !NCBrandOptions.shared.disable_show_more_nextcloud_apps_in_settings {
            sections.append(Section(items: [NKExternalSite()], type: .moreApps))
        }

        if !functionMenu.isEmpty {
            sections.append(Section(items: functionMenu, type: .regular))
        }

        if !externalSiteMenu.isEmpty {
            sections.append(Section(items: externalSiteMenu, type: .regular))
        }

        if !settingsMenu.isEmpty {
            sections.append(Section(items: settingsMenu, type: .regular))
        }
    }

    // MARK: - Action

    @objc func tapLabelQuotaExternalSite() {
        if !quotaMenu.isEmpty {
            let item = quotaMenu[0]
            if let browserWebVC = UIStoryboard(name: "NCBrowserWeb", bundle: nil).instantiateInitialViewController() as? NCBrowserWeb {
                browserWebVC.urlBase = item.url
                browserWebVC.isHiddenButtonExit = true

                self.navigationController?.pushViewController(browserWebVC, animated: true)
                self.navigationController?.navigationBar.isHidden = false
            }
        }
    }

    // MARK: -

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection index: Int) -> CGFloat {
        let section = sections[index]

        if section.type == .moreApps || (index > 0 && sections[index - 1].type == .moreApps) {
            return 1
        } else {
            return 20
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection index: Int) -> Int {
        return sections[index].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = sections[indexPath.section]

        if section.type == .moreApps {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: NCMoreAppSuggestionsCell.reuseIdentifier, for: indexPath) as? NCMoreAppSuggestionsCell else { return UITableViewCell() }
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: CCCellMore.reuseIdentifier, for: indexPath) as? CCCellMore else { return UITableViewCell() }

            let item = sections[indexPath.section].items[indexPath.row]

            cell.imageIcon?.image = utility.loadImage(named: item.icon, colors: [NCBrandColor.shared.iconImageColor])
            cell.imageIcon?.contentMode = .scaleAspectFit
            cell.labelText?.text = NSLocalizedString(item.name, comment: "")
            cell.labelText.textColor = NCBrandColor.shared.textColor

            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator

            cell.separator.backgroundColor = .separator
            cell.separatorHeigth.constant = 0.4

            cell.removeCornerRadius()
            let rows = tableView.numberOfRows(inSection: indexPath.section)

            if indexPath.row == 0 {
                cell.applyCornerRadius()
                if indexPath.row == rows - 1 {
                    cell.separator.backgroundColor = .clear
                    cell.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMaxYCorner]
                } else {
                    cell.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
                }
            } else if indexPath.row == rows - 1 {
                cell.applyCornerRadius()
                cell.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
                cell.separator.backgroundColor = .clear
            }

            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = sections[indexPath.section].items[indexPath.row]

        // Action
        if item.url.contains("segue") && !item.url.contains("//") {
            self.navigationController?.performSegue(withIdentifier: item.url, sender: self)
        } else if item.url.contains("openStoryboard") && !item.url.contains("//") {
            let nameStoryboard = item.url.replacingOccurrences(of: "openStoryboard", with: "")
            let storyboard = UIStoryboard(name: nameStoryboard, bundle: nil)
            if let controller = storyboard.instantiateInitialViewController() {
                controller.modalPresentationStyle = UIModalPresentationStyle.pageSheet
                present(controller, animated: true, completion: nil)
            }
        } else if item.url.contains("//") {
            if let browserWebVC = UIStoryboard(name: "NCBrowserWeb", bundle: nil).instantiateInitialViewController() as? NCBrowserWeb {
                browserWebVC.urlBase = item.url
                browserWebVC.isHiddenButtonExit = true
                browserWebVC.titleBrowser = item.name
                self.navigationController?.pushViewController(browserWebVC, animated: true)
                self.navigationController?.navigationBar.isHidden = false
            }
        } else if item.url == "logout" {
            let alertController = UIAlertController(title: "", message: NSLocalizedString("_want_delete_", comment: ""), preferredStyle: .alert)
            let actionYes = UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (_: UIAlertAction) in
                self.appDelegate.openLogin(selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            }

            let actionNo = UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (_: UIAlertAction) in
                print("You've pressed No button")
            }

            alertController.addAction(actionYes)
            alertController.addAction(actionNo)
            self.present(alertController, animated: true, completion: nil)
        } else if item.url == "openAssistant" {
            let assistant = NCAssistant().environmentObject(NCAssistantTask())
            let hostingController = UIHostingController(rootView: assistant)
            present(hostingController, animated: true, completion: nil)
        } else if item.url == "openSettings" {
            let settingsView = NCSettingsView(model: NCSettingsModel(controller: tabBarController as? NCMainTabBarController))
            let settingsController = UIHostingController(rootView: settingsView)
            navigationController?.pushViewController(settingsController, animated: true)
        } else {
            applicationHandle.didSelectItem(item, viewController: self)
        }
    }
}
