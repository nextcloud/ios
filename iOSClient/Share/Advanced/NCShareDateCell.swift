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
    let shareCommon = NCShareCommon()

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
        let capabilities = NCCapabilities.shared.getCapabilitiesBlocking(for: account)

        switch self.shareType {
        case shareCommon.SHARE_TYPE_LINK,
            shareCommon.SHARE_TYPE_EMAIL,
            shareCommon.SHARE_TYPE_GUEST:
            return capabilities.fileSharingPubExpireDateEnforced
        case shareCommon.SHARE_TYPE_USER,
            shareCommon.SHARE_TYPE_GROUP,
            shareCommon.SHARE_TYPE_CIRCLE,
            shareCommon.SHARE_TYPE_ROOM:
            return capabilities.fileSharingInternalExpireDateEnforced
        case shareCommon.SHARE_TYPE_FEDERATED,
            shareCommon.SHARE_TYPE_FEDERATED_GROUP:
            return capabilities.fileSharingRemoteExpireDateEnforced
        default:
            return false
        }
    }

    private func defaultExpirationDays(account: String) -> Int {
        let capabilities = NCCapabilities.shared.getCapabilitiesBlocking(for: account)

        switch self.shareType {
        case shareCommon.SHARE_TYPE_LINK,
            shareCommon.SHARE_TYPE_EMAIL,
            shareCommon.SHARE_TYPE_GUEST:
            return capabilities.fileSharingPubExpireDateDays
        case shareCommon.SHARE_TYPE_USER,
            shareCommon.SHARE_TYPE_GROUP,
            shareCommon.SHARE_TYPE_CIRCLE,
            shareCommon.SHARE_TYPE_ROOM:
            return capabilities.fileSharingInternalExpireDateDays
        case shareCommon.SHARE_TYPE_FEDERATED,
            shareCommon.SHARE_TYPE_FEDERATED_GROUP:
            return capabilities.fileSharingRemoteExpireDateDays
        default:
            return 0
        }
    }
}
