// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKitUI
import SwiftUI
import UIKit

/// The onboarding and login of NextcloudKitUI, shown while the app has no account and to add one.
struct NCAccountSetupView: View {
    @Bindable var model: NCAccountSetupModel

    var body: some View {
        ZStack {
            if model.showsOnboarding {
                OnboardingView(title: String.localizedStringWithFormat(NSLocalizedString("_onboarding_title_", comment: ""), NCBrandOptions.shared.brand),
                               features: features,
                               tint: Color(uiColor: NCBrandColor.shared.customer)) {
                    withAnimation {
                        model.showsOnboarding = false
                    }
                }
                .transition(.opacity)
            } else {
                ServerAddressView(backgroundColor: .constant(Color(uiColor: NCBrandColor.shared.customer)),
                                  brandImage: Image("logo"),
                                  sharedAccounts: model.sharedAccounts,
                                  userAgent: userAgent,
                                  configuration: model.configuration) { host, name, password in
                    try await model.addAccount(host: host, user: name, password: password)
                }
                .onAppear {
                    model.loginDidAppear()
                }
                .transition(.opacity)
            }
        }
        .alert(NSLocalizedString("_ssl_certificate_untrusted_", comment: ""), isPresented: $model.isPresentingCertificatePrompt) {
            Button(NSLocalizedString("_yes_", comment: "")) {
                model.answer(true)
            }

            Button(NSLocalizedString("_no_", comment: "")) {
                model.answer(false)
            }

            Button(NSLocalizedString("_certificate_details_", comment: "")) {
                model.presentCertificateDetails()
            }
        } message: {
            Text(NSLocalizedString("_connect_server_anyway_", comment: ""))
        }
        .alert(NSLocalizedString("_warning_", comment: ""), isPresented: $model.isPresentingInsecureConnectionPrompt) {
            Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) {
                model.answer(false)
            }

            Button(NSLocalizedString("_continue_", comment: ""), role: .destructive) {
                model.answer(true)
            }
        } message: {
            Text(NSLocalizedString("_https_failed_try_http_", comment: ""))
        }
        .sheet(isPresented: $model.isPresentingCertificateDetails) {
            // The details close themselves, which a sheet binding may not notice.
            certificateDetailsView(host: model.certificateHost, title: NSLocalizedString("_certificate_view_", comment: "")) {
                model.certificateDetailsDidClose()
            }
        }
        .onDisappear {
            // A login must not wait for a prompt of a setup that is gone.
            model.answer(false)
        }
    }

    private var features: [OnboardingFeature] {
        [
            OnboardingFeature(icon: Image(systemName: "lock.shield"), title: NSLocalizedString("_intro_1_title_", comment: "")),
            OnboardingFeature(icon: Image(systemName: "person.2"), title: NSLocalizedString("_intro_2_title_", comment: "")),
            OnboardingFeature(icon: Image(systemName: "envelope"), title: NSLocalizedString("_intro_3_title_", comment: "")),
            OnboardingFeature(icon: Image(systemName: "video"), title: NSLocalizedString("_intro_4_title_", comment: ""))
        ]
    }

    /// The setup in a full screen controller, for the root of a window or to present on the tab bar.
    /// - Parameter controller: The tab bar to present the setup on.
    static func viewController(controller: NCMainTabBarController? = nil) -> UIViewController {
        let model = NCAccountSetupModel(controller: controller)
        let viewController = UIHostingController(rootView: NCAccountSetupView(model: model))

        viewController.modalPresentationStyle = .fullScreen
        viewController.view.backgroundColor = model.showsOnboarding ? .systemBackground : NCBrandColor.shared.customer
        model.presenter = viewController

        return viewController
    }
}
