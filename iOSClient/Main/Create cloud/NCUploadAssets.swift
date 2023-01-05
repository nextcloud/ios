//
//  NCUploadAssets.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 04/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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

import SwiftUI
import NextcloudKit

class NCHostingUploadAssetsView: NSObject {

    @objc func makeShipDetailsUI(assets: [PHAsset], cryptated: Bool, session: String, userBaseUrl: NCUserBaseUrl, serverUrl: String) -> UIViewController {

        let uploadAssets = NCUploadAssets(assets: assets, session: session, userBaseUrl: userBaseUrl, serverUrl: serverUrl)
        let details = UploadAssetsView(uploadAssets: uploadAssets)
        let vc = UIHostingController(rootView: details)
        return vc
    }
}

class NCUploadAssets: ObservableObject {

    internal var assets: [PHAsset]
    internal var session: String
    internal var userBaseUrl: NCUserBaseUrl

    @Published var serverUrl: String
    @Published var isMaintainOriginalFilename: Bool = CCUtility.getOriginalFileName(NCGlobal.shared.keyFileNameOriginal)
    @Published var isAddFilenametype: Bool = CCUtility.getFileNameType(NCGlobal.shared.keyFileNameType)

    init(assets: [PHAsset], session: String, userBaseUrl: NCUserBaseUrl, serverUrl: String) {

        self.assets = assets
        self.session = session
        self.userBaseUrl = userBaseUrl
        self.serverUrl = serverUrl
    }

    func setFileNameMask(fileName: String?) -> String {

        guard let asset = assets.first else { return "" }
        var preview: String = ""
        let creationDate = asset.creationDate ?? Date()

        CCUtility.setFileNameType(isAddFilenametype, key: NCGlobal.shared.keyFileNameType)

        if let fileName = fileName {

            let fileName = fileName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            if !fileName.isEmpty {

                CCUtility.setFileNameMask(fileName, key: NCGlobal.shared.keyFileNameMask)
                preview = CCUtility.createFileName(asset.value(forKey: "filename") as? String,
                                                   fileDate: creationDate, fileType: asset.mediaType,
                                                   keyFileName: NCGlobal.shared.keyFileNameMask,
                                                   keyFileNameType: NCGlobal.shared.keyFileNameType,
                                                   keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginal,
                                                   forcedNewFileName: false)

            } else {

                CCUtility.setFileNameMask("", key: NCGlobal.shared.keyFileNameMask)
                preview = CCUtility.createFileName(asset.value(forKey: "filename") as? String,
                                                   fileDate: creationDate,
                                                   fileType: asset.mediaType,
                                                   keyFileName: nil,
                                                   keyFileNameType: NCGlobal.shared.keyFileNameType,
                                                   keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginal,
                                                   forcedNewFileName: false)
            }

        } else {

            CCUtility.setFileNameMask("", key: NCGlobal.shared.keyFileNameMask)
            preview = CCUtility.createFileName(asset.value(forKey: "filename") as? String,
                                               fileDate: creationDate,
                                               fileType: asset.mediaType,
                                               keyFileName: nil,
                                               keyFileNameType: NCGlobal.shared.keyFileNameType,
                                               keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginal,
                                               forcedNewFileName: false)
        }

        return String(format: NSLocalizedString("_preview_filename_", comment: ""), "MM, MMM, DD, YY, YYYY, HH, hh, mm, ss, ampm") + ":" + "\n\n" + preview
    }

    func getOriginalFilename() -> String {

        if let asset = assets.first, let name = (asset.value(forKey: "filename") as? String) {
            return name
        } else {
            return ""
        }
    }

    func save() {

        // DispatchQueue.global().async {

            var metadatasNOConflict: [tableMetadata] = []
            var metadatasUploadInConflict: [tableMetadata] = []
            let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: userBaseUrl.urlBase, userId: userBaseUrl.userId, account: userBaseUrl.account)

            for asset in self.assets {

                var serverUrl = self.serverUrl
                var livePhoto: Bool = false
                let creationDate = asset.creationDate ?? Date()
                let fileName = CCUtility.createFileName(asset.value(forKey: "filename") as? String,
                                                        fileDate: creationDate,
                                                        fileType: asset.mediaType,
                                                        keyFileName: NCGlobal.shared.keyFileNameMask,
                                                        keyFileNameType: NCGlobal.shared.keyFileNameType,
                                                        keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginal,
                                                        forcedNewFileName: false)!

                if asset.mediaSubtypes.contains(.photoLive) && CCUtility.getLivePhoto() {
                    livePhoto = true
                }

                // Check if is in upload
                let isRecordInSessions = NCManageDatabase.shared.getAdvancedMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@ AND session != ''", userBaseUrl.account, serverUrl, fileName), sorted: "fileName", ascending: false)
                if !isRecordInSessions.isEmpty { continue }

                let metadataForUpload = NCManageDatabase.shared.createMetadata(account: userBaseUrl.account, user: userBaseUrl.user, userId: userBaseUrl.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: serverUrl, urlBase: userBaseUrl.urlBase, url: "", contentType: "", isLivePhoto: livePhoto)

                metadataForUpload.assetLocalIdentifier = asset.localIdentifier
                metadataForUpload.session = self.session
                metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
                metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload

                if let result = NCManageDatabase.shared.getMetadataConflict(account: userBaseUrl.account, serverUrl: serverUrl, fileNameView: fileName) {
                    metadataForUpload.fileName = result.fileName
                    metadatasUploadInConflict.append(metadataForUpload)
                } else {
                    metadatasNOConflict.append(metadataForUpload)
                }
            }

            // Verify if file(s) exists
            if !metadatasUploadInConflict.isEmpty {

                /*
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if let conflict = UIStoryboard(name: "NCCreateFormUploadConflict", bundle: nil).instantiateInitialViewController() as? NCCreateFormUploadConflict {

                        conflict.serverUrl = self.serverUrl
                        conflict.metadatasNOConflict = metadatasNOConflict
                        conflict.metadatasUploadInConflict = metadatasUploadInConflict
                        conflict.delegate = self.appDelegate

                        self.appDelegate.window?.rootViewController?.present(conflict, animated: true, completion: nil)
                    }
                }
                */
            } else {
                NCNetworkingProcessUpload.shared.createProcessUploads(metadatas: metadatasNOConflict, completion: { _ in })
            }

            // DispatchQueue.main.async {self.dismiss(animated: true, completion: nil)  }
        // }
    }
}

// MARK: - Delegate

extension NCUploadAssets: NCSelectDelegate {

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {

        if let serverUrl = serverUrl {
            CCUtility.setDirectoryScanDocument(serverUrl)
            self.serverUrl = serverUrl
        }
    }
}

// MARK: - View

struct UploadAssetsView: View {

    @State var fileName: String = CCUtility.getFileNameMask(NCGlobal.shared.keyFileNameMask)
    @State var isPresentedSelect = false

    @ObservedObject var uploadAssets: NCUploadAssets

    init(uploadAssets: NCUploadAssets) {
        self.uploadAssets = uploadAssets
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text(NSLocalizedString("_save_path_", comment: ""))) {
                    HStack {
                        Label {
                            if NCUtilityFileSystem.shared.getHomeServer(urlBase: uploadAssets.userBaseUrl.urlBase, userId: uploadAssets.userBaseUrl.userId) == uploadAssets.serverUrl {
                                Text("/")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                Text((uploadAssets.serverUrl as NSString).lastPathComponent)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        } icon: {
                            Image("folder")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(Color(NCBrandColor.shared.brand))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPresentedSelect = true
                    }
                }

                Section(header: Text(NSLocalizedString("_mode_filename_", comment: ""))) {

                    Toggle(NSLocalizedString("_maintain_original_filename_", comment: ""), isOn: $uploadAssets.isMaintainOriginalFilename)
                        .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))
                        .onChange(of: uploadAssets.isMaintainOriginalFilename) { _ in }

                    Toggle(NSLocalizedString("_add_filenametype_", comment: ""), isOn: $uploadAssets.isAddFilenametype)
                        .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))
                        .onChange(of: uploadAssets.isAddFilenametype) { _ in }
                }

                Section(header: Text(NSLocalizedString("_filename_", comment: ""))) {

                    HStack {
                        Text(NSLocalizedString("_filename_", comment: ""))
                        if uploadAssets.isMaintainOriginalFilename {
                            Text(uploadAssets.getOriginalFilename())
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            TextField(NSLocalizedString("_enter_filename_", comment: ""), text: $fileName)
                                .modifier(TextFieldClearButton(text: $fileName))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if !uploadAssets.isMaintainOriginalFilename {
                        Text(uploadAssets.setFileNameMask(fileName: fileName))
                    }
                }
                .complexModifier { view in
                    if #available(iOS 15, *) {
                        view.listRowSeparator(.hidden)
                    }
                }

                Button(NSLocalizedString("_save_", comment: "")) {
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(ButtonRounded(disabled: false))
                .listRowBackground(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle(NSLocalizedString("_upload_photos_videos_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isPresentedSelect) {
            NCSelectViewControllerRepresentable(delegate: uploadAssets)
        }
    }
}

// MARK: - Preview

struct UploadAssetsView_Previews: PreviewProvider {
    static var previews: some View {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            let uploadAssets = NCUploadAssets(assets: [], session: "", userBaseUrl: appDelegate, serverUrl: "/")
            UploadAssetsView(uploadAssets: uploadAssets)
        }
    }
}
