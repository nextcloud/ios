//
//  NCLoginPollModel.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 16.12.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

class NCLoginPollModel: ObservableObject {
    @Published var isLoading = false

    func openLoginInBrowser(loginFlowV2Login: String = "") {
        UIApplication.shared.open(URL(string: loginFlowV2Login)!)
    }
}
