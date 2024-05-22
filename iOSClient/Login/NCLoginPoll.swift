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
    let loginFlowV2Token: String
    let loginFlowV2Endpoint: String
    let loginFlowV2Login: String

    @ObservedObject private var loginManager = LoginManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("Please continue in your browser")

            Button("Cancel") {

            }
            .buttonStyle(.borderedProminent)
        }
        .onChange(of: loginManager.pollFinished) { value in
            if value {
                let window = UIApplication.shared.firstWindow

                if window?.rootViewController is NCMainTabBarController {
                    window?.rootViewController?.dismiss(animated: true, completion: nil)
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
        .onAppear {
            loginManager.poll(loginFlowV2Token: loginFlowV2Token, loginFlowV2Endpoint: loginFlowV2Endpoint, loginFlowV2Login: loginFlowV2Login)
            loginManager.openLoginInBrowser()
        }
    }
}

#Preview {
    NCLoginPoll(loginFlowV2Token: "", loginFlowV2Endpoint: "", loginFlowV2Login: "")
}

private class LoginManager: ObservableObject {
    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    var loginFlowV2Token = ""
    var loginFlowV2Endpoint = ""
    var loginFlowV2Login = ""

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @Published var pollFinished = false

    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        poll(loginFlowV2Token: loginFlowV2Token, loginFlowV2Endpoint: loginFlowV2Endpoint, loginFlowV2Login: loginFlowV2Login)
    }

    func poll(loginFlowV2Token: String, loginFlowV2Endpoint: String, loginFlowV2Login: String) {
        self.loginFlowV2Token = loginFlowV2Token
        self.loginFlowV2Endpoint = loginFlowV2Endpoint
        self.loginFlowV2Login = loginFlowV2Login

        NextcloudKit.shared.getLoginFlowV2Poll(token: self.loginFlowV2Token, endpoint: self.loginFlowV2Endpoint) { server, loginName, appPassword, _, error in
            if error == .success, let server, let loginName, let appPassword {
                self.createAccount(server: server, username: loginName, password: appPassword)
            }
        }
    }

    func openLoginInBrowser() {
        UIApplication.shared.open(URL(string: loginFlowV2Login)!)
    }

    private func createAccount(server: String, username: String, password: String) {
        appDelegate.createAccount(server: server, username: username, password: password) { error in
            if error == .success {
                self.pollFinished = true
            }
        }
    }
}
