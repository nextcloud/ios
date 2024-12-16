//
//  NCLoginPollModel.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 16.12.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

class NCLoginPollModel: ObservableObject {
//    var loginFlowV2Token = ""
//    var loginFlowV2Endpoint = ""
//    var loginFlowV2Login = ""

    @Published var pollFinished = false
    @Published var isLoading = false
    @Published var account = ""

    var timer: DispatchSourceTimer?

    func configure() {
//        self.loginFlowV2Token = loginFlowV2Token
//        self.loginFlowV2Endpoint = loginFlowV2Endpoint
//        self.loginFlowV2Login = loginFlowV2Login
//
//        poll()
    }

    func poll() {
        let queue = DispatchQueue.global(qos: .background)
        timer = DispatchSource.makeTimerSource(queue: queue)

        guard let timer = timer else { return }

        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .seconds(1))
        timer.setEventHandler(handler: {
            DispatchQueue.main.async {
                let controller = UIApplication.shared.firstWindow?.rootViewController as? NCMainTabBarController
                NextcloudKit.shared.getLoginFlowV2Poll(token: self.loginFlowV2Token, endpoint: self.loginFlowV2Endpoint) { server, loginName, appPassword, _, error in
                    if error == .success, let urlBase = server, let user = loginName, let appPassword {
                        self.isLoading = true
                        NCAccount().createAccount(urlBase: urlBase, user: user, password: appPassword, controller: controller) { account, error in
                            if error == .success {
                                self.account = account
                                self.pollFinished = true
                            }
                        }
                    }
                }
            }
        })

        timer.resume()
    }

    func onDisappear() {
        timer?.cancel()
    }

    func openLoginInBrowser() {
        UIApplication.shared.open(URL(string: loginFlowV2Login)!)
    }
}
