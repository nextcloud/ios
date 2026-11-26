// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Alamofire

final class NCMediaNetwork {
    private static let captureDateProperty = "nc:metadata-photos-original_date_time"

    enum DateSort: String, Sendable {
        case modified = "date"
        case captured = "datePhotosOriginal"

        func date(for file: NKFile) -> Date {
            switch self {
            case .modified: file.date
            case .captured: file.datePhotosOriginal ?? file.date
            }
        }
    }

    @MainActor
    func searchMediaPage(path: String,
                         firstDate: Date,
                         lastDate: Date,
                         account: String,
                         dateSort: DateSort,
                         paginate: Bool,
                         limit: Int,
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         update: @escaping (_ files: [NKFile]) async -> Void,
                         finish: @escaping () -> Void) async {
        defer { finish() }

        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account) else {
            return
        }
        let href = "/files/" + nkSession.userId + path
        let modifiedProperty = "d:" + NCGlobal.shared.mediaPropOrder
        let modifiedFirstDate = firstDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let modifiedLastDate = lastDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")

        if dateSort == .modified {
            let body = getRequestBodySearchMedia(href: href, elementDate: modifiedProperty,
                                                 lessDate: modifiedFirstDate, greaterDate: modifiedLastDate, limit: String(limit))
            _ = await search(urlBase: nkSession.urlBase, account: account, body: body, paginate: paginate, taskHandler: taskHandler) { files in
                await update(files.sorted { $0.date > $1.date })
            }
            return
        }

        // DAV can sort by either property, but cannot order by a fallback expression.
        // Fetch the top results for each disjoint set before applying the shared limit.
        let capturedFirstDate = Int64(firstDate.timeIntervalSince1970.rounded(.down))
        let capturedLastDate = max(1, Int64(lastDate.timeIntervalSince1970.rounded(.up)))
        var files: [NKFile] = []
        if capturedFirstDate >= capturedLastDate {
            let capturedBody = getRequestBodySearchMedia(href: href, elementDate: Self.captureDateProperty,
                                                         lessDate: String(capturedFirstDate), greaterDate: String(capturedLastDate), limit: String(limit))
            guard await search(urlBase: nkSession.urlBase, account: account, body: capturedBody, paginate: paginate, taskHandler: taskHandler, update: {
                files.append(contentsOf: $0)
            }) else {
                return
            }
        }

        let fallbackBody = getRequestBodySearchMedia(href: href, elementDate: modifiedProperty,
                                                     lessDate: modifiedFirstDate, greaterDate: modifiedLastDate, limit: String(limit),
                                                     missingCaptureDate: true)
        guard await search(urlBase: nkSession.urlBase, account: account, body: fallbackBody, paginate: paginate, taskHandler: taskHandler, update: {
            files.append(contentsOf: $0)
        }), !Task.isCancelled else {
            return
        }

        let sortedFiles = files.sorted { dateSort.date(for: $0) > dateSort.date(for: $1) }
        await update(Array(sortedFiles.prefix(limit)))
    }

    @MainActor
    private func search(urlBase: String,
                        account: String,
                        body: String,
                        paginate: Bool,
                        taskHandler: @escaping (URLSessionTask) -> Void,
                        update: ([NKFile]) async -> Void) async -> Bool {
        let nkComm = NextcloudKit.shared.nkCommonInstance
        let httpBody = Data(body.utf8)
        var paginateToken: String?
        let paginateCount = 200
        var paginateOffset = 0

        while !Task.isCancelled {
            let options = NKRequestOptions(timeout: 180,
                                           taskDescription: NCGlobal.shared.taskDescriptionRetrievesProperties,
                                           paginate: paginate,
                                           paginateToken: paginateToken,
                                           paginateOffset: paginateOffset,
                                           paginateCount: paginateCount,
                                           queue: .global(qos: .utility))

            let results = await NextcloudKit.shared.searchAsync(serverUrl: urlBase, httpBody: httpBody, showHiddenFiles: true, includeHiddenFiles: [], account: account, options: options, taskHandler: taskHandler)
            guard results.error == .success, let files = results.files, !Task.isCancelled else {
                return false
            }

            // Server offsets include hidden files.
            await update(files.filter { !NCMediaNetwork.isHiddenFile($0) })
            let headers = results.responseData?.response?.allHeaderFields
            guard paginate,
                  nkComm.findHeader("x-nc-paginate", allHeaderFields: headers) == "true",
                  files.count == paginateCount else {
                return true
            }
            paginateToken = nkComm.findHeader("x-nc-paginate-token", allHeaderFields: headers) ?? paginateToken
            paginateOffset += paginateCount
        }
        return false
    }

    static func isHiddenFile(_ file: NKFile) -> Bool {
        let pathComponents = (file.path as NSString).pathComponents + [file.fileName]
        return pathComponents.contains { $0.hasPrefix(".") }
    }

    internal func getRequestBodySearchMedia(href: String,
                                            elementDate: String,
                                            lessDate: String,
                                            greaterDate: String,
                                            limit: String,
                                            missingCaptureDate: Bool = false) -> String {
        let escapedHref = href.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let captureDateProperty = Self.captureDateProperty
        let captureDateFilter = missingCaptureDate ? """
            <d:or>
                <d:not>
                    <d:is-defined><d:prop><\(captureDateProperty)/></d:prop></d:is-defined>
                </d:not>
                <d:lte>
                    <d:prop><\(captureDateProperty)/></d:prop>
                    <d:literal>0</d:literal>
                </d:lte>
            </d:or>
            """ : ""
        let request = """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:basicsearch>

            <!-- ====================================================== -->
            <!-- SELECT: return the Nextcloud internal object           -->
            <!-- ====================================================== -->

            <d:select>
                <d:prop>
                    <id xmlns="http://owncloud.org/ns"/>
                    <fileid xmlns="http://owncloud.org/ns"/>
                    <permissions xmlns="http://owncloud.org/ns"/>
                    <d:getetag/>
                    <d:getlastmodified />
                    <upload_time xmlns="http://nextcloud.org/ns"/>
                    <size xmlns="http://owncloud.org/ns"/>
                    <has-preview xmlns="http://nextcloud.org/ns"/>
                    <metadata-files-live-photo xmlns="http://nextcloud.org/ns"/>
                    <\(captureDateProperty)/>
                </d:prop>
            </d:select>

            <!-- ===================================================== -->
            <!-- FROM: recursive search starting from the given href   -->
            <!-- ===================================================== -->

            <d:from>
                <d:scope>
                    <d:href>\(escapedHref)</d:href>
                    <d:depth>infinity</d:depth>
                </d:scope>
            </d:from>

            <!-- ===================================================== -->
            <!-- WHERE:                                                -->
            <!-- 1) Filter only image and video content types          -->
            <!-- 2) Apply a date range on elementDate                  -->
            <!-- ===================================================== -->

            <d:where>
                <d:and>

                    <!-- Media type filter -->
                    <d:or>
                        <d:like>
                            <d:prop><d:getcontenttype/></d:prop>
                            <d:literal>image/%</d:literal>
                        </d:like>
                        <d:like>
                            <d:prop><d:getcontenttype/></d:prop>
                            <d:literal>video/%</d:literal>
                        </d:like>
                    </d:or>

                    <!-- Date / numeric range filter LTE / GTE -->
                    <d:and>
                        <d:lte>
                            <d:prop><\(elementDate)/></d:prop>
                            <d:literal>\(lessDate)</d:literal>
                        </d:lte>
                        <d:gte>
                            <d:prop><\(elementDate)/></d:prop>
                            <d:literal>\(greaterDate)</d:literal>
                        </d:gte>
                    </d:and>
                    \(captureDateFilter)
                </d:and>
            </d:where>

            <!-- ===================================================== -->
            <!-- ORDER BY:                                             -->
            <!-- Primary sort on elementDate (descending)              -->
            <!-- Secondary sort on displayname for deterministic order -->
            <!-- ===================================================== -->

            <d:orderby>
                <d:order>
                    <d:prop><\(elementDate)/></d:prop>
                    <d:descending/>
                </d:order>
                <d:order>
                    <d:prop><d:displayname/></d:prop>
                    <d:descending/>
                </d:order>
            </d:orderby>

            <!-- ===================================================== -->
            <!-- LIMIT: maximum number of results returned             -->
            <!-- ===================================================== -->

            <d:limit>
                <d:nresults>\(limit)</d:nresults>
            </d:limit>

            </d:basicsearch>
        </d:searchrequest>
        """
        return request
    }
}

extension Date {
    func formatted(using format: String) -> String {
        NKLogFileManager.shared.convertDate(self, format: format)
    }
}
