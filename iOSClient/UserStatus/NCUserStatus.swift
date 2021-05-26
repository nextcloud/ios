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
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = NSLocalizedString("_online_status_", comment: "")

        buttonCancel.title = NSLocalizedString("_cancel_", comment: "")

        onlineButton.layer.cornerRadius = 10
        onlineButton.layer.masksToBounds = true
        onlineButton.backgroundColor = NCBrandColor.shared.systemGray5
        //onlineLabel.layer.borderWidth = 0.5
        //onlineLabel.layer.borderColor = NCBrandColor.shared.brand.cgColor
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
        let offline = NCUtility.shared.getUserStatus(userIcon: nil, userStatus: "offline", userMessage: nil)
        invisibleImage.image = offline.onlineStatus
        invisibleLabel.text = offline.statusMessage
        invisibleLabel.textColor = NCBrandColor.shared.label
        invisibleDescrLabel.text = offline.descriptionMessage
        invisibleDescrLabel.textColor = .darkGray
        
        statusMessageLabel.text = NSLocalizedString("_status_message_", comment: "")
        statusMessageLabel.textColor = NCBrandColor.shared.label

        statusMessageEmojiTextField.delegate = self
        statusMessageEmojiTextField.backgroundColor = NCBrandColor.shared.systemGray5
        
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
        clearStatusMessageAfterText.textColor = .lightGray
        
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

        changeTheming()
        getStatus()
    }
    
    func dismissWithError(_ errorCode: Int, errorDescription: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismiss(animated: true) {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode, forced: true)
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
    
    // MARK: - Networking
    
    func getStatus() {
        
        NCCommunication.shared.getUserStatus { account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, userId, errorCode, errorDescription in
            
            if errorCode == 0 {
                
                self.statusMessageEmojiTextField.text = icon
                self.statusMessageTextField.text = message
                self.clearStatusMessageAfterText.text = "  " +  CCUtility.getTitleSectionDate(clearAt! as Date)
                
                switch status {
                case "online":
                    self.onlineButton.layer.borderWidth = 1.5
                    self.onlineButton.layer.borderColor = NCBrandColor.shared.brand.cgColor
                case "away":
                    self.awayButton.layer.borderWidth = 1.5
                    self.awayButton.layer.borderColor = NCBrandColor.shared.brand.cgColor
                case "dnd":
                    self.dndButton.layer.borderWidth = 1.5
                    self.dndButton.layer.borderColor = NCBrandColor.shared.brand.cgColor
                case "invisible":
                    self.invisibleButton.layer.borderWidth = 1.5
                    self.invisibleButton.layer.borderColor = NCBrandColor.shared.brand.cgColor
                default:
                    print("No status")
                }
                
                NCCommunication.shared.getUserStatusPredefinedStatuses { account, userStatuses, errorCode, errorDescription in
                    
                    if errorCode == 0 {
                        if let userStatuses = userStatuses {
                            self.statusPredefinedStatuses = userStatuses
                        }
                        
                        self.tableView.reloadData()
                        
                    } else {
                        self.dismissWithError(errorCode, errorDescription: errorDescription)
                    }
                }
            } else {
                self.dismissWithError(errorCode, errorDescription: errorDescription)
            }
        }
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
        }
        
        return true
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
        
        let status = statusPredefinedStatuses[indexPath.row]
        
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
    
    func getPredefinedClearStatusText(clearAt: NSDate?, clearAtTime: String?, clearAtType: String?) -> String {
             
        // Date
        if clearAt != nil {
            
            return CCUtility.getTitleSectionDate(clearAt! as Date)
        }
        
        // Period
        if clearAtTime != nil && clearAtType == "period" {
            
            switch clearAtTime {
            case "3600":
                return NSLocalizedString("_1_hour_", comment: "")
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
