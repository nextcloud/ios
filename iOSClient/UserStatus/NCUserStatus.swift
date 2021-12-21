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

import UIKit
import Foundation
import NCCommunication
import DropDown

@available(iOS 13.0, *)
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

    private var statusPredefinedStatuses: [NCCommunicationUserStatus] = []

    private var clearAtTimestamp: Double = 0     // Unix Timestamp representing the time to clear the status

    private let borderWidthButton: CGFloat = 1.5
    private let borderColorButton: CGColor = NCBrandColor.shared.brand.cgColor

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("_online_status_", comment: "")

        buttonCancel.title = NSLocalizedString("_close_", comment: "")

        onlineButton.layer.cornerRadius = 10
        onlineButton.layer.masksToBounds = true
        onlineButton.backgroundColor = NCBrandColor.shared.systemGray5
        let onLine = NCUtility.shared.getUserStatus(userIcon: nil, userStatus: "online", userMessage: nil)
        onlineImage.image = onLine.onlineStatus
        onlineLabel.text = onLine.statusMessage
        onlineLabel.textColor = NCBrandColor.shared.label

        awayButton.layer.cornerRadius = 10
        awayButton.layer.masksToBounds = true
        awayButton.backgroundColor = NCBrandColor.shared.systemGray5
        let away = NCUtility.shared.getUserStatus(userIcon: nil, userStatus: "away", userMessage: nil)
        awayImage.image = away.onlineStatus
        awayLabel.text = away.statusMessage
        awayLabel.textColor = NCBrandColor.shared.label

        dndButton.layer.cornerRadius = 10
        dndButton.layer.masksToBounds = true
        dndButton.backgroundColor = NCBrandColor.shared.systemGray5
        let dnd = NCUtility.shared.getUserStatus(userIcon: nil, userStatus: "dnd", userMessage: nil)
        dndImage.image = dnd.onlineStatus
        dndLabel.text = dnd.statusMessage
        dndLabel.textColor = NCBrandColor.shared.label
        dndDescrLabel.text = dnd.descriptionMessage
        dndDescrLabel.textColor = .darkGray

        invisibleButton.layer.cornerRadius = 10
        invisibleButton.layer.masksToBounds = true
        invisibleButton.backgroundColor = NCBrandColor.shared.systemGray5
        let invisible = NCUtility.shared.getUserStatus(userIcon: nil, userStatus: "invisible", userMessage: nil)
        invisibleImage.image = invisible.onlineStatus
        invisibleLabel.text = invisible.statusMessage
        invisibleLabel.textColor = NCBrandColor.shared.label
        invisibleDescrLabel.text = invisible.descriptionMessage
        invisibleDescrLabel.textColor = .darkGray

        statusMessageLabel.text = NSLocalizedString("_status_message_", comment: "")
        statusMessageLabel.textColor = NCBrandColor.shared.label

        statusMessageEmojiTextField.delegate = self
        statusMessageEmojiTextField.backgroundColor = NCBrandColor.shared.systemGray5

        statusMessageTextField.delegate = self
        statusMessageTextField.placeholder = NSLocalizedString("_status_message_placehorder_", comment: "")
        statusMessageTextField.textColor = NCBrandColor.shared.label

        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.none

        clearStatusMessageAfterLabel.text = NSLocalizedString("_clear_status_message_after_", comment: "")
        clearStatusMessageAfterLabel.textColor = NCBrandColor.shared.label

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

        clearStatusMessageButton.layer.cornerRadius = 15
        clearStatusMessageButton.layer.masksToBounds = true
        clearStatusMessageButton.layer.borderWidth = 0.5
        clearStatusMessageButton.layer.borderColor = UIColor.darkGray.cgColor
        clearStatusMessageButton.backgroundColor = NCBrandColor.shared.systemGray5
        clearStatusMessageButton.setTitle(NSLocalizedString("_clear_status_message_", comment: ""), for: .normal)
        clearStatusMessageButton.setTitleColor(NCBrandColor.shared.label, for: .normal)

        setStatusMessageButton.layer.cornerRadius = 15
        setStatusMessageButton.layer.masksToBounds = true
        setStatusMessageButton.backgroundColor = NCBrandColor.shared.brand
        setStatusMessageButton.setTitle(NSLocalizedString("_set_status_message_", comment: ""), for: .normal)
        setStatusMessageButton.setTitleColor(NCBrandColor.shared.brandText, for: .normal)

        getStatus()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        changeTheming()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NCCommunication.shared.getUserStatus { account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, _, errorCode, _ in

            if errorCode == 0 {

                NCManageDatabase.shared.setAccountUserStatus(userStatusClearAt: clearAt, userStatusIcon: icon, userStatusMessage: message, userStatusMessageId: messageId, userStatusMessageIsPredefined: messageIsPredefined, userStatusStatus: status, userStatusStatusIsUserDefined: statusIsUserDefined, account: account)
            }
        }
    }

    func dismissIfError(_ errorCode: Int, errorDescription: String) {
        if errorCode != 0 && errorCode != NCGlobal.shared.errorResourceNotFound {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.dismiss(animated: true) {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }
    }

    // MARK: - Theming

    @objc func changeTheming() {

        view.backgroundColor = NCBrandColor.shared.systemBackground
        tableView.backgroundColor = NCBrandColor.shared.systemBackground

        tableView.reloadData()
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

        NCCommunication.shared.setUserStatus(status: "online") { _, errorCode, errorDescription in
            self.dismissIfError(errorCode, errorDescription: errorDescription)
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

        NCCommunication.shared.setUserStatus(status: "away") { _, errorCode, errorDescription in
            self.dismissIfError(errorCode, errorDescription: errorDescription)
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

        NCCommunication.shared.setUserStatus(status: "dnd") { _, errorCode, errorDescription in
            self.dismissIfError(errorCode, errorDescription: errorDescription)
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

        NCCommunication.shared.setUserStatus(status: "invisible") { _, errorCode, errorDescription in
            self.dismissIfError(errorCode, errorDescription: errorDescription)
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

        NCCommunication.shared.clearMessage { _, errorCode, errorDescription in

            if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }

            self.dismiss(animated: true)
        }
    }

    @IBAction func actionSetStatusMessage(_ sender: UIButton) {

        guard let message = statusMessageTextField.text else { return }

        NCCommunication.shared.setCustomMessageUserDefined(statusIcon: statusMessageEmojiTextField.text, message: message, clearAt: clearAtTimestamp) { _, errorCode, errorDescription in

            if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }

            self.dismiss(animated: true)
        }
    }

    // MARK: - Networking

    func getStatus() {

        NCCommunication.shared.getUserStatus { _, clearAt, icon, message, _, _, status, _, _, errorCode, errorDescription in

            if errorCode == 0 || errorCode == NCGlobal.shared.errorResourceNotFound {

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

                NCCommunication.shared.getUserStatusPredefinedStatuses { _, userStatuses, errorCode, errorDescription in

                    if errorCode == 0 {

                        if let userStatuses = userStatuses {
                            self.statusPredefinedStatuses = userStatuses
                        }

                        self.tableView.reloadData()
                    }

                    self.dismissIfError(errorCode, errorDescription: errorDescription)
                }

            }

            self.dismissIfError(errorCode, errorDescription: errorDescription)
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

    func getPredefinedClearStatusText(clearAt: NSDate?, clearAtTime: String?, clearAtType: String?) -> String {

        // Date
        if clearAt != nil {

            let from = Date()
            let to = clearAt! as Date

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
        if clearAtTime != nil && clearAtType == "period" {

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
        if clearAtTime != nil && clearAtType == "end-of" {

            return NSLocalizedString(clearAtTime!, comment: "")
        }

        return NSLocalizedString("_dont_clear_", comment: "")
    }
}

@available(iOS 13.0, *)
extension NCUserStatus: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {

        if textField is emojiTextField {

            if string.count == 0 {
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

@available(iOS 13.0, *)
class emojiTextField: UITextField {

    // required for iOS 13
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

@available(iOS 13.0, *)
extension NCUserStatus: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 45
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        let status = statusPredefinedStatuses[indexPath.row]

        if let messageId = status.id {

            NCCommunication.shared.setCustomMessagePredefined(messageId: messageId, clearAt: 0) { _, errorCode, errorDescription in

                cell.isSelected = false

                if errorCode == 0 {

                    let clearAtTimestampString = self.getPredefinedClearStatusText(clearAt: status.clearAt, clearAtTime: status.clearAtTime, clearAtType: status.clearAtType)

                    self.statusMessageEmojiTextField.text = status.icon
                    self.statusMessageTextField.text = status.message
                    self.clearStatusMessageAfterText.text = " " + clearAtTimestampString
                    self.clearAtTimestamp = self.getClearAt(clearAtTimestampString)
                }

                self.dismissIfError(errorCode, errorDescription: errorDescription)
            }
        }
    }
}

@available(iOS 13.0, *)
extension NCUserStatus: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return statusPredefinedStatuses.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = tableView.backgroundColor

        let status = statusPredefinedStatuses[indexPath.row]

        let icon = cell.viewWithTag(10) as! UILabel
        let message = cell.viewWithTag(20) as! UILabel

        icon.text = status.icon
        var timeString = getPredefinedClearStatusText(clearAt: status.clearAt, clearAtTime: status.clearAtTime, clearAtType: status.clearAtType)

        if let messageText = status.message {

            message.text = messageText
            timeString = " - " + timeString

            let attributedString: NSMutableAttributedString = NSMutableAttributedString(string: messageText + timeString)
            attributedString.setColor(color: .lightGray, font: UIFont.systemFont(ofSize: 15), forText: timeString)
            message.attributedText = attributedString
        }

        return cell
    }
}
