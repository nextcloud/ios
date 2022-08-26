//
//  NextcloudData.swift
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
import NCCommunication

struct RecentData: Identifiable, Codable, Hashable {
    var id: String
    var image: String
    var title: String
    var subTitle: String
    var url: URL
}

struct NextcloudDataEntry: TimelineEntry {
    let date: Date
    let recentDatas: [RecentData]
    let isPlaceholder: Bool
    let footerText: String
}

let recentDatasTest: [RecentData] = [
    .init(id: "1",
          image: "/Users/marinofaggiana/Library/Developer/CoreSimulator/Devices/BDE5102B-F3D3-4951-804B-A9E7F6253D56/data/Containers/Shared/AppGroup/D425298A-F6F7-482A-BD07-7ECD42B2836B/File Provider Storage/00395828ocvhmkstoevb/63074889b016c.small.ico",
          title: "title 1",
          subTitle: "subTitle - description 1",
          url: URL(string: "https://nextcloud.com/")!),
    .init(id: "2",
          image: "/Users/marinofaggiana/Library/Developer/CoreSimulator/Devices/BDE5102B-F3D3-4951-804B-A9E7F6253D56/data/Containers/Shared/AppGroup/D425298A-F6F7-482A-BD07-7ECD42B2836B/File Provider Storage/00392008ocvhmkstoevb/a339c916eea984af8ada3815e1f0e9c6.small.ico",
          title: "title 2",
          subTitle: "subTitle - description 2",
          url: URL(string: "https://nextcloud.com/")!),
    .init(id: "3",
          image: "/Users/marinofaggiana/Library/Developer/CoreSimulator/Devices/BDE5102B-F3D3-4951-804B-A9E7F6253D56/data/Containers/Shared/AppGroup/D425298A-F6F7-482A-BD07-7ECD42B2836B/File Provider Storage/00391801ocvhmkstoevb/62f4c03fd46bd.small.ico",
          title: "title 3",
          subTitle: "subTitle - description 3",
          url: URL(string: "https://nextcloud.com/")!),
    .init(id: "4",
          image: "/Users/marinofaggiana/Library/Developer/CoreSimulator/Devices/BDE5102B-F3D3-4951-804B-A9E7F6253D56/data/Containers/Shared/AppGroup/D425298A-F6F7-482A-BD07-7ECD42B2836B/File Provider Storage/00392070ocvhmkstoevb/00340fefc50d1fee8491de0c5dc1864b.small.ico",
          title: "title 4",
          subTitle: "subTitle - description 4",
          url: URL(string: "https://nextcloud.com/")!),
    .init(id: "5",
          image: "file",
          title: "title 4",
          subTitle: "subTitle - description 4",
          url: URL(string: "https://nextcloud.com/")!)
]

func getDataEntry(completion: @escaping (_ entry: NextcloudDataEntry) -> Void) { // _ recentDatas: [RecentData], _ isPlaceholder: Bool, _ footerText: String) -> Void) {

    guard let account = NCManageDatabase.shared.getActiveAccount() else {
        return completion(NextcloudDataEntry(date: Date(), recentDatas: recentDatasTest, isPlaceholder: true, footerText: NSLocalizedString("_no_active_account_", value: "No account found", comment: "")))
    }

    // NETWORKING
    let password = CCUtility.getPassword(account.account)!
    NCCommunicationCommon.shared.setup(
        account: account.account,
        user: account.user,
        userId: account.userId,
        password: password,
        urlBase: account.urlBase,
        userAgent: CCUtility.getUserAgent(),
        webDav: NCUtilityFileSystem.shared.getWebDAV(account: account.account),
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
        <d:nresults>20</d:nresults>
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

    NCCommunicationCommon.shared.levelLog = levelLog
    if let pathDirectoryGroup = CCUtility.getDirectoryGroup()?.path {
        NCCommunicationCommon.shared.pathLog = pathDirectoryGroup
    }
    if isSimulatorOrTestFlight {
        NCCommunicationCommon.shared.writeLog("Start \(NCBrandOptions.shared.brand) widget session with level \(levelLog) " + versionNextcloudiOS + " (Simulator / TestFlight)")
    } else {
        NCCommunicationCommon.shared.writeLog("Start \(NCBrandOptions.shared.brand) widget session with level \(levelLog) " + versionNextcloudiOS)
    }
    NCCommunicationCommon.shared.writeLog("Start \(NCBrandOptions.shared.brand) widget [Auto upload]")

    NCAutoUpload.shared.initAutoUpload(viewController: nil) { items in
        NCCommunicationCommon.shared.writeLog("Completition \(NCBrandOptions.shared.brand) widget [Auto upload]")
        NCCommunication.shared.searchBodyRequest(serverUrl: account.urlBase, requestBody: requestBody, showHiddenFiles: CCUtility.getShowHiddenFiles()) { _, files, errorCode, errorDescription in
            var recentDatas: [RecentData] = []
            for file in files {
                guard !file.directory else { continue }
                let subTitle = CCUtility.dateDiff(file.date as Date) + " · " + CCUtility.transformedSize(file.size)
                let iconImagePath = CCUtility.getDirectoryProviderStorageIconOcId(file.ocId, etag: file.etag)!
                //if FileManager().fileExists(atPath: iconImagePath) {
                //    (cell as! NCCellProtocol).filePreviewImageView?.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                //}


                // Example: nextcloud://open-file?path=Talk/IMG_0000123.jpg&user=marinofaggiana&link=https://cloud.nextcloud.com/f/123

                let path = NCUtilityFileSystem.shared.getPath(path: file.path, user: file.user, fileName: file.fileName)
                let link = file.urlBase + "/f/" + file.fileId
                let urlString = "nextcloud://open-file?path=" + path + "&user=" + file.user + "&link=" + link
                guard let url = URL(string: urlString) else { continue }
                let recentData = RecentData.init(id: file.ocId, image: iconImagePath, title: file.fileName, subTitle: subTitle, url: url)
                recentDatas.append(recentData)
                if recentDatas.count == 5 { break}
            }
            if errorCode != 0 {
                completion(NextcloudDataEntry(date: Date(), recentDatas: recentDatasTest, isPlaceholder: true, footerText: errorDescription))
            } else if recentDatas.isEmpty {
                completion(NextcloudDataEntry(date: Date(), recentDatas: recentDatasTest, isPlaceholder: true, footerText: "Auto upoload: \(items), \(Date().formatted())"))
            } else {
                completion(NextcloudDataEntry(date: Date(), recentDatas: recentDatas, isPlaceholder: false, footerText: "Auto upoload: \(items), \(Date().formatted())"))
            }
        }
    }
}
