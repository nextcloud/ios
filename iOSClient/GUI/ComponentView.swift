//
//  ComponentView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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

import SwiftUI

struct TextFieldClearButton: ViewModifier {
    @Binding var text: String

    func body(content: Content) -> some View {
        HStack {
            content
            if !text.isEmpty {
                Button(
                    action: { self.text = "" },
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(UIColor.placeholderText))
                    }
                ).buttonStyle(BorderlessButtonStyle())
            }
        }
    }
}

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
