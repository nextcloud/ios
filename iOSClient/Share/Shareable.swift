// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

///
/// Shared requirements of data models used in the share link user interface  (transient ``NCTableShareOptions``, persisted ``tableShare`` and `NKShare` transfer object).
///
protocol Shareable: AnyObject {
    var shareType: Int { get set }
    var permissions: Int { get set }
    var idShare: Int { get set }
    var shareWith: String { get set }
    var hideDownload: Bool { get set }
    var password: String { get set }
    var label: String { get set }
    var note: String { get set }
    var downloadAndSync: Bool { get set }
    var expirationDate: NSDate? { get set }
    var shareWithDisplayname: String { get set }
    var attributes: String? { get set }
}

// MARK: - Default Implementations

extension Shareable {
    ///
    /// Convenience method to format ``expirationDate`` as a human readable string similar to ISO 8601 format.
    ///
    var formattedDateString: String? {
        guard let date = expirationDate else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"

        return dateFormatter.string(from: date as Date)
    }

    ///
    /// Custom implementation to compare two implementations for relevant differences.
    ///
    func hasChanges(comparedTo other: Shareable) -> Bool {
        return other.shareType != shareType
            || other.permissions != permissions
            || other.hideDownload != hideDownload
            || other.password != password
            || other.label != label
            || other.note != note
            || other.expirationDate != expirationDate
    }
}

// MARK: - tableShare Extension

extension tableShare: Shareable {
    var downloadAndSync: Bool {
        get {
            NCManageDatabase.shared.isAttributeDownloadEnabled(attributes: attributes)
        }
        set {
            attributes = NCManageDatabase.shared.setAttibuteDownload(state: newValue)
        }
    }    
}

// MARK: - NKShare Extension

extension NKShare: Shareable {
    var downloadAndSync: Bool {
        get {
             NCManageDatabase.shared.isAttributeDownloadEnabled(attributes: attributes)
        }
        set {
            attributes = NCManageDatabase.shared.setAttibuteDownload(state: newValue)
        }
    }
}

private func isAttributeDownloadEnabled(attributes: String?) -> Bool {
    if let attributes = attributes, let data = attributes.data(using: .utf8) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [Dictionary<String, Any>] {
                for sub in json {
                    let key = sub["key"] as? String
                    let enabled = sub["enabled"] as? Bool
                    let scope = sub["scope"] as? String
                    if key == "download", scope == "permissions", let enabled = enabled {
                        return enabled
                    }
                }
            }
        } catch let error as NSError { print(error) }
    }
    return true
}
