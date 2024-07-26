//
<<<<<<<< HEAD:iOSClient/Main/Collection Common/NCCollectionViewCommon+EndToEndInitialize.swift
//  NCCollectionViewCommon+EndToEndInitialize.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/07/24.
========
//  LazyView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/06/24.
>>>>>>>> origin/master:iOSClient/GUI/LazyView.swift
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

<<<<<<<< HEAD:iOSClient/Main/Collection Common/NCCollectionViewCommon+EndToEndInitialize.swift
import Foundation
import UIKit

extension NCCollectionViewCommon: NCEndToEndInitializeDelegate {
    func endToEndInitializeSuccess(metadata: tableMetadata?) {
        if let metadata {
            pushMetadata(metadata)
        }
========
import SwiftUI

/// LazyView is a view that delays the initialization of its contained view until it is actually needed.
struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
>>>>>>>> origin/master:iOSClient/GUI/LazyView.swift
    }
}
