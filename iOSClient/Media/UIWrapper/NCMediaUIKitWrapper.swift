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

    var mediaView: NCMedia?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if mediaView != nil {
            navigationController?.navigationBar.isHidden = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if mediaView == nil {
            navigationController?.navigationBar.isHidden = true
            addView()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.isHidden = false
    }

    func addView() {

        mediaView = NCMedia()
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
