// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Henrik Storch
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

///
/// Table view cell to manage the expiration date on a share in its details.
///
class NCShareDateCell: UITableViewCell {
    let picker = UIDatePicker()
    let textField = UITextField()
    var shareType: Int
    var onReload: (() -> Void)?

    init(share: Shareable) {
        self.shareType = share.shareType
        super.init(style: .value1, reuseIdentifier: "shareExpDate")

        picker.datePickerMode = .date
        picker.minimumDate = Date()
        picker.preferredDatePickerStyle = .wheels
        picker.action(for: .valueChanged) { datePicker in
            guard let datePicker = datePicker as? UIDatePicker else { return }
            self.detailTextLabel?.text = DateFormatter.shareExpDate.string(from: datePicker.date)
        }
        accessoryView = textField

        let toolbar = UIToolbar.toolbar {
            self.resignFirstResponder()
            share.expirationDate = nil
            self.onReload?()
        } onDone: {
            self.resignFirstResponder()
            share.expirationDate = self.picker.date as NSDate
            self.onReload?()
        }

        textField.isAccessibilityElement = false
        textField.accessibilityElementsHidden = true
        textField.inputAccessoryView = toolbar.wrappedSafeAreaContainer
        textField.inputView = picker

        if let expDate = share.expirationDate {
            detailTextLabel?.text = DateFormatter.shareExpDate.string(from: expDate as Date)
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func checkMaximumDate(account: String) {
        let defaultExpDays = defaultExpirationDays(account: account)
        if defaultExpDays > 0 && isExpireDateEnforced(account: account) {
            let enforcedInSecs = TimeInterval(defaultExpDays * 24 * 60 * 60)
            self.picker.maximumDate = Date().advanced(by: enforcedInSecs)
        }
    }

    private func isExpireDateEnforced(account: String) -> Bool {
        let capabilities = NCNetworking.shared.capabilities[account] ?? NKCapabilities.Capabilities()

        switch self.shareType {
        case NCShareCommon.shareTypeLink,
            NCShareCommon.shareTypeEmail,
            NCShareCommon.shareTypeGuest:
            return capabilities.fileSharingPubExpireDateEnforced
        case NCShareCommon.shareTypeUser,
            NCShareCommon.shareTypeGroup,
            NCShareCommon.shareTypeTeam,
            NCShareCommon.shareTypeRoom:
            return capabilities.fileSharingInternalExpireDateEnforced
        case NCShareCommon.shareTypeFederated,
            NCShareCommon.shareTypeFederatedGroup:
            return capabilities.fileSharingRemoteExpireDateEnforced
        default:
            return false
        }
    }

    private func defaultExpirationDays(account: String) -> Int {
        let capabilities = NCNetworking.shared.capabilities[account] ?? NKCapabilities.Capabilities()

        switch self.shareType {
        case NCShareCommon.shareTypeLink,
            NCShareCommon.shareTypeEmail,
            NCShareCommon.shareTypeGuest:
            return capabilities.fileSharingPubExpireDateDays
        case NCShareCommon.shareTypeUser,
            NCShareCommon.shareTypeGroup,
            NCShareCommon.shareTypeTeam,
            NCShareCommon.shareTypeRoom:
            return capabilities.fileSharingInternalExpireDateDays
        case NCShareCommon.shareTypeFederated,
            NCShareCommon.shareTypeFederatedGroup:
            return capabilities.fileSharingRemoteExpireDateDays
        default:
            return 0
        }
    }
}
