// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

protocol NCCellProtocol {
    var metadata: tableMetadata? {get set }
    var avatarImageView: UIImageView? { get }
    var previewImageView: UIImageView? { get set }

    func hideButtonMore(_ status: Bool)
    func hideImageStatus(_ status: Bool)
}

extension NCCellProtocol {
    var metadata: tableMetadata? {
        get { return nil }
        set {}
    }
    var avatarImageView: UIImageView? {
        return nil
    }
    var previewImageView: UIImageView? {
        get { return nil }
        set {}
    }

    func hideButtonMore(_ status: Bool) {}
    func hideImageStatus(_ status: Bool) {}
}
