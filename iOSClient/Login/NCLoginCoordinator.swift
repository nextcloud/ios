// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import NextcloudKitUI
import SwiftUI
import UIKit

/// Connects the shared NextcloudKitUI login to the app: branding, managed configuration, certificate trust and account creation.
@MainActor
final class NCLoginCoordinator: NCViewCertificateDetailsDelegate {
    enum Presentation {
        case windowRoot
        case modal
        case pushed
    }

    weak var presenter: UIViewController?

    private let presentation: Presentation
    private let controller: NCMainTabBarController?
    private var certificateDetailsContinuation: CheckedContinuation<Void, Never>?

    init(controller: NCMainTabBarController?, presentation: Presentation) {
        self.controller = controller
        self.presentation = presentation
    }

    // MARK: - Configuration

    /// Built from the brand options at presentation time, so values overridden by the managed configuration apply.
    func makeConfiguration() -> LoginFlowConfiguration {
        let brandOptions = NCBrandOptions.shared
        var configuration = LoginFlowConfiguration()

        configuration.foregroundColor = NCBrandColor.shared.customer.isTooLight() ? .black : .white
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
        configuration.embedsNavigationStack = presentation != .pushed
        configuration.showsCancelButton = presentation == .modal && !NCManageDatabase.shared.getAllTableAccount().isEmpty

        configuration.onCancel = { [weak self] in
            self?.presenter?.dismiss(animated: true)
        }

        configuration.onServerError = { [weak self] error, serverURL in
            await self?.recover(from: error, serverURL: serverURL) ?? .presentError
        }

        return configuration
    }

    /// Accounts of other Nextcloud apps on this device which are not added here yet.
    func loadSharedAccounts() -> [SharedAccount] {
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

        // A closing QR scanner or shared accounts sheet would otherwise receive the dismissal below.
        await waitForPresentedViewControllerDismissal()

        let controller = self.controller ?? SceneManager.shared.getController(window: UIApplication.shared.mainAppWindow)

        if let host = host.host {
            NCNetworking.shared.writeCertificate(host: host)
        }

        try await NCAccount().createAccount(viewController: presenter, urlBase: host.absoluteString, user: user, password: password, controller: controller)
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

    func runAppConfigAutoLoginIfNeeded() async {
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
                await showErrorBanner(windowScene: presenter?.view.window?.windowScene, error: results.error == .success ? .invalidData : results.error)
                return
            }

            serverURL = url
            user = name
            password = token
        case .prefill, nil:
            return
        }

        guard let host = URL(string: serverURL) else { return }

        do {
            try await addAccount(host: host, user: user, password: password)
        } catch {
            await showErrorBanner(windowScene: presenter?.view.window?.windowScene, error: error as? NKError ?? NKError(error: error))
        }
    }

    // MARK: - Server errors

    private func recover(from error: NKError, serverURL: URL) async -> LoginFlowConfiguration.Recovery {
        switch NCLoginServerErrorClassifier.classify(error, serverURL: serverURL) {
        case .untrustedCertificate(let host):
            return await resolveUntrustedCertificate(host: host, serverURL: serverURL)
        case .insecureFallback(let httpURL):
#if DEBUG
            return .retry(httpURL)
#else
            let choice = await presentChoice(title: NSLocalizedString("_warning_", comment: ""),
                                             message: NSLocalizedString("_https_failed_try_http_", comment: ""),
                                             actions: [(NSLocalizedString("_cancel_", comment: ""), .cancel),
                                                       (NSLocalizedString("_continue_", comment: ""), .destructive)])

            return choice == 1 ? .retry(httpURL) : .cancel
#endif
        case .generic:
            return .presentError
        }
    }

    private func resolveUntrustedCertificate(host: String, serverURL: URL) async -> LoginFlowConfiguration.Recovery {
        while true {
            let choice = await presentChoice(title: NSLocalizedString("_ssl_certificate_untrusted_", comment: ""),
                                             message: NSLocalizedString("_connect_server_anyway_", comment: ""),
                                             actions: [(NSLocalizedString("_yes_", comment: ""), .default),
                                                       (NSLocalizedString("_no_", comment: ""), .default),
                                                       (NSLocalizedString("_certificate_details_", comment: ""), .default)])

            switch choice {
            case 0:
                NCNetworking.shared.writeCertificate(host: host)
                return .retry(serverURL)
            case 2:
                await presentCertificateDetails(host: host)
            default:
                return .cancel
            }
        }
    }

    // MARK: - Presentation

    private var topViewController: UIViewController? {
        var top = presenter

        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }

        return top
    }

    /// - Returns: The index of the chosen action, or `nil` when nothing could present the alert.
    private func presentChoice(title: String, message: String, actions: [(title: String, style: UIAlertAction.Style)]) async -> Int? {
        await waitForPresentedViewControllerDismissal()

        guard let topViewController else { return nil }

        return await withCheckedContinuation { continuation in
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

            for (index, action) in actions.enumerated() {
                alertController.addAction(UIAlertAction(title: action.title, style: action.style) { _ in
                    continuation.resume(returning: index)
                })
            }

            topViewController.present(alertController, animated: true)
        }
    }

    private func presentCertificateDetails(host: String) async {
        guard let topViewController,
              let navigationController = UIStoryboard(name: "NCViewCertificateDetails", bundle: nil).instantiateInitialViewController() as? UINavigationController,
              let viewController = navigationController.topViewController as? NCViewCertificateDetails else {
            return
        }

        viewController.host = host
        viewController.delegate = self

        await withCheckedContinuation { continuation in
            certificateDetailsContinuation = continuation
            topViewController.present(navigationController, animated: true)
        }
    }

    nonisolated func viewCertificateDetailsDismiss(host: String) {
        MainActor.assumeIsolated {
            certificateDetailsContinuation?.resume()
            certificateDetailsContinuation = nil
        }
    }

    private func waitForPresentedViewControllerDismissal() async {
        let deadline = ContinuousClock.now + .seconds(2)

        while presenter?.presentedViewController != nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}
