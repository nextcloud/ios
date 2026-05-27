// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import SwiftUI

@Observable
final class NCAssistantInputModel {
    var text: String = ""
    var initialText: String

    init(initialText: String = "") {
        self.initialText = initialText
    }
}
