//
//  NCCellProtocol.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 05.06.20.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

protocol NCCellProtocol {

    var fileAvatarImageView: UIImageView? { get }
    var fileObjectId: String? { get set }
    var filePreviewImageView: UIImageView? { get set }
    var fileUser: String? { get set }
    var fileTitleLabel: UILabel? { get set }
    var fileInfoLabel: UILabel? { get set }
    var fileProgressView: UIProgressView? { get set }
    var fileSelectImage: UIImageView? { get set }
    var fileStatusImage: UIImageView? { get set }
    var fileLocalImage: UIImageView? { get set }
    var fileFavoriteImage: UIImageView? { get set }
    var fileSharedImage: UIImageView? { get set }
    var fileMoreImage: UIImageView? { get set }
    var cellSeparatorView: UIView? { get set }

    func titleInfoTrailingDefault()
    func titleInfoTrailingFull()
    func writeInfoDateSize(date: NSDate, size: Int64)
    func setButtonMore(named: String, image: UIImage)
    func hideButtonShare(_ status: Bool)
    func hideButtonMore(_ status: Bool)
    func selectMode(_ status: Bool)
    func selected(_ status: Bool)
    func setAccessibility(label: String, value: String)
    func setTags(tags: [String])
}

extension NCCellProtocol {

    var fileAvatarImageView: UIImageView? {
        return nil
    }
    var fileObjectId: String? {
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
    var fileProgressView: UIProgressView? {
        get { return nil }
        set {}
    }
    var fileSelectImage: UIImageView? {
        get { return nil }
        set {}
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
    func setButtonMore(named: String, image: UIImage) {}
    func hideButtonShare(_ status: Bool) {}
    func hideButtonMore(_ status: Bool) {}
    func selectMode(_ status: Bool) {}
    func selected(_ status: Bool) {}
    func setAccessibility(label: String, value: String) {}
    func setTags(tags: [String]) { }
}
