// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

protocol NCCellProtocol {
    var metadata: tableMetadata? {get set }
    var avatarImage: UIImageView? { get }
    var previewImage: UIImageView? { get set }
}

extension NCCellProtocol {
    var metadata: tableMetadata? {
        get { return nil }
        set {}
    }
    var avatarImage: UIImageView? {
        get { return nil }
        set {}
    }
    var previewImage: UIImageView? {
        get { return nil }
        set {}
    }
}
