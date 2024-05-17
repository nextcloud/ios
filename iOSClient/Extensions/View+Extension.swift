//
//  View+Extension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 29/12/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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

extension View {
    func complexModifier<V: View>(@ViewBuilder _ closure: (Self) -> V) -> some View {
        closure(self)
    }

    /// Use this on preview views that are used in snapshot testing. It prevents the snapashot library from complaining that the view has a size of 0
    /// Check: https://github.com/pointfreeco/swift-snapshot-testing/issues/738
    func frameForPreview() -> some View {
        return frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    }

    func hiddenConditionally(isHidden: Bool) -> some View {
        isHidden ? AnyView(self.hidden()) : AnyView(self)
    }
}
