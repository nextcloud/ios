// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import NextcloudKitUI
import SwiftUI
import UIKit

/// Connects the shared NextcloudKitUI onboarding and login to the app: branding, managed configuration, certificate trust and account creation.
@MainActor
@Observable
final class NCAccountSetupModel {
    /// Shown once before the first login, unless the brand turned it off.
    private(set) var showsOnboarding: Bool

    var isPresentingCertificatePrompt = false
    var isPresentingInsecureConnectionPrompt = false
    var isPresentingCertificateDetails = false

    /// The server whose certificate the prompt and its details are about.
    private(set) var certificateHost = ""

    /// The controller hosting the setup, which dismisses it and shows its error banners.
    @ObservationIgnored weak var presenter: UIViewController?

    @ObservationIgnored private(set) var configuration = LoginFlowConfiguration()
    @ObservationIgnored private(set) var sharedAccounts: [SharedAccount] = []

    @ObservationIgnored private let controller: NCMainTabBarController?
    @ObservationIgnored private var answerContinuation: CheckedContinuation<Bool, Never>?
    @ObservationIgnored private var hasLoginAppeared = false

    /// - Parameter controller: The tab bar the setup is presented on, or `nil` when the setup is the root of the window.
    init(controller: NCMainTabBarController?) {
        self.controller = controller

        let hasAccounts = !NCManageDatabase.shared.getAllTableAccount().isEmpty

        showsOnboarding = !NCBrandOptions.shared.disable_intro && !hasAccounts && !NCPreferences().hasSeenOnboarding
        configuration = makeConfiguration(showsCancelButton: controller != nil && hasAccounts)
        sharedAccounts = loadSharedAccounts()
    }

    func finishOnboarding() {
        NCPreferences().hasSeenOnboarding = true
        showsOnboarding = false
    }

    // MARK: - Configuration

    /// Built from the brand options when the setup is created, so values overridden by the managed configuration apply.
    private func makeConfiguration(showsCancelButton: Bool) -> LoginFlowConfiguration {
        let brandOptions = NCBrandOptions.shared
        var configuration = LoginFlowConfiguration()

        configuration.foregroundColor = NCBrandColor.shared.customer.isTooLight() ? .black : .white
        configuration.serverAddressPrompt = NSLocalizedString("_login_url_", comment: "")
        configuration.serverAddressDescription = String.localizedStringWithFormat(NSLocalizedString("_login_address_detail_", comment: ""), brandOptions.brand)
        configuration.enforcedServersPrompt = NSLocalizedString("_select_server_", comment: "")

        if case .prefill(let serverURL) = appConfigAction {
            configuration.initialServerAddress = serverURL
        } else if !brandOptions.loginBaseUrl.isEmpty {
            configuration.initialServerAddress = brandOptions.loginBaseUrl
        }

        configuration.isServerAddressEditable = !brandOptions.disable_request_login_url
        configuration.enforcedServers = brandOptions.enforce_servers.compactMap { server in
            URL(string: server.url).map { LoginFlowConfiguration.Server(name: server.name, url: $0) }
        }
        configuration.upgradesInsecureHTTP = true
        configuration.loginURLScheme = brandOptions.webLoginAutenticationProtocol.replacingOccurrences(of: "://", with: "")

        // Branded apps link to neither the nextcloud.com providers nor its install page.
        if !brandOptions.disable_intro {
            configuration.providerSignUp = URL(string: brandOptions.linkloginPreferredProviders).map {
                LoginFlowConfiguration.WebLink(title: NSLocalizedString("_sign_up_", comment: ""), url: $0)
            }

            configuration.hostingInformation = URL(string: brandOptions.linkLoginHost).map {
                LoginFlowConfiguration.WebLink(title: NSLocalizedString("_host_your_own_server_", comment: ""), url: $0)
            }
        }

        if showsCancelButton {
            configuration.onCancel = { [weak self] in
                self?.presenter?.dismiss(animated: true)
            }
        }

        configuration.onServerError = { [weak self] error, serverURL in
            await self?.recover(from: error, serverURL: serverURL) ?? .presentError
        }

        return configuration
    }

    /// Accounts of other Nextcloud apps on this device which are not added here yet.
    private func loadSharedAccounts() -> [SharedAccount] {
        // Not offered while the managed configuration logs in by itself.
        switch appConfigAction {
        case .createAccount, .requestAppPassword:
            return []
        case .prefill, nil:
            break
        }

        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroupApps),
              let shareAccounts = NKShareAccounts().getShareAccount(at: directory, application: UIApplication.shared) else {
            return []
        }

        return shareAccounts.compactMap { shareAccount in
            let predicate = NSPredicate(format: "urlBase == %@ AND user == %@", shareAccount.url, shareAccount.user)

            guard NCManageDatabase.shared.getTableAccount(predicate: predicate) == nil,
                  let host = URL(string: shareAccount.url) else {
                return nil
            }

            let name = shareAccount.name.flatMap { $0.isEmpty ? nil : $0 } ?? shareAccount.user
            let image = shareAccount.image.map { Image(uiImage: $0) } ?? Image(systemName: "person.crop.circle")

            return SharedAccount(name, user: shareAccount.user, on: host, with: image)
        }
    }

    // MARK: - Account

    func addAccount(host: URL, user: String, password: String) async throws {
        guard let presenter else { return }

        // The setup may still be sliding in, as for the managed auto-login, while the QR code scanner stays open and closes with the setup.
        await waitForTransitions()

        let controller = self.controller ?? SceneManager.shared.getController(window: UIApplication.shared.mainAppWindow)

        if let host = host.host {
            NCNetworking.shared.writeCertificate(host: host)
        }

        try await NCAccount().createAccount(viewController: presenter, urlBase: host.absoluteString, user: user, password: password, controller: controller)
    }

    /// Publishes the accounts for other apps and logs in with the managed configuration, once.
    func loginDidAppear() {
        guard !hasLoginAppeared else { return }

        hasLoginAppeared = true

        Task {
            _ = await NCAccount().updateAppsShareAccounts()
        }

        Task {
            await runAppConfigAutoLoginIfNeeded()
        }
    }

    // MARK: - Managed configuration

    private var appConfigAction: NCLoginAppConfig.Action? {
#if DEBUG
        // Passcode UI tests provision an account through the same path as the managed configuration.
        let process = ProcessInfo.processInfo
        let environment = process.environment

        if process.arguments.contains("UI_TESTING"), process.arguments.contains("UI_TESTING_PASSCODE"),
           let server = environment["UI_TESTING_PASSCODE_SERVER"],
           let username = environment["UI_TESTING_PASSCODE_USERNAME"],
           let password = environment["UI_TESTING_PASSCODE_PASSWORD"] {
            return .requestAppPassword(serverURL: server, user: username, password: password)
        }
#endif
        return NCLoginAppConfig.action(managed: UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed"),
                                       useAppConfig: NCBrandOptions.shared.use_AppConfig,
                                       disableMultiaccount: NCBrandOptions.shared.disable_multiaccount,
                                       accountCount: NCManageDatabase.shared.getAccounts()?.count ?? 0)
    }

    private func runAppConfigAutoLoginIfNeeded() async {
        do {
            let serverURL: String
            let user: String
            let password: String

            switch appConfigAction {
            case .createAccount(let url, let name, let appPassword):
                serverURL = url
                user = name
                password = appPassword
            case .requestAppPassword(let url, let name, let userPassword):
                let results = await NextcloudKit.shared.getAppPasswordAsync(url: url, user: name, password: userPassword)

                guard results.error == .success, let token = results.token else {
                    let isUnclassified = results.error == .success || results.error.kind == nil

                    throw isUnclassified ? NKError.invalidData : results.error
                }

                serverURL = url
                user = name
                password = token
            case .prefill, nil:
                return
            }

            guard let host = URL(string: serverURL) else { throw NKError.urlError }

            try await addAccount(host: host, user: user, password: password)
        } catch {
            await showErrorBanner(windowScene: presenter?.view.window?.windowScene, error: error as? NKError ?? NKError(error: error), context: .login)
        }
    }

    // MARK: - Server errors

    func recover(from error: NKError, serverURL: URL) async -> LoginFlowConfiguration.Recovery {
        switch NCLoginServerErrorClassifier.classify(error, serverURL: serverURL) {
        case .untrustedCertificate(let host):
            certificateHost = host

            guard await ask(\.isPresentingCertificatePrompt) else { return .cancel }

            NCNetworking.shared.writeCertificate(host: host)
            return .retry(serverURL)
        case .insecureFallback(let httpURL):
#if DEBUG
            return .retry(httpURL)
#else
            return await ask(\.isPresentingInsecureConnectionPrompt) ? .retry(httpURL) : .cancel
#endif
        case .generic:
            return .presentError
        }
    }

    /// Shows the prompt once nothing else is closing, and waits for its answer.
    private func ask(_ prompt: ReferenceWritableKeyPath<NCAccountSetupModel, Bool>) async -> Bool {
        await waitForTransitions()

        return await withCheckedContinuation { continuation in
            answerContinuation?.resume(returning: false)
            answerContinuation = continuation
            self[keyPath: prompt] = true
        }
    }

    /// Resumes the login waiting for the prompt.
    func answer(_ isConfirmed: Bool) {
        isPresentingCertificatePrompt = false
        isPresentingInsecureConnectionPrompt = false

        answerContinuation?.resume(returning: isConfirmed)
        answerContinuation = nil
    }

    func presentCertificateDetails() {
        isPresentingCertificateDetails = true
    }

    /// Asks again about the certificate whose details were shown.
    func certificateDetailsDidClose() {
        isPresentingCertificateDetails = false

        guard answerContinuation != nil else { return }

        isPresentingCertificatePrompt = true
    }

    // MARK: - Transitions

    /// A sheet still closing, or the setup still sliding in, would drop what is presented or dismissed next.
    private func waitForTransitions() async {
        let deadline = ContinuousClock.now + .seconds(2)

        while isTransitioning, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private var isTransitioning: Bool {
        guard let presenter else { return false }

        return presenter.isBeingPresented || presenter.presentedViewController?.isBeingDismissed == true
    }
}
