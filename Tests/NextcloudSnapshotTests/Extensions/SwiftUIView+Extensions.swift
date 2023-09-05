//
//  SwiftUIView+Extensions.swift
//  Nextcloud
//
//  Created by Milen on 06.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import SwiftUI

// Custom view modifier to track rotation and call an action
struct DeviceOrientationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

extension SwiftUI.View {
    func toVC() -> UIViewController {
        let vc = UIHostingController (rootView: self)
        vc.view.frame = UIScreen.main.bounds
        return vc
    }

    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceOrientationViewModifier(action: action))
    }
}
