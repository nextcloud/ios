//
//  SwiftUIView.swift
//  Nextcloud
//
//  Created by Milen on 21.05.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import NextcloudKit
import SwiftUI

struct NCLoginPoll: View {
    var body: some View {
        Text("Please continue in your browser")

        Button("Cancel") {

        }
        .buttonStyle(.borderedProminent)
    }
}

#Preview {
    NCLoginPoll()
}

class Polling: ObservableObject {
    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    var loginFlowV2Token = ""
    var loginFlowV2Endpoint = ""
    var loginFlowV2Login = ""

    func poll() {
        NextcloudKit.shared.getLoginFlowV2Poll(token: self.loginFlowV2Token, endpoint: self.loginFlowV2Endpoint) { server, loginName, appPassword, _, error in
            if error == .success, let server, let loginName, let appPassword {
                self.createAccount(server: server, username: loginName, password: appPassword)
            }
        }
    }

    private func createAccount(server: String, username: String, password: String) {
        appDelegate.createAccount(server: server, username: username, password: password) { error in
            if error == .success {
                let window = UIApplication.shared.firstWindow

                if window?.rootViewController is NCMainTabBarController {
                    self.dismiss(animated: true)
                } else {
                    if let mainTabBarController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                        mainTabBarController.modalPresentationStyle = .fullScreen
                        mainTabBarController.view.alpha = 0
                        window?.rootViewController = mainTabBarController
                        window?.makeKeyAndVisible()
                        UIView.animate(withDuration: 0.5) {
                            mainTabBarController.view.alpha = 1
                        }
                    }
                }
            }
        }
    }
}
