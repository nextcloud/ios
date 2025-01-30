//
//  FilesData.swift
//  Widget
//
//  Created by Marino Faggiana on 25/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import WidgetKit
import Intents
import NextcloudKit

struct FilesDataEntry: TimelineEntry {
    let date: Date
    let datas: [FilesData]
    let isPlaceholder: Bool
    let isEmpty: Bool
    let userId: String
    let url: String
    let account: String
    let tile: String
    let footerImage: String
    let footerText: String
}

struct FilesData: Identifiable, Hashable {
    var id: String
    var image: UIImage
    var title: String
    var subTitle: String
    var url: URL
    var useTypeIconFile: Bool = false
}

let filesDatasTest: [FilesData] = [
    .init(id: "0", image: UIImage(named: "widget")!, title: "title1", subTitle: "subTitle-description1", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "1", image: UIImage(named: "widget")!, title: "title2", subTitle: "subTitle-description2", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "2", image: UIImage(named: "widget")!, title: "title3", subTitle: "subTitle-description3", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "3", image: UIImage(named: "widget")!, title: "title4", subTitle: "subTitle-description4", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "4", image: UIImage(named: "widget")!, title: "title4", subTitle: "subTitle-description4", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "5", image: UIImage(named: "widget")!, title: "title4", subTitle: "subTitle-description4", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "6", image: UIImage(named: "widget")!, title: "title4", subTitle: "subTitle-description4", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "7", image: UIImage(named: "widget")!, title: "title4", subTitle: "subTitle-description4", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "8", image: UIImage(named: "widget")!, title: "title4", subTitle: "subTitle-description4", url: URL(string: "https://nextcloud.com/")!),
    .init(id: "9", image: UIImage(named: "widget")!, title: "title4", subTitle: "subTitle-description4", url: URL(string: "https://nextcloud.com/")!)
]

func getTitleFilesWidget(tableAccount: tableAccount?) -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    var good = ""

    switch hour {
    case 6..<12: good = NSLocalizedString("_good_morning_", value: "Good morning", comment: "")
    case 12: good = NSLocalizedString("_good_day_", value: "Good day", comment: "")
    case 13..<17: good = NSLocalizedString("_good_afternoon_", value: "Good afternoon", comment: "")
    case 17..<22: good = NSLocalizedString("_good_evening_", value: "Good evening", comment: "")
    default: good = NSLocalizedString("_good_night_", value: "Good night", comment: "")
    }

    if let tableAccount {
        return good + ", " + tableAccount.displayName
    } else {
        return good
    }
}

func getFilesItems(displaySize: CGSize) -> Int {
    let items = Int((displaySize.height - 90) / 55)
    return items
}

func getFilesDataEntry(configuration: AccountIntent?, isPreview: Bool, displaySize: CGSize, completion: @escaping (_ entry: FilesDataEntry) -> Void) {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let filesItems = getFilesItems(displaySize: displaySize)
    let datasPlaceholder = Array(filesDatasTest[0...filesItems - 1])
    var activeTableAccount: tableAccount?

    if isPreview {
        return completion(FilesDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, isEmpty: false, userId: "", url: "", account: "", tile: getTitleFilesWidget(tableAccount: nil), footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " files"))
    }

    let accountIdentifier: String = configuration?.accounts?.identifier ?? "active"
    if accountIdentifier == "active" {
        activeTableAccount = NCManageDatabase.shared.getActiveTableAccount()
    } else {
        activeTableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", accountIdentifier))
    }

    guard let activeTableAccount else {
        return completion(FilesDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, isEmpty: false, userId: "", url: "", account: "", tile: getTitleFilesWidget(tableAccount: nil), footerImage: "xmark.icloud", footerText: NSLocalizedString("_no_active_account_", value: "No account found", comment: "")))
    }

    // NETWORKING
    let password = NCKeychain().getPassword(account: activeTableAccount.account)

    NextcloudKit.shared.setup(delegate: NCNetworking.shared)
    NextcloudKit.shared.appendSession(account: activeTableAccount.account,
                                      urlBase: activeTableAccount.urlBase,
                                      user: activeTableAccount.user,
                                      userId: activeTableAccount.userId,
                                      password: password,
                                      userAgent: userAgent,
                                      nextcloudVersion: NCCapabilities.shared.getCapabilities(account: activeTableAccount.account).capabilityServerVersionMajor,
                                      httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                      httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                      httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                      groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

    let requestBodyRecent =
    """
    <?xml version=\"1.0\"?>
    <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
    <d:basicsearch>
        <d:select>
            <d:prop>
                <d:displayname/>
                <d:getcontenttype/>
                <d:resourcetype/>
                <d:getcontentlength/>
                <d:getlastmodified/>
                <d:getetag/>
                <id xmlns=\"http://owncloud.org/ns\"/>
                <fileid xmlns=\"http://owncloud.org/ns\"/>
                <size xmlns=\"http://owncloud.org/ns\"/>
                <creation_time xmlns=\"http://nextcloud.org/ns\"/>
                <upload_time xmlns=\"http://nextcloud.org/ns\"/>
                <is-encrypted xmlns=\"http://nextcloud.org/ns\"/>
                <has-preview xmlns=\"http://nextcloud.org/ns\"/>
            </d:prop>
        </d:select>
    <d:from>
        <d:scope>
            <d:href>%@</d:href>
            <d:depth>infinity</d:depth>
        </d:scope>
    </d:from>
    <d:where>
        <d:lt>
            <d:prop>
                <d:getlastmodified/>
            </d:prop>
            <d:literal>%@</d:literal>
        </d:lt>
    </d:where>
    <d:orderby>
        <d:order>
            <d:prop>
                <d:getlastmodified/>
            </d:prop>
            <d:descending/>
        </d:order>
    </d:orderby>
    <d:limit>
        <d:nresults>50</d:nresults>
    </d:limit>
    </d:basicsearch>
    </d:searchrequest>
    """

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    let lessDateString = dateFormatter.string(from: Date())
    let requestBody = String(format: requestBodyRecent, "/files/" + activeTableAccount.userId, lessDateString)

    // LOG
    let levelLog = NCKeychain().logLevel
    let isSimulatorOrTestFlight = utility.isSimulatorOrTestFlight()
    let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, utility.getVersionApp())

    NextcloudKit.shared.nkCommonInstance.levelLog = levelLog
    NextcloudKit.shared.nkCommonInstance.pathLog = utilityFileSystem.directoryGroup

    if isSimulatorOrTestFlight {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start \(NCBrandOptions.shared.brand) widget session with level \(levelLog) " + versionNextcloudiOS + " (Simulator / TestFlight)")
    } else {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start \(NCBrandOptions.shared.brand) widget session with level \(levelLog) " + versionNextcloudiOS)
    }

    let options = NKRequestOptions(timeout: 30, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
    NextcloudKit.shared.searchBodyRequest(serverUrl: activeTableAccount.urlBase, requestBody: requestBody, showHiddenFiles: NCKeychain().showHiddenFiles, account: activeTableAccount.account, options: options) { _, files, data, error in
        Task {
            var datas: [FilesData] = []
            let title = getTitleFilesWidget(tableAccount: activeTableAccount)
            let files = files?.sorted(by: { ($0.date as Date) > ($1.date as Date) }) ?? []

            for file in files {
                var useTypeIconFile = false
                var image: UIImage?

                if file.directory || (!file.livePhotoFile.isEmpty && file.classFile == NKCommon.TypeClassFile.video.rawValue) {
                    continue
                }

                // SUBTITLE
                let subTitle = utility.dateDiff(file.date as Date) + " · " + utilityFileSystem.transformedSize(file.size)

                // URL: nextcloud://open-file?path=Talk/IMG_0000123.jpg&user=marinofaggiana&link=https://cloud.nextcloud.com/f/123
                guard var path = utilityFileSystem.getPath(path: file.path, user: file.user, fileName: file.fileName).urlEncoded else { continue }
                if path.first == "/" { path = String(path.dropFirst())}
                guard let user = file.user.urlEncoded else { continue }
                let link = file.urlBase + "/f/" + file.fileId
                let urlString = "nextcloud://open-file?path=\(path)&user=\(user)&link=\(link)"
                guard let url = URL(string: urlString) else { continue }

                // IMAGE
                image = utility.getImage(ocId: file.ocId, etag: file.etag, ext: NCGlobal.shared.previewExt512)
                if image == nil, file.hasPreview {
                    let result = await NCNetworking.shared.downloadPreview(fileId: file.fileId,
                                                                           account: activeTableAccount.account,
                                                                           options: options)
                    if result.error == .success, let data = result.responseData?.data {
                        utility.createImageFileFrom(data: data, ocId: file.ocId, etag: file.etag)
                        image = utility.getImage(ocId: file.ocId, etag: file.etag, ext: NCGlobal.shared.previewExt256)
                    }
                }
                if image == nil {
                    image = utility.loadImage(named: file.iconName, useTypeIconFile: true, account: file.account)
                    useTypeIconFile = true
                }

                let isDirectoryE2EE = utilityFileSystem.isDirectoryE2EE(file: file)
                let metadata = NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)

                // DATA
                let data = FilesData(id: metadata.ocId, image: image ?? UIImage(), title: metadata.fileNameView, subTitle: subTitle, url: url, useTypeIconFile: useTypeIconFile)
                datas.append(data)
                if datas.count == filesItems { break}
            }

            let alias = (activeTableAccount.alias.isEmpty) ? "" : (" (" + activeTableAccount.alias + ")")
            let footerText = "Files " + NSLocalizedString("_of_", comment: "") + " " + activeTableAccount.displayName + alias

            if error != .success {
                completion(FilesDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, isEmpty: false, userId: activeTableAccount.userId, url: activeTableAccount.urlBase, account: activeTableAccount.account, tile: title, footerImage: "xmark.icloud", footerText: error.errorDescription))
            } else {
                completion(FilesDataEntry(date: Date(), datas: datas, isPlaceholder: false, isEmpty: datas.isEmpty, userId: activeTableAccount.userId, url: activeTableAccount.urlBase, account: activeTableAccount.account, tile: title, footerImage: "checkmark.icloud", footerText: footerText))
            }
        }
    }
}
