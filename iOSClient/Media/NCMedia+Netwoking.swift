// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Alamofire

extension NCMedia {
    func searchMediaAsync(path: String = "",
                          lessDate: Date,
                          greaterDate: Date,
                          limit: Int,
                          account: String,
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, files: [NKFile]?, error: NKError) {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account) else {
            return (account, nil, .urlError)
        }
        let files: [NKFile] = []
        let href = "/files/" + nkSession.userId + path

        let elementDate = "d:getlastmodified"
        let lessDateString = lessDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let greaterDateString = greaterDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let options = NKRequestOptions(timeout: 180, taskDescription: self.global.taskDescriptionRetrievesProperties, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let httpBodyString = String(format: getRequestBodySearchMedia(
            createProperties: options.createProperties,
            removeProperties: options.removeProperties,
            href: href,
            elementDate: elementDate,
            lessDate: lessDateString,
            greaterDate: greaterDateString,
            limit: String(limit))
        )

        guard let httpBody = httpBodyString.data(using: .utf8) else {
            return (account, files, .invalidData)
        }

        let results = await NextcloudKit.shared.searchAsync(serverUrl: nkSession.urlBase, httpBody: httpBody, showHiddenFiles: false, includeHiddenFiles: [], account: account, options: options, taskHandler: taskHandler)

        return(results.account, results.files, results.error)
    }

    func getRequestBodySearchMedia(createProperties: [NKProperties]?,
                                   removeProperties: [NKProperties] = [],
                                   href: String,
                                   elementDate: String,
                                   lessDate: String,
                                   greaterDate: String,
                                   limit: String) -> String {
        // Build the DAV property list (merged create/remove rules)
        let properties = NKProperties.properties(createProperties: createProperties, removeProperties: removeProperties)

        let request = """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:basicsearch>

            <!-- ====================================================== -->
            <!-- SELECT: properties returned for each matching resource -->
            <!-- ====================================================== -->

            <d:select>
                <d:prop>\(properties)</d:prop>
            </d:select>

            <!-- ===================================================== -->
            <!-- FROM: recursive search starting from the given href   -->
            <!-- ===================================================== -->
            <d:from>
                <d:scope>
                    <d:href>\(href)</d:href>
                    <d:depth>infinity</d:depth>
                </d:scope>
            </d:from>

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
            <!-- WHERE:                                                -->
            <!-- 1) Filter only image and video content types          -->
            <!-- 2) Apply a numeric/date range on elementDate          -->
            <!-- ===================================================== -->
            <d:where>
                <d:and>

                    <!-- Media type filter -->
                    <d:or>
                        <d:like>
                            <d:prop><d:getcontenttype/></d:prop>
                            <d:literal>image/%%</d:literal>
                        </d:like>
                        <d:like>
                            <d:prop><d:getcontenttype/></d:prop>
                            <d:literal>video/%%</d:literal>
                        </d:like>
                    </d:or>

                    <!-- Date / numeric range filter -->
                    <d:and>
                        <d:lt>
                            <d:prop><\(elementDate)/></d:prop>
                            <d:literal>\(lessDate)</d:literal>
                        </d:lt>
                        <d:gt>
                            <d:prop><\(elementDate)/></d:prop>
                            <d:literal>\(greaterDate)</d:literal>
                        </d:gt>
                    </d:and>

                </d:and>
            </d:where>

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

    // MARK: - TEST

    func searchMediaPlaceholders(path: String,
                                 lessDate: Date,
                                 greaterDate: Date,
                                 account: String,
                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> ([NKFile], NKError) {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account) else {
            return ([], NKError(errorCode: NCGlobal.shared.errorOfflineNotAllowed, errorDescription: "_offline_not_allowed_"))
        }
        let nkComm = NextcloudKit.shared.nkCommonInstance
        var allFiles: [NKFile] = []
        let href = "/files/" + nkSession.userId + path

        let elementDate = "d:getlastmodified"
        let lessDateString = lessDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let greaterDateString = greaterDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")

        let httpBodyString = String(format: getRequestBodySearchMediaPlaceholders(
            href: href,
            elementDate: elementDate,
            lessDate: lessDateString,
            greaterDate: greaterDateString)
        )

        guard let httpBody = httpBodyString.data(using: .utf8) else {
            return ([], NKError(errorCode: NCGlobal.shared.errorOfflineNotAllowed, errorDescription: "_offline_not_allowed_"))
        }

        var paginatedTotal = 0
        var paginateToken: String?
        var error = NKError()
        let paginateCount = 75
        var page = 0
        var paginateOffset = 0
        var totalResults = 0

        while true {
            var isPaginate: Bool = false
            let options = NKRequestOptions(timeout: 180,
                                           taskDescription: self.global.taskDescriptionRetrievesProperties,
                                           paginate: false,
                                           paginateToken: paginateToken,
                                           paginateOffset: paginateOffset,
                                           paginateCount: paginateCount)

            let results = await NextcloudKit.shared.searchAsync(serverUrl: nkSession.urlBase, httpBody: httpBody, showHiddenFiles: false, includeHiddenFiles: [], account: account, options: options, taskHandler: taskHandler)
            error = results.error

            if error == .success {
                if let files = results.files {
                    allFiles.append(contentsOf: files)
                }
                let allHeaderFields = results.responseData?.response?.allHeaderFields
                if let result = nkComm.findHeader("x-nc-paginate-token", allHeaderFields: allHeaderFields) {
                    paginateToken = result
                }
                if let result = nkComm.findHeader("x-nc-paginate-total", allHeaderFields: allHeaderFields),
                   let total = Int(result) {
                    paginatedTotal = total
                }
                if let result = nkComm.findHeader("x-nc-paginate", allHeaderFields: allHeaderFields) {
                    isPaginate = Bool(result) ?? false
                }
            } else {
                break
            }

            if results.files?.count ?? 0 < paginateCount {
                break
            }

            if !isPaginate {
                break
            }

            if totalResults == paginatedTotal {
                break
            }

            page += 1
            paginateOffset = page * paginateCount
        }

        return (allFiles, error)
    }

    func getRequestBodySearchMediaPlaceholders(href: String, elementDate: String, lessDate: String, greaterDate: String) -> String {
        let request = """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:basicsearch>

            <!-- ====================================================== -->
            <!-- SELECT: return only the Nextcloud internal object id   -->
            <!-- ====================================================== -->

            <d:select>
                <d:prop>
                    <id xmlns="http://owncloud.org/ns"/>
                </d:prop>
            </d:select>

            <!-- ===================================================== -->
            <!-- FROM: recursive search starting from the given href   -->
            <!-- ===================================================== -->
            <d:from>
                <d:scope>
                    <d:href>\(href)</d:href>
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
                            <d:literal>image/%%</d:literal>
                        </d:like>
                        <d:like>
                            <d:prop><d:getcontenttype/></d:prop>
                            <d:literal>video/%%</d:literal>
                        </d:like>
                    </d:or>

                    <!-- Date / numeric range filter -->
                    <d:and>
                        <d:lt>
                            <d:prop><\(elementDate)/></d:prop>
                            <d:literal>\(lessDate)</d:literal>
                        </d:lt>
                        <d:gt>
                            <d:prop><\(elementDate)/></d:prop>
                            <d:literal>\(greaterDate)</d:literal>
                        </d:gt>
                    </d:and>
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
