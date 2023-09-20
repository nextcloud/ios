//
//  NCMediaUI.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/09/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import SwiftUI

class NCMediaUI: UIViewController, ObservableObject {

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.navigationBar.isHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = true
        addView()
    }

    func addView() {
        let testView = NCMediaNew()
        let controller = UIHostingController(rootView: testView.environmentObject(self))
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

/*
struct SwiftUIView: View {
    @EnvironmentObject var parent: NCMediaUI
    var body: some View {
        Button {
            // push new view controller
            // parent.navigationController?.pushViewController(<#T##viewController: UIViewController##UIViewController#>, animated: <#T##Bool#>)
        } label: {
            Text("go")
        }
    }
}
*/
