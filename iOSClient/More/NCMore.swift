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
import MarqueeLabel

class NCMore: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var labelQuota: UILabel!
    @IBOutlet weak var labelQuotaExternalSite: UILabel!
    @IBOutlet weak var progressQuota: UIProgressView!
    @IBOutlet weak var viewQuota: UIView!

    var functionMenu: [NKExternalSite] = []
    var externalSiteMenu: [NKExternalSite] = []
    var settingsMenu: [NKExternalSite] = []
    var quotaMenu: [NKExternalSite] = []

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let defaultCornerRadius: CGFloat = 10.0
    let applicationHandle = NCApplicationHandle()
    
    var tabAccount: tableAccount?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("_more_", comment: "")
        view.backgroundColor = .systemGroupedBackground

        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .systemGroupedBackground
        tableView.register(UINib(nibName: "NCMoreUserCell", bundle: nil), forCellReuseIdentifier: "userCell")

        // create tap gesture recognizer
        let tapQuota = UITapGestureRecognizer(target: self, action: #selector(tapLabelQuotaExternalSite))
        labelQuotaExternalSite.isUserInteractionEnabled = true
        labelQuotaExternalSite.addGestureRecognizer(tapQuota)

        // Notification
        NotificationCenter.default.addObserver(self, selector: #selector(initialize), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setGroupeAppreance()
        
        appDelegate.activeViewController = self
        loadItems()
        tableView.reloadData()
    }

    // MARK: - NotificationCenter

    @objc func initialize() {
        loadItems()
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
        item.order = 40
        functionMenu.append(item)

        // ITEM : Shares
        if NCGlobal.shared.capabilityFileSharingApiEnabled {
            item = NKExternalSite()
            item.name = "_list_shares_"
            item.icon = "share"
            item.url = "segueShares"
            item.order = 50
            functionMenu.append(item)
        }

        // ITEM : Offline
        item = NKExternalSite()
        item.name = "_manage_file_offline_"
        item.icon = "tray.and.arrow.down"
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
        item.url = "segueSettings"
        settingsMenu.append(item)

        if quotaMenu.count > 0 {
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
                quota = CCUtility.transformedSize(activeAccount.quotaTotal)
            }

            let quotaUsed: String = CCUtility.transformedSize(activeAccount.quotaUsed)

            labelQuota.text = String.localizedStringWithFormat(NSLocalizedString("_quota_using_", comment: ""), quotaUsed, quota)
        }

        // ITEM : External
        if NCBrandOptions.shared.disable_more_external_site == false {
            if let externalSites = NCManageDatabase.shared.getAllExternalSites(account: appDelegate.account) {
                for externalSite in externalSites {
                    if (externalSite.name != "" && externalSite.url != ""), let urlEncoded = externalSite.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
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
    }

    // MARK: - Action

    @objc func tapLabelQuotaExternalSite() {

        if quotaMenu.count > 0 {

            let item = quotaMenu[0]
            let browserWebVC = UIStoryboard(name: "NCBrowserWeb", bundle: nil).instantiateInitialViewController() as! NCBrowserWeb
            browserWebVC.urlBase = item.url
            browserWebVC.isHiddenButtonExit = true

            self.navigationController?.pushViewController(browserWebVC, animated: true)
            self.navigationController?.navigationBar.isHidden = false
        }
    }

    @objc func tapImageLogoManageAccount() {

        let controller = CCManageAccount()

        self.navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: -

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 75
        } else {
            return NCGlobal.shared.heightCellSettings
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {

        if externalSiteMenu.count == 0 {
            return 3
        } else {
            return 4
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if section == 0 {
            return 10
        } else {
            return 20
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        var cont = 0

        if section == 0 {
            cont = tabAccount == nil ? 0 : 1
        } else if section == 1 {
            // Menu Normal
            cont = functionMenu.count
        } else {
            switch numberOfSections(in: tableView) {
            case 3:
                // Menu Settings
                if section == 2 {
                    cont = settingsMenu.count
                }
            case 4:
                // Menu External Site
                if section == 2 {
                    cont = externalSiteMenu.count
                }
                // Menu Settings
                if section == 3 {
                    cont = settingsMenu.count
                }
            default:
                cont = 0
            }
        }

        return cont
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        var item = NKExternalSite()

        // change color selection and disclosure indicator
        let selectionColor: UIView = UIView()
        if indexPath.section == 0 {

            let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath) as! NCMoreUserCell

            cell.avatar.image = nil
            cell.icon.image = nil
            cell.status.text = ""
            cell.displayName.text = ""

            if let account = tabAccount {
                cell.avatar.image = NCUtility.shared.loadUserImage(
                    for: account.user,
                       displayName: account.displayName,
                       userBaseUrl: appDelegate)

                if account.alias == "" {
                    cell.displayName?.text = account.displayName
                } else {
                    cell.displayName?.text = account.displayName + " (" + account.alias + ")"
                }
                cell.displayName.textColor = .label
            }
            cell.selectedBackgroundView = selectionColor
            cell.backgroundColor = .secondarySystemGroupedBackground
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator

            if NCGlobal.shared.capabilityUserStatusEnabled, let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", appDelegate.account)) {
                let status = NCUtility.shared.getUserStatus(userIcon: account.userStatusIcon, userStatus: account.userStatusStatus, userMessage: account.userStatusMessage)
                cell.icon.image = status.onlineStatus
                cell.status.text = status.statusMessage
                cell.status.textColor = .label
                cell.status.trailingBuffer = cell.status.frame.width
                if cell.status.labelShouldScroll() {
                    cell.status.tapToScroll = true
                } else {
                    cell.status.tapToScroll = false
                }
            }
            
            cell.layer.cornerRadius = defaultCornerRadius
            cell.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMaxYCorner]

            return cell

        } else {

            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! CCCellMore

            // Menu Normal
            if indexPath.section == 1 {
                item = functionMenu[indexPath.row]
            }
            // Menu External Site
            if numberOfSections(in: tableView) == 4 && indexPath.section == 2 {
                item = externalSiteMenu[indexPath.row]
            }
            // Menu Settings
            if (numberOfSections(in: tableView) == 3 && indexPath.section == 2) || (numberOfSections(in: tableView) == 4 && indexPath.section == 3) {
                item = settingsMenu[indexPath.row]
            }

            cell.imageIcon?.image = NCUtility.shared.loadImage(named: item.icon)
            cell.imageIcon?.contentMode = .scaleAspectFit
            cell.labelText?.text = NSLocalizedString(item.name, comment: "")
            cell.labelText.textColor = .label

            cell.selectedBackgroundView = selectionColor
            cell.backgroundColor = .secondarySystemGroupedBackground
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator

            cell.separator.backgroundColor = .separator
            cell.separatorHeigth.constant = 0.4
            
            cell.layer.cornerRadius = 0
            let rows = tableView.numberOfRows(inSection: indexPath.section)
            
            if indexPath.row == 0 {
                cell.layer.cornerRadius = defaultCornerRadius
                if indexPath.row == rows - 1 {
                    cell.separator.backgroundColor = .clear
                    cell.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMaxYCorner]
                } else {
                    cell.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
                }
            } else if indexPath.row == rows - 1 {
                cell.layer.cornerRadius = defaultCornerRadius
                cell.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
                cell.separator.backgroundColor = .clear
            }
            
            return cell
        }
    }

    // method to run when table view cell is tapped
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        var item = NKExternalSite()

        if indexPath.section == 0 {
            tapImageLogoManageAccount()
            return
        }

        // Menu Function
        if indexPath.section == 1 {
            item = functionMenu[indexPath.row]
        }

        // Menu External Site
        if numberOfSections(in: tableView) == 4 && indexPath.section == 2 {
            item = externalSiteMenu[indexPath.row]
        }

        // Menu Settings
        if (numberOfSections(in: tableView) == 3 && indexPath.section == 2) || (numberOfSections(in: tableView) == 4 && indexPath.section == 3) {
            item = settingsMenu[indexPath.row]
        }

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

            let browserWebVC = UIStoryboard(name: "NCBrowserWeb", bundle: nil).instantiateInitialViewController() as! NCBrowserWeb
            browserWebVC.urlBase = item.url
            browserWebVC.isHiddenButtonExit = true
            browserWebVC.titleBrowser = item.name

            self.navigationController?.pushViewController(browserWebVC, animated: true)
            self.navigationController?.navigationBar.isHidden = false

        } else if item.url == "logout" {

            let alertController = UIAlertController(title: "", message: NSLocalizedString("_want_delete_", comment: ""), preferredStyle: .alert)

            let actionYes = UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (_: UIAlertAction) in

                let manageAccount = CCManageAccount()
                manageAccount.delete(self.appDelegate.account)

                self.appDelegate.openLogin(viewController: self, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            }

            let actionNo = UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (_: UIAlertAction) in
                print("You've pressed No button")
            }

            alertController.addAction(actionYes)
            alertController.addAction(actionNo)
            self.present(alertController, animated: true, completion: nil)

        } else {
            applicationHandle.didSelectItem(item, viewController: self)
        }
    }
}

class CCCellMore: UITableViewCell {

    @IBOutlet weak var labelText: UILabel!
    @IBOutlet weak var imageIcon: UIImageView!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var separatorHeigth: NSLayoutConstraint!

    override var frame: CGRect {
        get {
            return super.frame
        }
        set (newFrame) {
            var frame = newFrame
            let newWidth = frame.width * 0.90
            let space = (frame.width - newWidth) / 2
            frame.size.width = newWidth
            frame.origin.x += space
            super.frame = frame
        }
    }
}

class NCMoreUserCell: UITableViewCell {

    @IBOutlet weak var displayName: UILabel!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var status: MarqueeLabel!
    
    override var frame: CGRect {
        get {
            return super.frame
        }
        set (newFrame) {
            var frame = newFrame
            let newWidth = frame.width * 0.90
            let space = (frame.width - newWidth) / 2
            frame.size.width = newWidth
            frame.origin.x += space
            super.frame = frame
        }
    }
}
