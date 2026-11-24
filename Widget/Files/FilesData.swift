// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WidgetKit
import Intents
import ImageIO
import NextcloudKit

struct FilesDataEntry: TimelineEntry {
    let date: Date
    let datas: [FilesData]
    let isPlaceholder: Bool
    let isEmpty: Bool
    let allowsRefresh: Bool
    let footerImage: String
    let footerText: String
}

struct FilesData: Identifiable, Hashable {
    var id: String
    var image: UIImage
    var title: String
    var subTitle: String
    var url: URL?
    var useTypeIconFile: Bool = false
}

func filesWidgetSampleRows(count: Int) -> [FilesData] {
    let image = UIImage(systemName: "doc") ?? UIImage()
    return (0..<count).map { index in
        FilesData(id: String(index),
                  image: image,
                  title: "Document \(index + 1).pdf",
                  subTitle: "76 KB",
                  url: nil,
                  useTypeIconFile: true)
    }
}

func getFilesDataEntry(configuration: AccountIntent, displaySize: CGSize) async -> FilesDataEntry {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let maxItems = FilesWidgetLayout.rowCount(for: displaySize.height)
    let datasPlaceholder = filesWidgetSampleRows(count: maxItems)
    var activeTableAccount: tableAccount?
    let versionApp = NCUtility().getVersionMaintenance()

    if let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup),
          let lastVersion = groupDefaults.string(forKey: NCGlobal.shared.udLastVersion),
          lastVersion != versionApp {
        return (FilesDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, isEmpty: false, allowsRefresh: true, footerImage: "checkmark.icloud", footerText: NSLocalizedString("_version_mismatch_error_", comment: "")))
    }

    let accountIdentifier: String = configuration.accounts?.identifier ?? "active"
    if accountIdentifier == "active" {
        activeTableAccount = NCManageDatabase.shared.getActiveTableAccount()
    } else {
        activeTableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", accountIdentifier))
    }

    guard let activeTableAccount else {
        return (FilesDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, isEmpty: false, allowsRefresh: true, footerImage: "xmark.icloud", footerText: NSLocalizedString("_no_active_account_", value: "No account found", comment: "")))
    }

    NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup, delegate: NCNetworking.shared)
    NextcloudKit.shared.appendSession(account: activeTableAccount.account,
                                      urlBase: activeTableAccount.urlBase,
                                      user: activeTableAccount.user,
                                      userId: activeTableAccount.userId,
                                      password: NCPreferences().getPassword(account: activeTableAccount.account),
                                      userAgent: userAgent,
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
    let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: activeTableAccount.account)

    // LOG
    let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, utility.getVersionBuild())
    NextcloudKit.configureLogger(
        logLevel: NCBrandOptions.shared.disable_log ? .disabled : NCPreferences().log,
        logDirectory: NCPreferences.sharedLogDirectory
    )
    defer { NextcloudKit.flushLogger() }

    nkLog(debug: "Start \(NCBrandOptions.shared.brand) widget session " + versionNextcloudiOS)

    let options = NKRequestOptions(timeout: 30)
    let results = await NextcloudKit.shared.searchBodyRequestAsync(serverUrl: activeTableAccount.urlBase, requestBody: requestBody, showHiddenFiles: showHiddenFiles, account: activeTableAccount.account, options: options)

    var datas: [FilesData] = []
    let files = results.files?.sorted(by: { ($0.date as Date) > ($1.date as Date) }) ?? []

    for file in files {
        guard datas.count < maxItems else { break }

        var useTypeIconFile = false
        var image: UIImage?

        if file.directory || (!file.livePhotoFile.isEmpty && file.classFile == NKTypeClassFile.video.rawValue) {
            continue
        }

        // SUBTITLE
        let subTitle = utility.getRelativeDateTitle(file.date as Date) + " · " + utilityFileSystem.transformedSize(file.size)

        var components = URLComponents()
        components.scheme = NCGlobal.shared.appScheme
        components.host = "open-file"
        components.queryItems = [
            URLQueryItem(name: "user", value: file.userId),
            URLQueryItem(name: "link", value: file.urlBase + "/f/" + file.fileId),
            URLQueryItem(name: "account", value: file.account)
        ]
        guard let url = components.url else { continue }

        image = await loadFilesWidgetPreview(for: file, account: activeTableAccount, fileSystem: utilityFileSystem, options: options)
        if image == nil {
            image = utility.loadImage(named: file.iconName, useTypeIconFile: true, account: file.account)
            useTypeIconFile = true
        }

        let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)

        // DATA
        let data = FilesData(id: metadata.ocId, image: image ?? UIImage(), title: metadata.fileNameView, subTitle: subTitle, url: url, useTypeIconFile: useTypeIconFile)
        datas.append(data)
    }

    let alias = (activeTableAccount.alias.isEmpty) ? "" : (" (" + activeTableAccount.alias + ")")
    let footerText = activeTableAccount.displayName + alias

    if results.error != .success {
        return(FilesDataEntry(date: Date(), datas: datasPlaceholder, isPlaceholder: true, isEmpty: false, allowsRefresh: true, footerImage: "xmark.icloud", footerText: results.error.localizedGenericMessage))
    } else {
        return(FilesDataEntry(date: Date(), datas: datas, isPlaceholder: false, isEmpty: datas.isEmpty, allowsRefresh: true, footerImage: "checkmark.icloud", footerText: footerText))
    }
}

private func loadFilesWidgetPreview(for file: NKFile,
                                    account: tableAccount,
                                    fileSystem: NCUtilityFileSystem,
                                    options: NKRequestOptions) async -> UIImage? {
    let thumbnailSize = NCGlobal.shared.size256
    let thumbnailPath = fileSystem.getDirectoryProviderStorageImageOcId(file.ocId,
                                                                        etag: file.etag,
                                                                        ext: NCGlobal.shared.previewExt256,
                                                                        userId: account.userId,
                                                                        urlBase: account.urlBase)
    let thumbnailURL = URL(fileURLWithPath: thumbnailPath)
    if let image = UIImage.thumbnail(imageAt: thumbnailURL, to: thumbnailSize, scale: 1) {
        return image
    }

    let largerPath = fileSystem.getDirectoryProviderStorageImageOcId(file.ocId,
                                                                     etag: file.etag,
                                                                     ext: NCGlobal.shared.previewExt512,
                                                                     userId: account.userId,
                                                                     urlBase: account.urlBase)
    if let image = UIImage.thumbnail(imageAt: URL(fileURLWithPath: largerPath), to: thumbnailSize, scale: 1) {
        return image
    }

    let result = await NextcloudKit.shared.downloadPreviewAsync(fileId: file.fileId,
                                                                width: Int(thumbnailSize.width),
                                                                height: Int(thumbnailSize.height),
                                                                etag: file.etag,
                                                                account: account.account,
                                                                options: options)
    guard result.error == .success,
          let data = result.responseData?.data else { return nil }

    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

    let thumbnailOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: Int(thumbnailSize.width)
    ] as CFDictionary
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
    // The shared preview cache expects all three sizes. Use this thumbnail only for the widget entry.
    return UIImage(cgImage: thumbnail)
}
