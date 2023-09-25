//
//  NCMediaUI.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/09/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import SwiftUI

/**
 Wraps the SwiftUI view to a ViewController with a NavigationViewController
 */
class NCMediaUIKitWrapper: UIViewController, ObservableObject {
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.navigationBar.isHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = true
        addView()
    }

    func addView() {
        let mediaView = NCMediaNew()
        let controller = UIHostingController(rootView: mediaView.environmentObject(self))
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        controller.didMove(toParent: self)

        NSLayoutConstraint.activate([
            controller.view.widthAnchor.constraint(equalTo: view.widthAnchor),
            controller.view.heightAnchor.constraint(equalTo: view.heightAnchor),
            controller.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            controller.view.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
