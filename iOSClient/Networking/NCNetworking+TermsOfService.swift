// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI
import NextcloudKit

extension NCNetworking {
    func termsOfService(account: String, completion: @escaping () -> Void = {}) {
        guard let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier),
              let controller = SceneManager.shared.getControllers().first(where: { $0.account == account }),
              controller.presentedViewController as? UIHostingController<NCTermOfServiceModelView> == nil
        else {
            return completion()
        }

        var tosArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String] ?? []
        let options = NKRequestOptions(checkInterceptor: false)

        NextcloudKit.shared.getTermsOfService(account: account, options: options) { _, tos, _, error in
            if error == .success, let tos, !tos.hasUserSigned() {
                let termOfServiceModel = NCTermOfServiceModel(controller: controller, tos: tos)
                let termOfServiceView = NCTermOfServiceModelView(model: termOfServiceModel)
                let termOfServiceController = UIHostingController(rootView: termOfServiceView)

                controller.present(termOfServiceController, animated: true, completion: nil)
            } else {
                tosArray.removeAll { $0 == account }
                groupDefaults.set(tosArray, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS)
            }

            completion()
        }
    }

    func signTermsOfService(account: String, termId: Int, completion: @escaping (NKError) -> Void) {
        guard let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier)
        else {
            return
        }
        var tosArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String] ?? []
        let options = NKRequestOptions(checkInterceptor: false)

        NextcloudKit.shared.signTermsOfService(termId: "\(termId)", account: account, options: options) { _, _, error in
            if error == .success {
                tosArray.removeAll { $0 == account }
                groupDefaults.set(tosArray, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS)
            }
            completion(error)
        }
    }
}
