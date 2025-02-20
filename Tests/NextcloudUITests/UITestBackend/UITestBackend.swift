// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import XCTest

///
/// An API to abstract and simplify interaction with the backend used for the UI tests.
///
/// This does not rely on NextcloudKit for now because the latter is implemented as global state which violates the test isolation principle.
/// Also, using `URLSession` enables use of the ephemeral configuration, further improving test isolation.
/// At the time of writing, NextcloudKit also does not support structured concurrency with `async` and `await` yet which simplifies test code drastically.
///
class UITestBackend {
    ///
    /// Used to decode server responses.
    ///
    private let jsonDecoder = JSONDecoder()

    ///
    /// The URLSession used for all network requests.
    ///
    private let urlSession = URLSession(configuration: .ephemeral)

    ///
    /// The base URL for all WebDAV requests.
    ///
    private let webDAVBaseURL = URL(string: "\(TestConstants.server)/remote.php/dav/files/\(TestConstants.username)/")!

    ///
    /// Add the HTTP basic authorization header which provides the credentials as a Base64 encoded string.
    ///
    /// > Warning: This authentication method is **insecure** but sufficient for use cases when UI tests run against a temporary and local test backend in a Docker container.
    ///
    private func addAuthorizationHeader(to request: inout URLRequest) {
        let credentials = "\(TestConstants.username):\(TestConstants.password)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()

        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
    }

    ///
    /// Tell the backend that responses are expected as JSON.
    ///
    private func addAcceptHeader(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    ///
    /// OCS API requests require this header.
    ///
    private func addOCSAPIRequestHeader(to request: inout URLRequest) {
        request.setValue("true", forHTTPHeaderField: "OCS-APIRequest")
    }

    ///
    /// Convenience method to reduce the amount of repeated code.
    ///
    /// - Parameters:
    ///     - method: The HTTP verb to use for the request.
    ///     - path: Everything behind `/ocs/v2.php/apps/` in the URL path part.
    ///     - queryItems: Additional query items to use.
    ///
    /// - Returns: A request prepared with the common HTTP headers.
    ///
    private func makeOCSRequest(method: String = "GET", path: String, queryItems: [String: String] = [:]) -> URLRequest {
        var url = URL(string: "\(TestConstants.server)/ocs/v2.php/\(path)")!

        for key in queryItems.keys {
            url.append(queryItems: [URLQueryItem(name: key, value: queryItems[key])])
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        addAuthorizationHeader(to: &request)
        addOCSAPIRequestHeader(to: &request)
        addAcceptHeader(to: &request)

        return request
    }

    // MARK: - Assertions

    ///
    /// Verify that there is a download limit in place for the share identified by the given token.
    ///
    func assertDownloadLimit(by token: String, count: Int?, limit: Int?, file: StaticString = #file, line: UInt = #line) async throws {
        let request = makeOCSRequest(path: "apps/files_downloadlimit/api/v1/\(token)/limit")
        let (data, info) = try await urlSession.data(for: request)
        let statusCode = (info as! HTTPURLResponse).statusCode

        guard statusCode == 200 else {
            XCTFail("Received response with unexpected status code \(statusCode)", file: file, line: line)
            throw UITestError.unexpectedResponse
        }

        let response = try jsonDecoder.decode(OCSResponse<DownloadLimitResponse>.self, from: data)

        XCTAssertEqual(count, response.data.count, "download count", file: file, line: line)
        XCTAssertEqual(limit, response.data.limit, "download limit", file: file, line: line)
    }

    ///
    /// Assert the (in)availability of the download limit capability on the server.
    ///
    func assertCapability(_ expectation: Bool, capability: KeyPath<CapabilitiesResponse.CapabilitiesResponseCapabilitiesComponent, CapabilityResponse?>, file: StaticString = #file, line: UInt = #line) async throws {
        let request = makeOCSRequest(path: "cloud/capabilities")
        let (data, info) = try await urlSession.data(for: request)
        let statusCode = (info as! HTTPURLResponse).statusCode

        guard statusCode == 200 else {
            XCTFail("Received response with unexpected status code \(statusCode)", file: file, line: line)
            throw UITestError.unexpectedResponse
        }

        let response = try jsonDecoder.decode(OCSResponse<CapabilitiesResponse>.self, from: data)
        let reality = response.data.capabilities[keyPath: capability]?.enabled ?? false

        XCTAssertEqual(expectation, reality, file: file, line: line)
    }

    ///
    /// Verify that there is no download limit in place for the share identified by the given token.
    ///
    func assertNoDownloadLimit(by token: String, file: StaticString = #file, line: UInt = #line) async throws {
        try await assertDownloadLimit(by: token, count: nil, limit: nil)
    }

    // MARK: - Getters and Setters

    ///
    /// Creates a new folder on the server.
    ///
    /// - Throws: ``UITestError/unexpectedResponse`` in case the server responds with `405 Not Allowed` when a folder with the given path already exists.
    ///
    func createFolder(_ path: String, file: StaticString = #file, line: UInt = #line) async throws {
        let url = webDAVBaseURL.appending(path: path)

        var request = URLRequest(url: url)
        addAuthorizationHeader(to: &request)
        request.httpMethod = "MKCOL"

        let (_, info) = try await urlSession.data(for: request)
        let statusCode = (info as! HTTPURLResponse).statusCode

        guard statusCode == 201 /* created */ else {
            XCTFail("Received response with unexpected status code \(statusCode)", file: file, line: line)
            throw UITestError.unexpectedResponse
        }
    }

    ///
    /// Create a new share on the server by the given file path.
    ///
    @discardableResult
    func createShare(byPath path: String, file: StaticString = #file, line: UInt = #line) async throws -> ShareResponse {
        let request = makeOCSRequest(method: "POST", path: "apps/files_sharing/api/v1/shares", queryItems: [
            "path": path,
            "shareType": "3",
        ])

        let (data, info) = try await urlSession.data(for: request)
        let statusCode = (info as! HTTPURLResponse).statusCode

        guard statusCode == 200 else {
            XCTFail("Received response with unexpected status code \(statusCode)", file: file, line: line)
            throw UITestError.unexpectedResponse
        }

        let response = try jsonDecoder.decode(OCSResponse<ShareResponse>.self, from: data)

        return response.data
    }

    ///
    /// To clean up created content after a test.
    ///
    func delete(_ path: String, file: StaticString = #file, line: UInt = #line) async throws {
        let url = webDAVBaseURL.appending(path: path)

        var request = URLRequest(url: url)
        addAuthorizationHeader(to: &request)
        request.httpMethod = "DELETE"

        let (_, info) = try await urlSession.data(for: request)
        let statusCode = (info as! HTTPURLResponse).statusCode

        guard statusCode == 204 /* no content */ || statusCode == 404 /* not found */ else {
            XCTFail("Received response with unexpected status code \(statusCode)", file: file, line: line)
            throw UITestError.unexpectedResponse
        }
    }

    ///
    /// Get all existing shares by a file or folder path.
    ///
    /// - Parameters:
    ///     - path: In most cases the test subject.
    ///
    /// - Returns: An array of share descriptions.
    ///
    func getShares(byPath path: String, file: StaticString = #file, line: UInt = #line) async throws -> [ShareResponse] {
        let request = makeOCSRequest(path: "apps/files_sharing/api/v1/shares", queryItems: [
            "path": path,
        ])

        let (data, info) = try await urlSession.data(for: request)
        let statusCode = (info as! HTTPURLResponse).statusCode

        guard statusCode == 200 else {
            XCTFail("Received response with unexpected status code \(statusCode)", file: file, line: line)
            throw UITestError.unexpectedResponse
        }

        let response = try jsonDecoder.decode(OCSResponse<[ShareResponse]>.self, from: data)

        return response.data
    }

    ///
    /// To set up a file on the backend which is required for a test.
    ///
    /// The content is automatically generated and also contains the given file name itself.
    ///
    /// - Parameters:
    ///     - fileName: The name of the file to prepare.
    ///
    func prepareTestFile(_ fileName: String, file: StaticString = #file, line: UInt = #line) async throws {
        let content = "# Test Subject\n\nThis file named \"\(fileName)\" is intended to be uploaded and used by this UI test for Nextcloud on iOS.".data(using: .utf8)!
        let url = webDAVBaseURL.appending(path: fileName)

        var request = URLRequest(url: url)
        addAuthorizationHeader(to: &request)
        request.httpMethod = "PUT"
        request.setValue("text/markdown", forHTTPHeaderField: "Content-Type")

        let (_, info) = try await urlSession.upload(for: request, from: content)
        let statusCode = (info as! HTTPURLResponse).statusCode

        guard statusCode == 201 /* created */ else {
            XCTFail("Received response with unexpected status code \(statusCode)", file: file, line: line)
            throw UITestError.unexpectedResponse
        }
    }

    ///
    /// Set a download limit on a share identified by the given token.
    ///
    func setDownloadLimit(to limit: Int, by token: String, file: StaticString = #file, line: UInt = #line) async throws {
        var request = makeOCSRequest(method: "PUT", path: "apps/files_downloadlimit/api/v1/\(token)/limit")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{\"limit\": \(limit)}".data(using: .utf8)

        let (_, info) = try await urlSession.data(for: request)
        let statusCode = (info as! HTTPURLResponse).statusCode

        guard statusCode == 200 else {
            XCTFail("Received response with unexpected status code \(statusCode)", file: file, line: line)
            throw UITestError.unexpectedResponse
        }
    }
}
