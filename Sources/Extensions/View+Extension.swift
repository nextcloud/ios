//
//  View+Extension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 29/12/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import SwiftUI

extension View {

    func complexModifier<V: View>(@ViewBuilder _ closure: (Self) -> V) -> some View {
        closure(self)
    }
}
