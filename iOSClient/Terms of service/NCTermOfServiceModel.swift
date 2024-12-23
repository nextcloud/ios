// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

/// A model that allows the user to configure the account
class NCTermOfServiceModel: ObservableObject {
    /// Root View Controller
    var controller: NCMainTabBarController?
    /// Set true for dismiss the view
    @Published var dismissView = false
    // Data
    @Published var languages: [String: String] = [:]
    @Published var terms: [String: String] = [:]
    @Published var termsId: [String: Int] = [:]
    @Published var hasUserSigned: Bool = false

    /// Initialization code
    init(controller: NCMainTabBarController?, tos: NKTermsOfService?) {
        self.controller = controller

        if let terms = tos?.getTerms() {
            for term in terms {
                self.terms[term.languageCode] = term.body
                self.termsId[term.languageCode] = term.id
            }
        } else {
            languages = ["en": "English", "de": "Deutsch", "it": "Italiano"]
        }

        if let languages = tos?.getLanguages() {
            for language in languages {
                if self.terms[language.key] != nil {
                    self.languages[language.key] = language.value
                }
            }
        } else {
            terms = [
                "en": "These are the Terms of Service.",
                "de": "Dies sind die Allgemeinen Geschäftsbedingungen.",
                "it": "Questi sono i Termini di servizio."
            ]
        }

        if let hasUserSigned = tos?.hasUserSigned() {
            self.hasUserSigned = hasUserSigned
        }
    }

    func signTermsOfService(termId: Int?) {
        guard let termId,
              let controller
        else {
            return
        }

        NextcloudKit.shared.signTermsOfService(termId: "\(termId)", account: controller.account) { _, _, error in
            if error == .success {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterGetServerData)
                self.dismissView = true
            } else {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    deinit { }
}
