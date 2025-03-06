// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI
import NextcloudKit

extension NCNetworking {
    func termsOfService(account: String) {
        guard let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier),
              let controller = SceneManager.shared.getControllers().first(where: { $0.account == account }) else {
            return
        }
        let options = NKRequestOptions(checkInterceptor: false)

        NextcloudKit.shared.getTermsOfService(account: account, options: options) { _, tos, _, error in
            var tosArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String] ?? []

            if error == .success, let tos {
                if !tosArray.contains(account) {
                    tosArray.append(account)
                    groupDefaults.set(tosArray, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS)
                }

                let termOfServiceModel = NCTermOfServiceModel(controller: controller, tos: tos)
                let termOfServiceView = NCTermOfServiceModelView(model: termOfServiceModel)
                let termOfServiceController = UIHostingController(rootView: termOfServiceView)
                controller.present(termOfServiceController, animated: true, completion: nil)
            } else {
                tosArray.removeAll { $0 == account }
                groupDefaults.set(tosArray, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS)
            }
        }
    }

    func signTermsOfService(account: String, termId: Int, completion: @escaping (NKError) -> Void) {
        let options = NKRequestOptions(checkInterceptor: false)

        NextcloudKit.shared.signTermsOfService(termId: "\(termId)", account: account, options: options) { _, _, error in
            completion(error)
        }
    }
}
