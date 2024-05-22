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

    var cancelButtonDisabled = false

    @ObservedObject private var loginManager = LoginManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("Please continue in your browser")

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(loginManager.isLoading || cancelButtonDisabled)
                .buttonStyle(.bordered)

                Button("Retry") {
                    loginManager.openLoginInBrowser()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
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
            loginManager.configure(loginFlowV2Token: loginFlowV2Token, loginFlowV2Endpoint: loginFlowV2Endpoint, loginFlowV2Login: loginFlowV2Login)
            loginManager.openLoginInBrowser()
        }
        .interactiveDismissDisabled()
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

    @Published var pollFinished = false
    @Published var isLoading = false

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        poll()
    }

    func configure(loginFlowV2Token: String, loginFlowV2Endpoint: String, loginFlowV2Login: String) {
        self.loginFlowV2Token = loginFlowV2Token
        self.loginFlowV2Endpoint = loginFlowV2Endpoint
        self.loginFlowV2Login = loginFlowV2Login
    }

    func poll() {
        NextcloudKit.shared.getLoginFlowV2Poll(token: self.loginFlowV2Token, endpoint: self.loginFlowV2Endpoint) { server, loginName, appPassword, _, error in
            if error == .success, let server, let loginName, let appPassword {
                self.isLoading = true
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
