//
//  PreviewSnapshots+Extensions.swift
//  Nextcloud
//
//  Created by Milen on 07.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import PreviewSnapshots
import SwiftUI

extension PreviewSnapshots {
    public init<V: View>(
        configure: @escaping (State) -> V
    ) {
        self.init(configurations: [.init(name: "Default", state: "" as! State)], configure: configure)
    }
}
