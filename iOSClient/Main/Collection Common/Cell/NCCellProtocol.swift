// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

protocol NCCellProtocol {
    var metadata: tableMetadata? {get set }

    var avatarImageView: UIImageView? { get }
    var previewImageView: UIImageView? { get set }
    var title: UILabel? { get set }
    var info: UILabel? { get set }
    var subInfo: UILabel? { get set }
    var statusImageView: UIImageView? { get set }
    var localImageView: UIImageView? { get set }
    var favoriteImageView: UIImageView? { get set }
    var shareImageView: UIImageView? { get set }
    var separatorView: UIView? { get set }

    func titleInfoTrailingFull()
    func writeInfoDateSize(date: NSDate, size: Int64)
    func setButtonMore(image: UIImage)
    func hideImageItem(_ status: Bool)
    func hideImageFavorite(_ status: Bool)
    func hideImageStatus(_ status: Bool)
    func hideImageLocal(_ status: Bool)
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
    var avatarImageView: UIImageView? {
        return nil
    }
    var metadata: tableMetadata? {
        get { return nil }
        set {}
    }
    var previewImageView: UIImageView? {
        get { return nil }
        set {}
    }
    var title: UILabel? {
        get { return nil }
        set {}
    }
    var info: UILabel? {
        get { return nil }
        set { }
    }
    var subInfo: UILabel? {
        get { return nil }
        set { }
    }
    var statusImageView: UIImageView? {
        get { return nil }
        set {}
    }
    var localImageView: UIImageView? {
        get { return nil }
        set {}
    }
    var favoriteImageView: UIImageView? {
        get { return nil }
        set {}
    }
    var shareImageView: UIImageView? {
        get { return nil }
        set {}
    }

    var separatorView: UIView? {
        get { return nil }
        set {}
    }

    func titleInfoTrailingFull() {}
    func writeInfoDateSize(date: NSDate, size: Int64) {}
    func setButtonMore(image: UIImage) {}
    func hideImageItem(_ status: Bool) {}
    func hideImageFavorite(_ status: Bool) {}
    func hideImageStatus(_ status: Bool) {}
    func hideImageLocal(_ status: Bool) {}
    func hideLabelInfo(_ status: Bool) {}
    func hideLabelSubinfo(_ status: Bool) {}
    func hideButtonShare(_ status: Bool) {}
    func hideButtonMore(_ status: Bool) {}
    func selected(_ status: Bool, isEditMode: Bool) {}
    func setAccessibility(label: String, value: String) {}
    func setTags(tags: [String]) {}
    func setIconOutlines() {}
}
