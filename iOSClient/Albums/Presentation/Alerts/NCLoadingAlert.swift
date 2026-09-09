//
//  NCLoadingAlert.swift
//  Nextcloud
//
//  Created by Dhanesh on 05/08/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI
import UIKit

struct NCLoadingAlert: View {
    
    var body: some View {
        
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            ProgressView(NSLocalizedString("_albums_loading_popup_desc_", comment: ""))
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(10)
        }
    }
}

//#if DEBUG
//#Preview {
//    NCLoadingAlert()
//}
//#endif

// UIKit presentation stays scoped to Albums; each operation owns its loader.
extension NCLoadingAlert {
    @MainActor
    static func show(on controller: UIViewController) -> UIHostingController<NCLoadingAlert> {
        let loader = UIHostingController(rootView: NCLoadingAlert())
        loader.view.frame = controller.view.bounds
        loader.view.backgroundColor = .clear
        loader.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        controller.addChild(loader)
        controller.view.addSubview(loader.view)
        loader.didMove(toParent: controller)
        return loader
    }

    @MainActor
    static func hide(_ loader: UIHostingController<NCLoadingAlert>) {
        loader.willMove(toParent: nil)
        loader.view.removeFromSuperview()
        loader.removeFromParent()
    }
}
