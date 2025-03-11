// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct CustomLabelStyle: LabelStyle {
    var spacing: Double = 5

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}
