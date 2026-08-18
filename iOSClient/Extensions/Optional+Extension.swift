// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension Optional where Wrapped: Collection {
    var isEmptyOrNil: Bool {
        return self?.isEmpty ?? true
    }

    var isNotEmpty: Wrapped? {
        guard let value = self, !value.isEmpty else {
            return nil
        }
        return value
    }
}
