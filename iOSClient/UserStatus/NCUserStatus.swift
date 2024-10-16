//
//  NCUserStatus.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/05/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//
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

import Foundation
import UIKit
import SwiftUI
import NextcloudKit
import DropDown

class NCUserStatus: UIViewController {

    @IBOutlet weak var buttonCancel: UIBarButtonItem!

    @IBOutlet weak var onlineButton: UIButton!
    @IBOutlet weak var onlineImage: UIImageView!
    @IBOutlet weak var onlineLabel: UILabel!

    @IBOutlet weak var awayButton: UIButton!
    @IBOutlet weak var awayImage: UIImageView!
    @IBOutlet weak var awayLabel: UILabel!

    @IBOutlet weak var dndButton: UIButton!
    @IBOutlet weak var dndImage: UIImageView!
    @IBOutlet weak var dndLabel: UILabel!
    @IBOutlet weak var dndDescrLabel: UILabel!

    @IBOutlet weak var invisibleButton: UIButton!
    @IBOutlet weak var invisibleImage: UIImageView!
    @IBOutlet weak var invisibleLabel: UILabel!
    @IBOutlet weak var invisibleDescrLabel: UILabel!

    @IBOutlet weak var statusMessageLabel: UILabel!

    @IBOutlet weak var statusMessageEmojiTextField: emojiTextField!
    @IBOutlet weak var statusMessageTextField: UITextField!

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var clearStatusMessageAfterLabel: UILabel!
    @IBOutlet weak var clearStatusMessageAfterText: UILabel!

    @IBOutlet weak var clearStatusMessageButton: UIButton!
    @IBOutlet weak var setStatusMessageButton: UIButton!

    private var statusPredefinedStatuses: [NKUserStatus] = []
    private let utility = NCUtility()
    private var clearAtTimestamp: Double = 0     // Unix Timestamp representing the time to clear the status
    private let borderWidthButton: CGFloat = 1.5
    private var borderColorButton: CGColor = NCBrandColor.shared.customer.cgColor

    public var account: String = ""

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.tintColor = NCBrandColor.shared.iconImageColor
        navigationItem.title = NSLocalizedString("_online_status_", comment: "")

        view.backgroundColor = .systemBackground
        tableView.backgroundColor = .systemBackground

        borderColorButton = NCBrandColor.shared.getElement(account: account).cgColor
        buttonCancel.image = utility.loadImage(named: "xmark", colors: [NCBrandColor.shared.iconImageColor])

        onlineButton.layer.cornerRadius = 10
        onlineButton.layer.masksToBounds = true
        onlineButton.backgroundColor = .systemGray5
        let onLine = utility.getUserStatus(userIcon: nil, userStatus: "online", userMessage: nil)
        onlineImage.image = onLine.statusImage
        onlineLabel.text = onLine.statusMessage
        onlineLabel.textColor = NCBrandColor.shared.textColor

        awayButton.layer.cornerRadius = 10
        awayButton.layer.masksToBounds = true
        awayButton.backgroundColor = .systemGray5
        let away = utility.getUserStatus(userIcon: nil, userStatus: "away", userMessage: nil)
        awayImage.image = away.statusImage
        awayLabel.text = away.statusMessage
        awayLabel.textColor = NCBrandColor.shared.textColor

        dndButton.layer.cornerRadius = 10
        dndButton.layer.masksToBounds = true
        dndButton.backgroundColor = .systemGray5
        let dnd = utility.getUserStatus(userIcon: nil, userStatus: "dnd", userMessage: nil)
        dndImage.image = dnd.statusImage
        dndLabel.text = dnd.statusMessage
        dndLabel.textColor = NCBrandColor.shared.textColor
        dndDescrLabel.text = dnd.descriptionMessage
        dndDescrLabel.textColor = .darkGray

        invisibleButton.layer.cornerRadius = 10
        invisibleButton.layer.masksToBounds = true
        invisibleButton.backgroundColor = .systemGray5
        let invisible = utility.getUserStatus(userIcon: nil, userStatus: "invisible", userMessage: nil)
        invisibleImage.image = invisible.statusImage
        invisibleLabel.text = invisible.statusMessage
        invisibleLabel.textColor = NCBrandColor.shared.textColor
        invisibleDescrLabel.text = invisible.descriptionMessage
        invisibleDescrLabel.textColor = .darkGray

        statusMessageLabel.text = NSLocalizedString("_status_message_", comment: "")
        statusMessageLabel.textColor = NCBrandColor.shared.textColor

        statusMessageEmojiTextField.delegate = self
        statusMessageEmojiTextField.backgroundColor = .systemGray5

        statusMessageTextField.delegate = self
        statusMessageTextField.placeholder = NSLocalizedString("_status_message_placehorder_", comment: "")
        statusMessageTextField.textColor = NCBrandColor.shared.textColor

        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.none

        clearStatusMessageAfterLabel.text = NSLocalizedString("_clear_status_message_after_", comment: "")
        clearStatusMessageAfterLabel.textColor = NCBrandColor.shared.textColor

        clearStatusMessageAfterText.layer.cornerRadius = 5
        clearStatusMessageAfterText.layer.masksToBounds = true
        clearStatusMessageAfterText.layer.borderWidth = 0.2
        clearStatusMessageAfterText.layer.borderColor = UIColor.lightGray.cgColor
        clearStatusMessageAfterText.text = NSLocalizedString("_dont_clear_", comment: "")
        if traitCollection.userInterfaceStyle == .dark {
            clearStatusMessageAfterText.backgroundColor = .black
            clearStatusMessageAfterText.textColor = .white
        } else {
            clearStatusMessageAfterText.backgroundColor = .white
            clearStatusMessageAfterText.textColor = .black
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.actionClearStatusMessageAfterText(sender:)))
        clearStatusMessageAfterText.isUserInteractionEnabled = true
        clearStatusMessageAfterText.addGestureRecognizer(tap)
        clearStatusMessageAfterText.text = "  " + NSLocalizedString("_dont_clear_", comment: "")

        clearStatusMessageButton.layer.cornerRadius = 20
        clearStatusMessageButton.layer.masksToBounds = true
        clearStatusMessageButton.layer.borderWidth = 0.5
        clearStatusMessageButton.layer.borderColor = UIColor.darkGray.cgColor
        clearStatusMessageButton.backgroundColor = .systemGray5
        clearStatusMessageButton.setTitle(NSLocalizedString("_clear_status_message_", comment: ""), for: .normal)
        clearStatusMessageButton.setTitleColor(NCBrandColor.shared.textColor, for: .normal)

        setStatusMessageButton.layer.cornerRadius = 20
        setStatusMessageButton.layer.masksToBounds = true
        setStatusMessageButton.backgroundColor = NCBrandColor.shared.getElement(account: account)
        setStatusMessageButton.setTitle(NSLocalizedString("_set_status_message_", comment: ""), for: .normal)
        setStatusMessageButton.setTitleColor(NCBrandColor.shared.getText(account: account), for: .normal)

        getStatus()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NextcloudKit.shared.getUserStatus(account: account) { account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, _, _, error in
            if error == .success {
                NCManageDatabase.shared.setAccountUserStatus(userStatusClearAt: clearAt, userStatusIcon: icon, userStatusMessage: message, userStatusMessageId: messageId, userStatusMessageIsPredefined: messageIsPredefined, userStatusStatus: status, userStatusStatusIsUserDefined: statusIsUserDefined, account: account)
            }
        }
    }

    func dismissIfError(_ error: NKError) {
        if error != .success && error.errorCode != NCGlobal.shared.errorResourceNotFound {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.dismiss(animated: true) {
                    NCContentPresenter().showError(error: error)
                }
            }
        }
    }

    // MARK: ACTION

    @IBAction func actionCancel(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func actionOnline(_ sender: UIButton) {
        self.onlineButton.layer.borderWidth = self.borderWidthButton
        self.onlineButton.layer.borderColor = self.borderColorButton
        self.awayButton.layer.borderWidth = 0
        self.awayButton.layer.borderColor = nil
        self.dndButton.layer.borderWidth = 0
        self.dndButton.layer.borderColor = nil
        self.invisibleButton.layer.borderWidth = 0
        self.invisibleButton.layer.borderColor = nil

        NextcloudKit.shared.setUserStatus(status: "online", account: account) { _, _, error in
            self.dismissIfError(error)
        }
    }

    @IBAction func actionAway(_ sender: UIButton) {
        self.onlineButton.layer.borderWidth = 0
        self.onlineButton.layer.borderColor = nil
        self.awayButton.layer.borderWidth = self.borderWidthButton
        self.awayButton.layer.borderColor = self.borderColorButton
        self.dndButton.layer.borderWidth = 0
        self.dndButton.layer.borderColor = nil
        self.invisibleButton.layer.borderWidth = 0
        self.invisibleButton.layer.borderColor = nil

        NextcloudKit.shared.setUserStatus(status: "away", account: account) { _, _, error in
            self.dismissIfError(error)
        }
    }

    @IBAction func actionDnd(_ sender: UIButton) {
        self.onlineButton.layer.borderWidth = 0
        self.onlineButton.layer.borderColor = nil
        self.awayButton.layer.borderWidth = 0
        self.awayButton.layer.borderColor = nil
        self.dndButton.layer.borderWidth = self.borderWidthButton
        self.dndButton.layer.borderColor = self.borderColorButton
        self.invisibleButton.layer.borderWidth = 0
        self.invisibleButton.layer.borderColor = nil

        NextcloudKit.shared.setUserStatus(status: "dnd", account: account) { _, _, error in
            self.dismissIfError(error)
        }
    }

    @IBAction func actionInvisible(_ sender: UIButton) {
        self.onlineButton.layer.borderWidth = 0
        self.onlineButton.layer.borderColor = nil
        self.awayButton.layer.borderWidth = 0
        self.awayButton.layer.borderColor = nil
        self.dndButton.layer.borderWidth = 0
        self.dndButton.layer.borderColor = nil
        self.invisibleButton.layer.borderWidth = self.borderWidthButton
        self.invisibleButton.layer.borderColor = self.borderColorButton

        NextcloudKit.shared.setUserStatus(status: "invisible", account: account) { _, _, error in
            self.dismissIfError(error)
        }
    }

    @objc func actionClearStatusMessageAfterText(sender: UITapGestureRecognizer) {
        let dropDown = DropDown()
        let appearance = DropDown.appearance()
        let clearStatusMessageAfterTextBackup = clearStatusMessageAfterText.text

        if traitCollection.userInterfaceStyle == .dark {
            appearance.backgroundColor = .black
            appearance.textColor = .white
        } else {
            appearance.backgroundColor = .white
            appearance.textColor = .black
        }
        appearance.cornerRadius = 5
        appearance.shadowRadius = 0
        appearance.animationEntranceOptions = .transitionCurlUp
        appearance.animationduration = 0.25
        appearance.setupMaskedCorners([.layerMaxXMaxYCorner, .layerMinXMaxYCorner])

        dropDown.dataSource.append(NSLocalizedString("_dont_clear_", comment: ""))
        dropDown.dataSource.append(NSLocalizedString("_30_minutes_", comment: ""))
        dropDown.dataSource.append(NSLocalizedString("_1_hour_", comment: ""))
        dropDown.dataSource.append(NSLocalizedString("_4_hours_", comment: ""))
        dropDown.dataSource.append(NSLocalizedString("day", comment: ""))
        dropDown.dataSource.append(NSLocalizedString("_this_week_", comment: ""))

        dropDown.anchorView = clearStatusMessageAfterText
        dropDown.topOffset = CGPoint(x: 0, y: -clearStatusMessageAfterText.bounds.height)
        dropDown.width = clearStatusMessageAfterText.bounds.width
        dropDown.direction = .top

        dropDown.selectionAction = { _, item in

            self.clearAtTimestamp = self.getClearAt(item)
            self.clearStatusMessageAfterText.text = " " + item
        }

        dropDown.cancelAction = { [unowned self] in
            clearStatusMessageAfterText.text = clearStatusMessageAfterTextBackup
        }

        clearStatusMessageAfterText.text = " " + NSLocalizedString("_select_option_", comment: "")

        dropDown.show()
    }

    @IBAction func actionClearStatusMessage(_ sender: UIButton) {
        NextcloudKit.shared.clearMessage(account: account) { _, _, error in
            if error != .success {
                NCContentPresenter().showError(error: error)
            }

            self.dismiss(animated: true)
        }
    }

    @IBAction func actionSetStatusMessage(_ sender: UIButton) {
        guard let message = statusMessageTextField.text else { return }

        NextcloudKit.shared.setCustomMessageUserDefined(statusIcon: statusMessageEmojiTextField.text, message: message, clearAt: clearAtTimestamp, account: account) { _, _, error in
            if error != .success {
                NCContentPresenter().showError(error: error)
            }

            self.dismiss(animated: true)
        }
    }

    // MARK: - Networking

    func getStatus() {
        NextcloudKit.shared.getUserStatus(account: account) { account, clearAt, icon, message, _, _, status, _, _, _, error in
            if error == .success || error.errorCode == NCGlobal.shared.errorResourceNotFound {

                if icon != nil {
                    self.statusMessageEmojiTextField.text = icon
                }
                if message != nil {
                    self.statusMessageTextField.text = message
                }
                if clearAt != nil {
                    self.clearStatusMessageAfterText.text = "  " + self.getPredefinedClearStatusText(clearAt: clearAt, clearAtTime: nil, clearAtType: nil)
                }

                switch status {
                case "online":
                    self.onlineButton.layer.borderWidth = self.borderWidthButton
                    self.onlineButton.layer.borderColor = self.borderColorButton
                case "away":
                    self.awayButton.layer.borderWidth = self.borderWidthButton
                    self.awayButton.layer.borderColor = self.borderColorButton
                case "dnd":
                    self.dndButton.layer.borderWidth = self.borderWidthButton
                    self.dndButton.layer.borderColor = self.borderColorButton
                case "invisible", "offline":
                    self.invisibleButton.layer.borderWidth = self.borderWidthButton
                    self.invisibleButton.layer.borderColor = self.borderColorButton
                default:
                    print("No status")
                }

                NextcloudKit.shared.getUserStatusPredefinedStatuses(account: account) { _, userStatuses, _, error in
                    if error == .success {
                        if let userStatuses = userStatuses {
                            self.statusPredefinedStatuses = userStatuses
                        }

                        self.tableView.reloadData()
                    }

                    self.dismissIfError(error)
                }

            }

            self.dismissIfError(error)
        }
    }

    // MARK: - Algorithms

    func getClearAt(_ clearAtString: String) -> Double {
        let now = Date()
        let calendar = Calendar.current
        let gregorian = Calendar(identifier: .gregorian)
        let midnight = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: midnight) else { return 0 }
        guard let startweek = gregorian.date(from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return 0 }
        guard let endweek = gregorian.date(byAdding: .day, value: 6, to: startweek) else { return 0 }

        switch clearAtString {
        case NSLocalizedString("_dont_clear_", comment: ""):
            return 0
        case NSLocalizedString("_30_minutes_", comment: ""):
            let date = now.addingTimeInterval(1800)
            return date.timeIntervalSince1970
        case NSLocalizedString("_1_hour_", comment: ""), NSLocalizedString("_an_hour_", comment: ""):
            let date = now.addingTimeInterval(3600)
            return date.timeIntervalSince1970
        case NSLocalizedString("_4_hours_", comment: ""):
            let date = now.addingTimeInterval(14400)
            return date.timeIntervalSince1970
        case NSLocalizedString("day", comment: ""):
            return tomorrow.timeIntervalSince1970
        case NSLocalizedString("_this_week_", comment: ""):
            return endweek.timeIntervalSince1970
        default:
            return 0
        }
    }

    func getPredefinedClearStatusText(clearAt: Date?, clearAtTime: String?, clearAtType: String?) -> String {
        // Date
        if let clearAt {
            let from = Date()
            let to = clearAt
            let day = Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
            let hour = Calendar.current.dateComponents([.hour], from: from, to: to).hour ?? 0
            let minute = Calendar.current.dateComponents([.minute], from: from, to: to).minute ?? 0

            if day > 0 {
                if day == 1 { return NSLocalizedString("day", comment: "") }
                return "\(day) " + NSLocalizedString("_days_", comment: "")
            }

            if hour > 0 {
                if hour == 1 { return NSLocalizedString("_an_hour_", comment: "") }
                if hour == 4 { return NSLocalizedString("_4_hour_", comment: "") }
                return "\(hour) " + NSLocalizedString("_hours_", comment: "")
            }

            if minute > 0 {
                if minute >= 25 && minute <= 30 { return NSLocalizedString("_30_minutes_", comment: "") }
                if minute > 30 { return NSLocalizedString("_an_hour_", comment: "") }
                return "\(minute) " + NSLocalizedString("_minutes_", comment: "")
            }
        }
        // Period
        if let clearAtTime, clearAtType == "period" {
            switch clearAtTime {
            case "3600":
                return NSLocalizedString("_an_hour_", comment: "")
            case "1800":
                return NSLocalizedString("_30_minutes_", comment: "")
            default:
                return NSLocalizedString("_dont_clear_", comment: "")
            }
        }
        // End of
        if let clearAtTime, clearAtType == "end-of" {
            return NSLocalizedString(clearAtTime, comment: "")
        }

        return NSLocalizedString("_dont_clear_", comment: "")
    }
}

extension NCUserStatus: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField is emojiTextField {
            if string.isEmpty {
                textField.text = "😀"
                return false
            }
            textField.text = string
            textField.endEditing(true)
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

class emojiTextField: UITextField {
    override var textInputContextIdentifier: String? { "" } // return non-nil to show the Emoji keyboard ¯\_(ツ)_/¯

    override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage == "emoji" {
                return mode
            }
        }
        return nil
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        NotificationCenter.default.addObserver(self, selector: #selector(inputModeDidChange), name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
    }

    @objc func inputModeDidChange(_ notification: Notification) {
        guard isFirstResponder else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.reloadInputViews()
        }
    }
}

extension NCUserStatus: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 45
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        let status = statusPredefinedStatuses[indexPath.row]

        if let messageId = status.id {
            NextcloudKit.shared.setCustomMessagePredefined(messageId: messageId, clearAt: 0, account: account) { _, _, error in
                cell.isSelected = false

                if error == .success {
                    let clearAtTimestampString = self.getPredefinedClearStatusText(clearAt: status.clearAt, clearAtTime: status.clearAtTime, clearAtType: status.clearAtType)

                    self.statusMessageEmojiTextField.text = status.icon
                    self.statusMessageTextField.text = status.message
                    self.clearStatusMessageAfterText.text = " " + clearAtTimestampString
                    self.clearAtTimestamp = self.getClearAt(clearAtTimestampString)
                }

                self.dismissIfError(error)
            }
        }
    }
}

extension NCUserStatus: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return statusPredefinedStatuses.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let status = statusPredefinedStatuses[indexPath.row]
        let icon = cell.viewWithTag(10) as? UILabel
        let message = cell.viewWithTag(20) as? UILabel
        var timeString = getPredefinedClearStatusText(clearAt: status.clearAt, clearAtTime: status.clearAtTime, clearAtType: status.clearAtType)

        cell.backgroundColor = tableView.backgroundColor
        icon?.text = status.icon

        if let messageText = status.message {
            message?.text = messageText
            timeString = " - " + timeString
            let attributedString: NSMutableAttributedString = NSMutableAttributedString(string: messageText + timeString)
            attributedString.setColor(color: .lightGray, font: UIFont.systemFont(ofSize: 15), forText: timeString)
            message?.attributedText = attributedString
        }

        return cell
    }
}

struct UserStatusView: UIViewControllerRepresentable {
    @Binding var showUserStatus: Bool
    var account: String

    class Coordinator: NSObject {
        var parent: UserStatusView

        init(_ parent: UserStatusView) {
            self.parent = parent
        }
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let storyboard = UIStoryboard(name: "NCUserStatus", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController
        let viewController = navigationController!.topViewController as? NCUserStatus
        viewController?.account = account
        return navigationController!
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
