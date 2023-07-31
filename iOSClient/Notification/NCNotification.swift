//
//  NCNotification.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/01/17.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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
import SwiftyJSON
import JGProgressHUD

class NCNotification: UITableViewController, NCNotificationCellDelegate, NCEmptyDataSetDelegate {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var notifications: [NKNotifications] = []
    var emptyDataSet: NCEmptyDataSet?
    var isReloadDataSourceNetworkInProgress: Bool = false

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("_notifications_", comment: "")
        view.backgroundColor = .systemBackground

        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50.0
        tableView.allowsSelection = false
        tableView.backgroundColor = .systemBackground

        refreshControl?.addTarget(self, action: #selector(getNetwokingNotification), for: .valueChanged)

        // Navigation controller is being presented modally
        if navigationController?.presentingViewController != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .plain, action: { [weak self] in
                self?.dismiss(animated: true)
            })
        }

        // Empty
        let offset = (self.navigationController?.navigationBar.bounds.height ?? 0) - 20
        emptyDataSet = NCEmptyDataSet(view: tableView, offset: -offset, delegate: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDelegate.activeViewController = self

        navigationController?.setFileAppreance()

        NotificationCenter.default.addObserver(self, selector: #selector(initialize), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)

        getNetwokingNotification()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
    }

    @objc func viewClose() {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - NotificationCenter

    @objc func initialize() {
        getNetwokingNotification()
    }

    // MARK: - Empty

    func emptyDataSetView(_ view: NCEmptyView) {

        if isReloadDataSourceNetworkInProgress {
            view.emptyImage.image = UIImage(named: "networkInProgress")?.image(color: .gray, size: UIScreen.main.bounds.width)
            view.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
            view.emptyDescription.text = ""
        } else {
            view.emptyImage.image = NCUtility.shared.loadImage(named: "bell", color: .gray, size: UIScreen.main.bounds.width)
            view.emptyTitle.text = NSLocalizedString("_no_notification_", comment: "")
            view.emptyDescription.text = ""
        }
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        emptyDataSet?.numberOfItemsInSection(notifications.count, section: section)
        return notifications.count
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let notification = notifications[indexPath.row]

        if notification.app == "files_sharing" {
            NCActionCenter.shared.viewerFile(account: appDelegate.account, fileId: notification.objectId, viewController: self)
        } else {
            NCApplicationHandle().didSelectNotification(notification, viewController: self)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = self.tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! NCNotificationCell
        cell.delegate = self
        cell.selectionStyle = .none

        let notification = notifications[indexPath.row]
        let urlIcon = URL(string: notification.icon)
        var image: UIImage?

        if let urlIcon = urlIcon {
            let pathFileName = String(CCUtility.getDirectoryUserData()) + "/" + urlIcon.deletingPathExtension().lastPathComponent + ".png"
            image = UIImage(contentsOfFile: pathFileName)
        }

        if let image = image {
            cell.icon.image = image.withTintColor(NCBrandColor.shared.iconColor, renderingMode: .alwaysOriginal)
        } else {
            cell.icon.image = NCUtility.shared.loadImage(named: "bell", color: NCBrandColor.shared.iconColor)
        }

        // Avatar
        cell.avatar.isHidden = true
        cell.avatarLeadingMargin.constant = 10
        cell.date.text = DateFormatter.localizedString(from: notification.date as Date, dateStyle: .medium, timeStyle: .medium)
        cell.notification = notification
        cell.date.text = CCUtility.dateDiff(notification.date as Date)
        cell.date.textColor = .gray
        cell.subject.text = notification.subject
        cell.subject.textColor = .label
        cell.message.text = notification.message.replacingOccurrences(of: "<br />", with: "\n")
        cell.message.textColor = .gray

        cell.remove.setImage(UIImage(named: "xmark")!.image(color: .gray, size: 20), for: .normal)

        cell.primary.isEnabled = false
        cell.primary.isHidden = true
        cell.primary.titleLabel?.font = .systemFont(ofSize: 14)
        cell.primary.setTitleColor(.white, for: .normal)
        cell.primary.layer.cornerRadius = 10
        cell.primary.layer.masksToBounds = true
        cell.primary.layer.backgroundColor = NCBrandColor.shared.notificationAction.cgColor

        cell.secondary.isEnabled = false
        cell.secondary.isHidden = true
        cell.secondary.titleLabel?.font = .systemFont(ofSize: 14)
        cell.secondary.setTitleColor(NCBrandColor.shared.notificationAction, for: .normal)
        cell.secondary.layer.cornerRadius = 10
        cell.secondary.layer.masksToBounds = true
        cell.secondary.layer.backgroundColor = UIColor.clear.cgColor
        cell.secondary.layer.borderWidth = 1
        cell.secondary.layer.borderColor = NCBrandColor.shared.notificationAction.cgColor

        // Action
        if let actions = notification.actions,
           let jsonActions = JSON(actions).array {
            if jsonActions.count == 1 {
                let action = jsonActions[0]

                cell.primary.isEnabled = true
                cell.primary.isHidden = false
                cell.primary.setTitle(action["label"].stringValue, for: .normal)

            } else if jsonActions.count == 2 {

                cell.primary.isEnabled = true
                cell.primary.isHidden = false

                cell.secondary.isEnabled = true
                cell.secondary.isHidden = false

                for action in jsonActions {

                    let label =  action["label"].stringValue
                    let primary = action["primary"].boolValue

                    if primary {
                        cell.primary.setTitle(label, for: .normal)
                    } else {
                        cell.secondary.setTitle(label, for: .normal)
                    }
                }
            }
            
            let widthPrimary = cell.primary.intrinsicContentSize.width + 48;
            let widthSecondary = cell.secondary.intrinsicContentSize.width + 48;
            
            if widthPrimary > widthSecondary {
                cell.primaryWidth.constant = widthPrimary
                cell.secondaryWidth.constant = widthPrimary
            } else {
                cell.primaryWidth.constant = widthSecondary
                cell.secondaryWidth.constant = widthSecondary
            }
            
            
            var buttonWidth = max(cell.primary.intrinsicContentSize.width, cell.secondary.intrinsicContentSize.width)
            buttonWidth += 30
            cell.primaryWidth.constant = buttonWidth
            cell.secondaryWidth.constant = buttonWidth
        }

        return cell
    }

    // MARK: - tap Action

    func tapRemove(with notification: NKNotifications) {

        NextcloudKit.shared.setNotification(serverUrl: nil, idNotification: notification.idNotification , method: "DELETE") { (account, error) in
            if error == .success && account == self.appDelegate.account {
                if let index = self.notifications
                    .firstIndex(where: { $0.idNotification == notification.idNotification })  {
                    self.notifications.remove(at: index)
                }
                self.tableView.reloadData()
            } else if error != .success {
                NCContentPresenter.shared.showError(error: error)
            } else {
                print("[Error] The user has been changed during networking process.")
            }
        }
    }

    func tapAction(with notification: NKNotifications, label: String) {
        if notification.app == NCGlobal.shared.spreedName,
           let roomToken = notification.objectId.split(separator: "/").first,
           let talkUrl = URL(string: "nextcloudtalk://open-conversation?server=\(appDelegate.urlBase)&user=\(appDelegate.userId)&withRoomToken=\(roomToken)"),
           UIApplication.shared.canOpenURL(talkUrl) {
            UIApplication.shared.open(talkUrl)
        } else if let actions = notification.actions,
                  let jsonActions = JSON(actions).array,
                  let action = jsonActions.first(where: { $0["label"].string == label }) {
                      let serverUrl = action["link"].stringValue
            let method = action["type"].stringValue

            if method == "WEB", let url = action["link"].url {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return
            }

            NextcloudKit.shared.setNotification(serverUrl: serverUrl, idNotification: 0, method: method) { (account, error) in
                if error == .success && account == self.appDelegate.account {
                    if let index = self.notifications.firstIndex(where: { $0.idNotification == notification.idNotification }) {
                        self.notifications.remove(at: index)
                    }
                    self.tableView.reloadData()
                    if self.navigationController?.presentingViewController != nil, notification.app == NCGlobal.shared.twoFactorNotificatioName {
                        self.dismiss(animated: true)
                    }
                } else if error != .success {
                    NCContentPresenter.shared.showError(error: error)
                } else {
                    print("[Error] The user has been changed during networking process.")
                }

            }
        } // else: Action not found
    }

    func tapMore(with notification: NKNotifications) {
       toggleMenu(notification: notification)
    }

    // MARK: - Load notification networking

   @objc func getNetwokingNotification() {

        isReloadDataSourceNetworkInProgress = true
        self.tableView.reloadData()

        NextcloudKit.shared.getNotifications { account, notifications, data, error in
            if error == .success && account == self.appDelegate.account {
                self.notifications.removeAll()
                let sortedListOfNotifications = (notifications! as NSArray).sortedArray(using: [NSSortDescriptor(key: "date", ascending: false)])
                for notification in sortedListOfNotifications {
                    if let icon = (notification as! NKNotifications).icon {
                        NCUtility.shared.convertSVGtoPNGWriteToUserData(svgUrlString: icon, fileName: nil, width: 25, rewrite: false, account: self.appDelegate.account, completion: { _, _ in })
                    }
                    self.notifications.append(notification as! NKNotifications)
                }
                self.refreshControl?.endRefreshing()
                self.isReloadDataSourceNetworkInProgress = false
                self.tableView.reloadData()
            }
        }
    }
}

// MARK: -

class NCNotificationCell: UITableViewCell, NCCellProtocol {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var subject: UILabel!
    @IBOutlet weak var message: UILabel!
    @IBOutlet weak var remove: UIButton!
    @IBOutlet weak var primary: UIButton!
    @IBOutlet weak var secondary: UIButton!
    @IBOutlet weak var avatarLeadingMargin: NSLayoutConstraint!
    @IBOutlet weak var primaryWidth: NSLayoutConstraint!
    @IBOutlet weak var secondaryWidth: NSLayoutConstraint!

    private var user = ""

    weak var delegate: NCNotificationCellDelegate?
    var notification: NKNotifications?

    var fileAvatarImageView: UIImageView? {
        get { return avatar }
    }
    var fileUser: String? {
        get { return user }
        set { user = newValue ?? "" }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    @IBAction func touchUpInsideRemove(_ sender: Any) {
        guard let notification = notification else { return }
        delegate?.tapRemove(with: notification)
    }

    @IBAction func touchUpInsidePrimary(_ sender: Any) {
        guard let notification = notification,
                let button = sender as? UIButton,
                let label = button.titleLabel?.text
        else { return }
        delegate?.tapAction(with: notification, label: label)
    }

    @IBAction func touchUpInsideSecondary(_ sender: Any) {
        guard let notification = notification,
                let button = sender as? UIButton,
                let label = button.titleLabel?.text
        else { return }
        delegate?.tapAction(with: notification, label: label)
    }

}

protocol NCNotificationCellDelegate: AnyObject {
    func tapRemove(with notification: NKNotifications)
    func tapAction(with notification: NKNotifications, label: String)
}
