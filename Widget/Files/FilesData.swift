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

import WidgetKit
import Intents
import NextcloudKit

struct FilesDataEntry: TimelineEntry {
    let date: Date
    let datas: [FilesData]
    let isPlaceholder: Bool
    let userId: String
    let url: String
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

func getTitleFilesWidget(account: tableAccount?) -> String {

    let hour = Calendar.current.component(.hour, from: Date())
    var good = ""

    switch hour {
    case 6..<12: good = NSLocalizedString("_good_morning_", value: "Good morning", comment: "")
    case 12: good = NSLocalizedString("_good_day_", value: "Good day", comment: "")
    case 13..<17: good = NSLocalizedString("_good_afternoon_", value: "Good afternoon", comment: "")
    case 17..<22: good = NSLocalizedString("_good_evening_", value: "Good evening", comment: "")
    default: good = NSLocalizedString("_good_night_", value: "Good night", comment: "")
    }

    if let account = account {
        return good + ", " + account.displayName
    } else {
        return good
    }
}

func getFilesItems(displaySize: CGSize) -> Int {
    
    let height = Int((displaySize.height - 100) / 50)
    return height
}

func getFilesDataEntry(configuration: AccountIntent?, isPreview: Bool, displaySize: CGSize, completion: @escaping (_ entry: FilesDataEntry) -> Void) {

    let filesItems = getFilesItems(displaySize: displaySize)
    let datasPlaceholder = Array(filesDatasTest[0...filesItems - 1])
    var account: tableAccount?

    if isPreview {
        return completion(FilesDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, userId: "", url: "", tile: getTitleFilesWidget(account: nil), footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " files"))
    }

    let accountIdentifier: String = configuration?.accounts?.identifier ?? "active"
    if accountIdentifier == "active" {
        account = NCManageDatabase.shared.getActiveAccount()
    } else {
        account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", accountIdentifier))
    }

    guard let account = account else {
        return completion(FilesDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, userId: "", url: "", tile: getTitleFilesWidget(account: nil), footerImage: "xmark.icloud", footerText: NSLocalizedString("_no_active_account_", value: "No account found", comment: "")))
    }

    @Sendable func isLive(file: NKFile, files: [NKFile]) -> Bool {

        if file.ext.lowercased() != "mov" { return false }
        if files.filter({ ($0.fileNameWithoutExt == file.fileNameWithoutExt) && ($0.ext.lowercased() == "jpg") }).first != nil {
            return true
        }
        return false
    }

    // NETWORKING
    let password = CCUtility.getPassword(account.account)!
    NKCommon.shared.setup(
        account: account.account,
        user: account.user,
        userId: account.userId,
        password: password,
        urlBase: account.urlBase,
        userAgent: CCUtility.getUserAgent(),
        nextcloudVersion: 0,
        delegate: NCNetworking.shared)

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
                <d:quota-used-bytes/>
                <d:quota-available-bytes/>
                <permissions xmlns=\"http://owncloud.org/ns\"/>
                <id xmlns=\"http://owncloud.org/ns\"/>
                <fileid xmlns=\"http://owncloud.org/ns\"/>
                <size xmlns=\"http://owncloud.org/ns\"/>
                <favorite xmlns=\"http://owncloud.org/ns\"/>
                <creation_time xmlns=\"http://nextcloud.org/ns\"/>
                <upload_time xmlns=\"http://nextcloud.org/ns\"/>
                <is-encrypted xmlns=\"http://nextcloud.org/ns\"/>
                <mount-type xmlns=\"http://nextcloud.org/ns\"/>
                <owner-id xmlns=\"http://owncloud.org/ns\"/>
                <owner-display-name xmlns=\"http://owncloud.org/ns\"/>
                <comments-unread xmlns=\"http://owncloud.org/ns\"/>
                <has-preview xmlns=\"http://nextcloud.org/ns\"/>
                <trashbin-filename xmlns=\"http://nextcloud.org/ns\"/>
                <trashbin-original-location xmlns=\"http://nextcloud.org/ns\"/>
                <trashbin-deletion-time xmlns=\"http://nextcloud.org/ns\"/>
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
    let requestBody = String(format: requestBodyRecent, "/files/" + account.userId, lessDateString)

    // LOG
    let levelLog = CCUtility.getLogLevel()
    let isSimulatorOrTestFlight = NCUtility.shared.isSimulatorOrTestFlight()
    let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, NCUtility.shared.getVersionApp())

    NKCommon.shared.levelLog = levelLog
    if let pathDirectoryGroup = CCUtility.getDirectoryGroup()?.path {
        NKCommon.shared.pathLog = pathDirectoryGroup
    }
    if isSimulatorOrTestFlight {
        NKCommon.shared.writeLog("[INFO] Start \(NCBrandOptions.shared.brand) widget session with level \(levelLog) " + versionNextcloudiOS + " (Simulator / TestFlight)")
    } else {
        NKCommon.shared.writeLog("[INFO] Start \(NCBrandOptions.shared.brand) widget session with level \(levelLog) " + versionNextcloudiOS)
    }
    
    let options = NKRequestOptions(timeout: 15)
    NextcloudKit.shared.searchBodyRequest(serverUrl: account.urlBase, requestBody: requestBody, showHiddenFiles: CCUtility.getShowHiddenFiles(), options: options) { _, files, data, error in
        Task {
            var datas: [FilesData] = []
            var imageRecent = UIImage(named: "file")!
            let title = getTitleFilesWidget(account: account)

            for file in files {
                guard !file.directory else { continue }
                guard !isLive(file: file, files: files) else { continue }
                let isEncrypted = CCUtility.isFolderEncrypted(file.serverUrl, e2eEncrypted: file.e2eEncrypted, account: account.account, urlBase: file.urlBase)
                let metadata = NCManageDatabase.shared.convertNCFileToMetadata(file, isEncrypted: isEncrypted, account: account.account)

                // SUBTITLE
                let subTitle = CCUtility.dateDiff(metadata.date as Date) + " · " + CCUtility.transformedSize(metadata.size)

                // URL: nextcloud://open-file?path=Talk/IMG_0000123.jpg&user=marinofaggiana&link=https://cloud.nextcloud.com/f/123
                guard var path = NCUtilityFileSystem.shared.getPath(path: metadata.path, user: metadata.user, fileName: metadata.fileName).urlEncoded else { continue }
                if path.first == "/" { path = String(path.dropFirst())}
                guard let user = metadata.user.urlEncoded else { continue }
                let link = metadata.urlBase + "/f/" + metadata.fileId
                let urlString = "nextcloud://open-file?path=\(path)&user=\(user)&link=\(link)"
                guard let url = URL(string: urlString) else { continue }

                // IMAGE
                if !metadata.iconName.isEmpty {
                    imageRecent = UIImage(named: metadata.iconName)!
                }
                if let image = NCUtility.shared.createFilePreviewImage(ocId: metadata.ocId, etag: metadata.etag, fileNameView: metadata.fileName, classFile: metadata.classFile, status: 0, createPreviewMedia: false) {
                    imageRecent = image
                } else if metadata.hasPreview {
                    let fileNamePathOrFileId = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, account: account.account)!
                    let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
                    let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)!
                    let (_, _, imageIcon, _, _, _) = await NextcloudKit.shared.downloadPreview(fileNamePathOrFileId: fileNamePathOrFileId, fileNamePreviewLocalPath: fileNamePreviewLocalPath, widthPreview: NCGlobal.shared.sizePreview, heightPreview: NCGlobal.shared.sizePreview, fileNameIconLocalPath: fileNameIconLocalPath, sizeIcon: NCGlobal.shared.sizeIcon)
                    if let image = imageIcon {
                        imageRecent = image
                    }
                }

                // DATA
                let data = FilesData.init(id: metadata.ocId, image: imageRecent, title: metadata.fileNameView, subTitle: subTitle, url: url)
                datas.append(data)
                if datas.count == filesItems { break}
            }

            let alias = (account.alias.isEmpty) ? "" : (" (" + account.alias + ")")
            let footerText = "Files " + NSLocalizedString("_of_", comment: "") +  " " + account.displayName + alias

            if error != .success {
                completion(FilesDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, userId: account.userId, url: account.urlBase, tile: title, footerImage: "xmark.icloud", footerText: error.errorDescription))
            } else if datas.isEmpty {
                var footerText = NSLocalizedString("_no_data_available_", comment: "")
                let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: account.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
                if serverVersionMajor < NCGlobal.shared.nextcloudVersion25 {
                    footerText = NSLocalizedString("_widget_available_nc25_", comment: "")
                }
                completion(FilesDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, userId: account.userId, url: account.urlBase, tile: title, footerImage: "checkmark.icloud", footerText: footerText))
            } else {
                completion(FilesDataEntry(date: Date(), datas: datas, isPlaceholder: false, userId: account.userId, url: account.urlBase, tile: title, footerImage: "checkmark.icloud", footerText: footerText))
            }
        }
    }
}
