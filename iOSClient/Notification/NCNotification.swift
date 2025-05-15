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

class NCNotification: UITableViewController, NCNotificationCellDelegate {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    var notifications: [NKNotifications] = []
    var dataSourceTask: URLSessionTask?
    var session: NCSession.Session!

    var controller: NCMainTabBarController? {
        self.tabBarController as? NCMainTabBarController
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("_notifications_", comment: "")
        view.backgroundColor = .systemBackground

        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50.0
        tableView.backgroundColor = .systemBackground

        refreshControl?.addTarget(self, action: #selector(getNetwokingNotification(_:)), for: .valueChanged)

        navigationController?.navigationBar.tintColor = NCBrandColor.shared.iconImageColor

        let close = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""), style: .done) {
            self.dismiss(animated: true)
        }

        self.navigationItem.leftBarButtonItems = [close]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        getNetwokingNotification(nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUpdateNotification)

        // Cancel Queue & Retrieves Properties
        dataSourceTask?.cancel()
    }

    @objc func viewClose() {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let notification = NCApplicationHandle().didSelectNotification(notifications[indexPath.row], viewController: self) else { return }

        do {
            if let subjectRichParameters = notification.subjectRichParameters,
               let json = try JSONSerialization.jsonObject(with: subjectRichParameters, options: .mutableContainers) as? [String: Any],
               let file = json["file"] as? [String: Any],
               file["type"] as? String == "file" {
                if let id = file["id"] {
                    NCActionCenter.shared.viewerFile(account: session.account, fileId: ("\(id)"), viewController: self)
                }
            }
        } catch {
            print("Something went wrong")
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = self.tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? NCNotificationCell else { return UITableViewCell() }
        cell.delegate = self
        cell.selectionStyle = .none
        cell.indexPath = indexPath

        let notification = notifications[indexPath.row]
        let urlIcon = URL(string: notification.icon)
        var image: UIImage?

        if let urlIcon = urlIcon {
            let pathFileName = utilityFileSystem.directoryUserData + "/" + urlIcon.deletingPathExtension().lastPathComponent + ".png"
            image = UIImage(contentsOfFile: pathFileName)
        }

        if let image = image {
            cell.icon.image = image.withTintColor(NCBrandColor.shared.getElement(account: session.account), renderingMode: .alwaysOriginal)
        }

        // Avatar
        cell.avatar.isHidden = true
        cell.avatarLeadingMargin.constant = 10
        if let subjectRichParameters = notification.subjectRichParameters,
           let json = JSON(subjectRichParameters).dictionary,
           let user = json["user"]?["id"].stringValue {
            cell.avatar.isHidden = false
            cell.avatarLeadingMargin.constant = 50

            let fileName = NCSession.shared.getFileName(urlBase: session.urlBase, user: user)
            let results = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName)

            if results.image == nil {
                cell.fileAvatarImageView?.image = utility.loadUserImage(for: user, displayName: json["user"]?["name"].string, urlBase: session.urlBase)
            } else {
                cell.fileAvatarImageView?.image = results.image
            }

            if !(results.tblAvatar?.loaded ?? false),
               NCNetworking.shared.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
                NCNetworking.shared.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: user, fileName: fileName, account: session.account, view: tableView))
            }
        }

        cell.date.text = DateFormatter.localizedString(from: notification.date as Date, dateStyle: .medium, timeStyle: .medium)
        cell.notification = notification
        cell.date.text = utility.getRelativeDateTitle(notification.date as Date)
        cell.date.textColor = NCBrandColor.shared.iconImageColor2
        cell.subject.text = notification.subject
        cell.subject.textColor = NCBrandColor.shared.textColor
        cell.message.text = notification.message.replacingOccurrences(of: "<br />", with: "\n")
        cell.message.textColor = NCBrandColor.shared.textColor2

        cell.remove.setImage(utility.loadImage(named: "xmark", colors: [NCBrandColor.shared.iconImageColor]), for: .normal)

        cell.primary.isEnabled = false
        cell.primary.isHidden = true
        cell.primary.titleLabel?.font = .systemFont(ofSize: 15)
        cell.primary.layer.cornerRadius = 15
        cell.primary.layer.masksToBounds = true
        cell.primary.layer.backgroundColor = NCBrandColor.shared.getElement(account: session.account).cgColor
        cell.primary.setTitleColor(.white, for: .normal)

        cell.more.isEnabled = false
        cell.more.isHidden = true
        cell.more.titleLabel?.font = .systemFont(ofSize: 15)
        cell.more.layer.cornerRadius = 15
        cell.more.layer.masksToBounds = true
        cell.more.layer.backgroundColor = NCBrandColor.shared.getElement(account: session.account).cgColor
        cell.more.setTitleColor(.white, for: .normal)

        cell.secondary.isEnabled = false
        cell.secondary.isHidden = true
        cell.secondary.titleLabel?.font = .systemFont(ofSize: 15)
        cell.secondary.layer.cornerRadius = 15
        cell.secondary.layer.masksToBounds = true
        cell.secondary.layer.borderWidth = 1
        cell.secondary.layer.borderColor = NCBrandColor.shared.iconImageColor2.cgColor
        cell.secondary.layer.backgroundColor = UIColor.secondarySystemBackground.cgColor
        cell.secondary.setTitleColor(NCBrandColor.shared.iconImageColor2, for: .normal)

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

                    let label = action["label"].stringValue
                    let primary = action["primary"].boolValue

                    if primary {
                        cell.primary.setTitle(label, for: .normal)
                    } else {
                        cell.secondary.setTitle(label, for: .normal)
                    }
                }
            } else if jsonActions.count >= 3 {

                cell.more.isEnabled = true
                cell.more.isHidden = false
                cell.more.setTitle("…", for: .normal)
            }

            var buttonWidth = max(cell.primary.intrinsicContentSize.width, cell.secondary.intrinsicContentSize.width)
            buttonWidth += 30
            cell.primaryWidth.constant = buttonWidth
            cell.secondaryWidth.constant = buttonWidth
        }

        return cell
    }

    // MARK: - tap Action

    func tapRemove(with notification: NKNotifications, sender: Any?) {

        NextcloudKit.shared.setNotification(serverUrl: nil, idNotification: notification.idNotification, method: "DELETE", account: session.account) { _, _, error in
            if error == .success {
                if let index = self.notifications
                    .firstIndex(where: { $0.idNotification == notification.idNotification }) {
                    self.notifications.remove(at: index)
                }
                self.tableView.reloadData()
            } else if error != .success {
                NCContentPresenter().showError(error: error)
            } else {
                print("[Error] The user has been changed during networking process.")
            }
        }
    }

    func tapAction(with notification: NKNotifications, label: String, sender: Any?) {
        if notification.app == NCGlobal.shared.spreedName,
           let roomToken = notification.objectId.split(separator: "/").first,
           let talkUrl = URL(string: "nextcloudtalk://open-conversation?server=\(session.urlBase)&user=\(session.userId)&withRoomToken=\(roomToken)"),
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

            NextcloudKit.shared.setNotification(serverUrl: serverUrl, idNotification: 0, method: method, account: session.account) { _, _, error in
                if error == .success {
                    if let index = self.notifications.firstIndex(where: { $0.idNotification == notification.idNotification }) {
                        self.notifications.remove(at: index)
                    }
                    self.tableView.reloadData()
                    if self.navigationController?.presentingViewController != nil, notification.app == NCGlobal.shared.twoFactorNotificatioName {
                        self.dismiss(animated: true)
                    }
                } else if error != .success {
                    NCContentPresenter().showError(error: error)
                } else {
                    print("[Error] The user has been changed during networking process.")
                }

            }
        } // else: Action not found
    }

    func tapMore(with notification: NKNotifications, sender: Any?) {
       toggleMenu(notification: notification, sender: sender)
    }

    // MARK: - Load notification networking

   @objc func getNetwokingNotification(_ sender: Any?) {

       self.tableView.reloadData()
       NextcloudKit.shared.getNotifications(account: session.account) { task in
           self.dataSourceTask = task
           self.tableView.reloadData()
       } completion: { account, notifications, _, error in
           if error == .success, let notifications = notifications {
               self.notifications.removeAll()
               let sortedNotifications = notifications.sorted { $0.date > $1.date }
               for notification in sortedNotifications {
                   if let icon = notification.icon {
                       self.utility.convertSVGtoPNGWriteToUserData(svgUrlString: icon, width: 25, rewrite: false, account: account) { _, _ in
                           self.tableView.reloadData()
                       }
                   }
                   self.notifications.append(notification)
               }
               self.refreshControl?.endRefreshing()
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
    @IBOutlet weak var more: UIButton!
    @IBOutlet weak var avatarLeadingMargin: NSLayoutConstraint!
    @IBOutlet weak var primaryWidth: NSLayoutConstraint!
    @IBOutlet weak var secondaryWidth: NSLayoutConstraint!

    private var user = ""
    private var index = IndexPath()

    weak var delegate: NCNotificationCellDelegate?
    var notification: NKNotifications?

    var indexPath: IndexPath {
        get { return index }
        set { index = newValue }
    }
    var fileAvatarImageView: UIImageView? {
        return avatar
    }
    var fileUser: String? {
        get { return user }
        set { user = newValue ?? "" }
    }

    @IBAction func touchUpInsideRemove(_ sender: Any) {
        guard let notification = notification else { return }
        delegate?.tapRemove(with: notification, sender: sender)
    }

    @IBAction func touchUpInsidePrimary(_ sender: Any) {
        guard let notification = notification,
                let button = sender as? UIButton,
                let label = button.titleLabel?.text
        else { return }
        delegate?.tapAction(with: notification, label: label, sender: sender)
    }

    @IBAction func touchUpInsideSecondary(_ sender: Any) {
        guard let notification = notification,
                let button = sender as? UIButton,
                let label = button.titleLabel?.text
        else { return }
        delegate?.tapAction(with: notification, label: label, sender: sender)
    }

    @IBAction func touchUpInsideMore(_ sender: Any) {
        guard let notification = notification else { return }
        delegate?.tapMore(with: notification, sender: sender)
    }
}

protocol NCNotificationCellDelegate: AnyObject {
    func tapRemove(with notification: NKNotifications, sender: Any?)
    func tapAction(with notification: NKNotifications, label: String, sender: Any?)
    func tapMore(with notification: NKNotifications, sender: Any?)
}
