//
//  SwiftUIView+Extensions.swift
//  Nextcloud
//
//  Created by Milen on 06.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import SwiftUI

extension SwiftUI.View {
    func toVC() -> UIViewController {
        let vc = UIHostingController (rootView: self)
        vc.view.frame = UIScreen.main.bounds
        return vc
    }
}
