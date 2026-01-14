// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

protocol NCCellProtocol {
    var fileAvatarImageView: UIImageView? { get }
    var fileAccount: String? { get set }
    var fileOcId: String? { get set }
    var fileOcIdTransfer: String? { get set }
    var filePreviewImageView: UIImageView? { get set }
    var fileUser: String? { get set }
    var fileTitleLabel: UILabel? { get set }
    var fileInfoLabel: UILabel? { get set }
    var fileSubinfoLabel: UILabel? { get set }
    var fileStatusImage: UIImageView? { get set }
    var fileLocalImage: UIImageView? { get set }
    var fileFavoriteImage: UIImageView? { get set }
    var fileSharedImage: UIImageView? { get set }
    var fileMoreImage: UIImageView? { get set }
    var cellSeparatorView: UIView? { get set }

    func titleInfoTrailingDefault()
    func titleInfoTrailingFull()
    func writeInfoDateSize(date: NSDate, size: Int64)
    func setButtonMore(image: UIImage)
    func hideImageItem(_ status: Bool)
    func hideImageFavorite(_ status: Bool)
    func hideImageStatus(_ status: Bool)
    func hideImageLocal(_ status: Bool)
    func hideLabelTitle(_ status: Bool)
    func hideLabelInfo(_ status: Bool)
    func hideLabelSubinfo(_ status: Bool)
    func hideButtonShare(_ status: Bool)
    func hideButtonMore(_ status: Bool)
    func selected(_ status: Bool, isEditMode: Bool)
    func setAccessibility(label: String, value: String)
    func setTags(tags: [String])
    func setIconOutlines()
}

extension NCCellProtocol {
    var fileAvatarImageView: UIImageView? {
        return nil
    }
    var fileAccount: String? {
        get { return nil }
        set {}
    }
    var fileOcId: String? {
        get { return nil }
        set {}
    }
    var fileOcIdTransfer: String? {
        get { return nil }
        set {}
    }
    var filePreviewImageView: UIImageView? {
        get { return nil }
        set {}
    }
    var fileTitleLabel: UILabel? {
        get { return nil }
        set {}
    }
    var fileInfoLabel: UILabel? {
        get { return nil }
        set { }
    }
    var fileSubinfoLabel: UILabel? {
        get { return nil }
        set { }
    }
    var fileStatusImage: UIImageView? {
        get { return nil }
        set {}
    }
    var fileLocalImage: UIImageView? {
        get { return nil }
        set {}
    }
    var fileFavoriteImage: UIImageView? {
        get { return nil }
        set {}
    }
    var fileSharedImage: UIImageView? {
        get { return nil }
        set {}
    }
    var fileMoreImage: UIImageView? {
        get { return nil }
        set {}
    }
    var cellSeparatorView: UIView? {
        get { return nil }
        set {}
    }

    func titleInfoTrailingDefault() {}
    func titleInfoTrailingFull() {}
    func writeInfoDateSize(date: NSDate, size: Int64) {}
    func setButtonMore(image: UIImage) {}
    func hideImageItem(_ status: Bool) {}
    func hideImageFavorite(_ status: Bool) {}
    func hideImageStatus(_ status: Bool) {}
    func hideImageLocal(_ status: Bool) {}
    func hideLabelTitle(_ status: Bool) {}
    func hideLabelInfo(_ status: Bool) {}
    func hideLabelSubinfo(_ status: Bool) {}
    func hideButtonShare(_ status: Bool) {}
    func hideButtonMore(_ status: Bool) {}
    func selected(_ status: Bool, isEditMode: Bool) {}
    func setAccessibility(label: String, value: String) {}
    func setTags(tags: [String]) {}
    func setIconOutlines() {}
}
