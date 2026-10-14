// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import NextcloudKit

/// Client for the OCS API of the Collectives server app (`apps/collectives/api/v1.0`).
///
/// Page content is plain Markdown stored in the user's files, so it is read through WebDAV.
/// Requests run on the account's NextcloudKit session to reuse its authentication and certificate handling.
final class NCCollectivesNetworking: Sendable {
    static let shared = NCCollectivesNetworking()

    private let endpoint = "ocs/v2.php/apps/collectives/api/v1.0/collectives"

    private struct Envelope<Payload: Decodable>: Decodable {
        struct OCS: Decodable {
            let data: Payload
        }
        let ocs: OCS
    }

    private struct CollectivesPayload: Decodable {
        let collectives: [NCCollective]
    }

    private struct PagesPayload: Decodable {
        let pages: [NCCollectivePage]
    }

    private struct PagePayload: Decodable {
        let page: NCCollectivePage
    }

    private struct AttachmentsPayload: Decodable {
        let attachments: [NCCollectivePageAttachment]
    }

    // MARK: - Collectives

    func getCollectives(account: String) async -> Result<[NCCollective], NKError> {
        await request(account: account, path: "", method: .get, as: CollectivesPayload.self).map(\.collectives)
    }

    /// Whether the Collectives app is enabled for the account. The app does not publish capabilities.
    func isAvailable(account: String) async -> Bool {
        if case .success = await getCollectives(account: account) {
            return true
        }
        return false
    }

    // MARK: - Pages

    func getPages(collectiveId: Int, account: String) async -> Result<[NCCollectivePage], NKError> {
        await request(account: account, path: "/\(collectiveId)/pages", method: .get, as: PagesPayload.self).map(\.pages)
    }

    func createPage(title: String, parentId: Int, collectiveId: Int, account: String) async -> Result<NCCollectivePage, NKError> {
        await request(account: account,
                      path: "/\(collectiveId)/pages/\(parentId)",
                      method: .post,
                      parameters: ["title": title],
                      as: PagePayload.self).map(\.page)
    }

    func renamePage(_ page: NCCollectivePage, title: String, collectiveId: Int, account: String) async -> Result<NCCollectivePage, NKError> {
        await request(account: account,
                      path: "/\(collectiveId)/pages/\(page.id)",
                      method: .put,
                      parameters: ["title": title],
                      as: PagePayload.self).map(\.page)
    }

    /// Moves the page and its subpages to the collective's trash, from where it can be restored in the web interface.
    func trashPage(_ page: NCCollectivePage, collectiveId: Int, account: String) async -> Result<NCCollectivePage, NKError> {
        await request(account: account, path: "/\(collectiveId)/pages/\(page.id)", method: .delete, as: PagePayload.self).map(\.page)
    }

    /// Full-text search. Results depend on the server's search index, which is updated by a background job.
    func searchPages(text: String, collectiveId: Int, account: String) async -> Result<[NCCollectivePage], NKError> {
        await request(account: account,
                      path: "/\(collectiveId)/search",
                      method: .get,
                      parameters: ["searchString": text],
                      as: PagesPayload.self).map(\.pages)
    }

    // MARK: - Content

    /// The unencoded WebDAV URL of the page's Markdown file, as used by `serverUrlFileName` parameters.
    func serverUrlFileName(page: NCCollectivePage, account: String) -> String? {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account),
              let relativeFilePath = page.relativeFilePath else {
            return nil
        }
        return NKDav.homeURLStringNoSlash(urlBase: nkSession.urlBase, userId: nkSession.userId) + "/" + relativeFilePath
    }

    func getContent(page: NCCollectivePage, account: String) async -> Result<String, NKError> {
        guard let relativeFilePath = page.relativeFilePath else {
            return .failure(.urlError)
        }
        return await download(relativePath: relativeFilePath, account: account).flatMap { data in
            String(bytes: data, encoding: .utf8).map { .success($0) } ?? .failure(.invalidData)
        }
    }

    // MARK: - Attachments

    func getAttachments(page: NCCollectivePage, collectiveId: Int, account: String) async -> Result<[NCCollectivePageAttachment], NKError> {
        await request(account: account,
                      path: "/\(collectiveId)/pages/\(page.id)/attachments",
                      method: .get,
                      as: AttachmentsPayload.self).map(\.attachments)
    }

    /// Downloads a file by its path relative to the user's root folder.
    func download(relativePath: String, account: String) async -> Result<Data, NKError> {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account),
              let encodedPath = relativePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: NKDav.homeURLStringNoSlash(urlBase: nkSession.urlBase, userId: nkSession.userId) + "/" + encodedPath) else {
            return .failure(.urlError)
        }
        return await data(url: url, account: account)
    }

    /// A server-side scaled preview, much smaller than large photos.
    func preview(fileId: Int, size: Int, account: String) async -> Result<Data, NKError> {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account),
              let url = URL(string: nkSession.urlBase + "/index.php/core/preview?fileId=\(fileId)&x=\(size)&y=\(size)&a=1") else {
            return .failure(.urlError)
        }
        return await data(url: url, account: account)
    }

    // MARK: - Private

    private func data(url: URL, account: String) async -> Result<Data, NKError> {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account),
              let headers = NextcloudKit.shared.nkCommonInstance.getStandardHeaders(account: account, accept: "*/*") else {
            return .failure(.urlError)
        }

        let response = await nkSession.sessionDataNoCache
            .request(url, method: .get, headers: headers)
            .validate(statusCode: 200..<300)
            .serializingData(emptyResponseCodes: [200, 204])
            .response

        switch response.result {
        case .success(let data):
            return .success(data)
        case .failure(let error):
            return .failure(NKError(error: error, afResponse: response, responseData: response.data))
        }
    }

    private func request<Payload: Decodable>(account: String,
                                             path: String,
                                             method: HTTPMethod,
                                             parameters: [String: String]? = nil,
                                             as type: Payload.Type) async -> Result<Payload, NKError> {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account),
              let headers = NextcloudKit.shared.nkCommonInstance.getStandardHeaders(account: account),
              let url = URL(string: nkSession.urlBase + "/" + endpoint + path) else {
            return .failure(.urlError)
        }
        let encoding: ParameterEncoding = method == .get ? URLEncoding.queryString : JSONEncoding.default

        let response = await nkSession.sessionDataNoCache
            .request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response

        switch response.result {
        case .success(let data):
            do {
                return .success(try JSONDecoder().decode(Envelope<Payload>.self, from: data).ocs.data)
            } catch {
                return .failure(.invalidData)
            }
        case .failure(let error):
            return .failure(NKError(error: error, afResponse: response, responseData: response.data))
        }
    }
}
