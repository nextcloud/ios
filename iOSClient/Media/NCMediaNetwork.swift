// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Alamofire

final class NCMediaNetwork {
    func searchMediaPage(path: String,
                         firstDate: Date,
                         lastDate: Date,
                         account: String,
                         paginate: Bool,
                         limit: Int,
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         update: @escaping (_ files: [NKFile]) async -> Void,
                         finish: @escaping () -> Void) async {
        guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: account) else {
            finish()
            return
        }
        let nkComm = NextcloudKit.shared.nkCommonInstance
        let href = "/files/" + nkSession.userId + path

        let elementDate = "d:" + NCGlobal.shared.mediaPropOrder
        let lessDateString = firstDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        let greaterDateString = lastDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")

        var paginateToken: String?
        var error = NKError()
        let paginateCount = 200
        var page = 0
        var paginateOffset = 0

        let httpBodyString = String(format: getRequestBodySearchMedia(
            href: href,
            elementDate: elementDate,
            lessDate: lessDateString,
            greaterDate: greaterDateString,
            limit: String(limit))
        )

        guard let httpBody = httpBodyString.data(using: .utf8) else {
            finish()
            return
        }

        while true {
            var isPaginate: Bool = false
            let options = NKRequestOptions(timeout: 180,
                                           taskDescription: NCGlobal.shared.taskDescriptionRetrievesProperties,
                                           paginate: paginate,
                                           paginateToken: paginateToken,
                                           paginateOffset: paginateOffset,
                                           paginateCount: paginateCount,
                                           queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

            let results = await NextcloudKit.shared.searchAsync(serverUrl: nkSession.urlBase, httpBody: httpBody, showHiddenFiles: false, includeHiddenFiles: [], account: account, options: options, taskHandler: taskHandler)
            error = results.error

            if error == .success {
                if let filesUnordered = results.files {
                    let files = filesUnordered.sorted {
                        $0.date > $1.date
                    }
                    await update(files)
                }
                let allHeaderFields = results.responseData?.response?.allHeaderFields
                if let result = nkComm.findHeader("x-nc-paginate-token", allHeaderFields: allHeaderFields) {
                    paginateToken = result
                }
                if let result = nkComm.findHeader("x-nc-paginate", allHeaderFields: allHeaderFields) {
                    isPaginate = Bool(result) ?? false
                }
            } else {
                finish()
                break
            }

            nkLog(info: "\(lessDateString) - \(greaterDateString) - \(isPaginate)", consoleOnly: true)

            if !isPaginate || (results.files?.count ?? 0) < paginateCount {
                finish()
                break
            }

            page += 1
            paginateOffset = page * paginateCount
        }
    }

    internal func getRequestBodySearchMedia(href: String,
                                            elementDate: String,
                                            lessDate: String,
                                            greaterDate: String,
                                            limit: String) -> String {
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
                    <d:getetag/>
                    <d:getlastmodified />
                    <upload_time xmlns="http://nextcloud.org/ns"/>
                    <size xmlns="http://owncloud.org/ns"/>
                    <has-preview xmlns="http://nextcloud.org/ns"/>
                    <metadata-files-live-photo xmlns="http://nextcloud.org/ns"/>
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
