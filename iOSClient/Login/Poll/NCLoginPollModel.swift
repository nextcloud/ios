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

//    @Published var pollFinished = false
    @Published var isLoading = false
//    @Published var account = ""

//    var timer: DispatchSourceTimer?

//    init(delegate: NCLoginPoll, pollFinished: Bool = false, isLoading: Bool = false, account: String = "", timer: DispatchSourceTimer? = nil) {
//        self.delegate = delegate
//        self.pollFinished = pollFinished
//        self.isLoading = isLoading
//        self.account = account
//        self.timer = timer
//    }

    func configure() {
//        self.loginFlowV2Token = loginFlowV2Token
//        self.loginFlowV2Endpoint = loginFlowV2Endpoint
//        self.loginFlowV2Login = loginFlowV2Login
//
//        poll()
    }

    func openLoginInBrowser(loginFlowV2Login: String = "") {
        UIApplication.shared.open(URL(string: loginFlowV2Login)!)
    }
}

protocol NCLoginDelegate: AnyObject {
    func pollDidStart()
}
