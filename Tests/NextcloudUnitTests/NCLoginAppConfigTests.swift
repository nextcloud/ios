// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import Nextcloud

@Suite("Login managed configuration")
struct NCLoginAppConfigTests {
    private let server = "https://cloud.example.com"

    private func action(_ managed: [String: Any]?, useAppConfig: Bool = true, disableMultiaccount: Bool = false, accountCount: Int = 0) -> NCLoginAppConfig.Action? {
        NCLoginAppConfig.action(managed: managed, useAppConfig: useAppConfig, disableMultiaccount: disableMultiaccount, accountCount: accountCount)
    }

    @Test("Nothing without a managed configuration or server")
    func noAction() {
        #expect(action(nil) == nil)
        #expect(action([:]) == nil)
        #expect(action(["serverUrl": ""]) == nil)
        #expect(action(["username": "jane", "apppassword": "secret"]) == nil)
    }

    @Test("Server alone prefills the address")
    func prefill() {
        #expect(action(["serverUrl": server]) == .prefill(serverURL: server))
    }

    @Test("Server, user and app password create the account")
    func createAccount() {
        let managed = ["serverUrl": server, "username": "jane", "apppassword": "secret", "password": "plain"]

        #expect(action(managed) == .createAccount(serverURL: server, user: "jane", appPassword: "secret"))
    }

    @Test("Server, user and password request an app password")
    func requestAppPassword() {
        let managed = ["serverUrl": server, "username": "jane", "password": "plain"]

        #expect(action(managed) == .requestAppPassword(serverURL: server, user: "jane", password: "plain"))
    }

    @Test("Surrounding whitespace is trimmed except from the password")
    func trimming() {
        #expect(action(["serverUrl": " \(server)\n"]) == .prefill(serverURL: server))
        #expect(action(["serverUrl": server, "username": " jane ", "apppassword": "secret\n"]) == .createAccount(serverURL: server, user: "jane", appPassword: "secret"))
        #expect(action(["serverUrl": server, "username": "jane", "password": " pass "]) == .requestAppPassword(serverURL: server, user: "jane", password: " pass "))
        #expect(action(["serverUrl": "  "]) == nil)
    }

    @Test("Template placeholder values are ignored")
    func placeholders() {
        let managed = ["serverUrl": server, "username": "Username", "password": "password", "apppassword": "AppPassword"]

        #expect(action(managed) == .prefill(serverURL: server))
    }

    @Test("Ignored unless the brand enables the managed configuration")
    func disabled() {
        #expect(action(["serverUrl": server], useAppConfig: false) == nil)
    }

    @Test("A single-account brand only uses it for the first account")
    func singleAccount() {
        #expect(action(["serverUrl": server], disableMultiaccount: true, accountCount: 1) == nil)
        #expect(action(["serverUrl": server], disableMultiaccount: true, accountCount: 0) == .prefill(serverURL: server))
        #expect(action(["serverUrl": server], disableMultiaccount: false, accountCount: 1) == .prefill(serverURL: server))
    }
}
