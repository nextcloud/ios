// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// View controllers conforming to this gain the convenience method ``setNavigationTitle()`` to set the navigation title in a convenient and consistent way.
///
protocol NCShareNavigationTitleSetting {
    var share: Shareable! { get }
}

// MARK: - UIViewController Extension

extension NCShareNavigationTitleSetting where Self: UIViewController {
    ///
    /// Consolidated convenience method to set a view controller navigation title for a share.
    ///
    func setNavigationTitle() {
        title = NSLocalizedString("_share_", comment: "") + " – "

        if share.shareType == NCShareCommon().SHARE_TYPE_LINK {
            title! += share.label.isEmpty ? NSLocalizedString("_share_link_", comment: "") : share.label
        } else {
            title! += share.shareWithDisplayname.isEmpty ? share.shareWith : share.shareWithDisplayname
        }
    }
}
