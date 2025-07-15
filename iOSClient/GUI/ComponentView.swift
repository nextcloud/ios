// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ButtonRounded: ButtonStyle {
    var disabled = false
    var account = ""

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 40)
            .padding(.vertical, 10)
            .background(disabled ? Color(UIColor.placeholderText) : Color(NCBrandColor.shared.getElement(account: account)))
            .foregroundColor(disabled ? Color(UIColor.placeholderText) : Color(NCBrandColor.shared.getText(account: account)))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}
