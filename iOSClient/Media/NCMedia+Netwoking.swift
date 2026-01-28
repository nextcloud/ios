// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Alamofire

extension NCMedia {
    func searchMediaAsync(path: String = "",
                          lessDate: Any,
                          greaterDate: Any,
                          elementDate: String,
                          limit: Int,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, files: [NKFile]?, error: NKError) {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account) else {
            return (account, nil, .urlError)
        }
        let files: [NKFile] = []
        let elementDate = elementDate + "/"
        var greaterDateString: String?, lessDateString: String?
        let href = "/files/" + nkSession.userId + path
        if let lessDate = lessDate as? Date {
            lessDateString = lessDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        } else if let lessDate = lessDate as? Int {
            lessDateString = String(lessDate)
        }
        if let greaterDate = greaterDate as? Date {
            greaterDateString = greaterDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        } else if let greaterDate = greaterDate as? Int {
            greaterDateString = String(greaterDate)
        }
        guard let lessDateString, let greaterDateString else {
            return (account, files, .invalidDate)
        }

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
                    <d:prop><\(elementDate)></d:prop>
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
                            <d:prop><\(elementDate)></d:prop>
                            <d:literal>\(lessDate)</d:literal>
                        </d:lt>
                        <d:gt>
                            <d:prop><\(elementDate)></d:prop>
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
}

extension Date {
    func formatted(using format: String) -> String {
        NKLogFileManager.shared.convertDate(self, format: format)
    }
}
