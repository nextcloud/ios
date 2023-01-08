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

    @objc func makeShipDetailsUI(assets: [PHAsset], serverUrl: String, userBaseUrl: NCUserBaseUrl) -> UIViewController {

        let uploadAssets = NCUploadAssets(assets: assets, serverUrl: serverUrl, userBaseUrl: userBaseUrl )
        let details = UploadAssetsView(uploadAssets: uploadAssets)
        return UIHostingController(rootView: details)
    }
}

// MARK: - Class

class NCUploadAssets: ObservableObject, NCCreateFormUploadConflictDelegate {

    @Published var serverUrl: String
    @Published var assets: [PHAsset]
    @Published var userBaseUrl: NCUserBaseUrl
    @Published var dismiss = false

    var metadatasNOConflict: [tableMetadata] = []
    var metadatasUploadInConflict: [tableMetadata] = []

    init(assets: [PHAsset], serverUrl: String, userBaseUrl: NCUserBaseUrl) {

        self.assets = assets
        self.serverUrl = serverUrl
        self.userBaseUrl = userBaseUrl
    }

    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {

        if let metadatas = metadatas {
            NCNetworkingProcessUpload.shared.createProcessUploads(metadatas: metadatas, completion: { _ in
                self.dismiss = true
            })
        } else {
            self.dismiss = true
        }
    }
}

// MARK: - View

struct UploadAssetsView: View {

    @State private var fileName: String = CCUtility.getFileNameMask(NCGlobal.shared.keyFileNameMask)
    @State private var preview: String = ""
    @State private var isMaintainOriginalFilename: Bool = CCUtility.getOriginalFileName(NCGlobal.shared.keyFileNameOriginal)
    @State private var isAddFilenametype: Bool = CCUtility.getFileNameType(NCGlobal.shared.keyFileNameType)
    @State private var isPresentedSelect = false
    @State private var isPresentedUploadConflict = false

    @ObservedObject var uploadAssets: NCUploadAssets

    @Environment(\.presentationMode) var presentationMode

    init(uploadAssets: NCUploadAssets) {
        self.uploadAssets = uploadAssets
    }

    func getOriginalFilename() -> String {

        if let asset = uploadAssets.assets.first, let name = (asset.value(forKey: "filename") as? String) {
            return name
        } else {
            return ""
        }
    }

    func setFileNameMask(fileName: String?) -> String {

        guard let asset = uploadAssets.assets.first else { return "" }
        var preview: String = ""
        let creationDate = asset.creationDate ?? Date()

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

    func save(completion: @escaping (_ metadatasNOConflict: [tableMetadata], _ metadatasUploadInConflict: [tableMetadata]) -> Void) {

        var metadatasNOConflict: [tableMetadata] = []
        var metadatasUploadInConflict: [tableMetadata] = []

        for asset in uploadAssets.assets {

            let serverUrl = uploadAssets.serverUrl
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
            let isRecordInSessions = NCManageDatabase.shared.getAdvancedMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@ AND session != ''", uploadAssets.userBaseUrl.account, serverUrl, fileName), sorted: "fileName", ascending: false)
            if !isRecordInSessions.isEmpty { continue }

            let metadata = NCManageDatabase.shared.createMetadata(account: uploadAssets.userBaseUrl.account, user: uploadAssets.userBaseUrl.user, userId: uploadAssets.userBaseUrl.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: serverUrl, urlBase: uploadAssets.userBaseUrl.urlBase, url: "", contentType: "", isLivePhoto: livePhoto)

            metadata.assetLocalIdentifier = asset.localIdentifier
            metadata.session = NCNetworking.shared.sessionIdentifierBackground
            metadata.sessionSelector = NCGlobal.shared.selectorUploadFile
            metadata.status = NCGlobal.shared.metadataStatusWaitUpload

            if let result = NCManageDatabase.shared.getMetadataConflict(account: uploadAssets.userBaseUrl.account, serverUrl: serverUrl, fileNameView: fileName) {
                metadata.fileName = result.fileName
                metadatasUploadInConflict.append(metadata)
            } else {
                metadatasNOConflict.append(metadata)
            }
        }

        // Verify if file(s) exists
        if !metadatasUploadInConflict.isEmpty {
            completion(metadatasNOConflict, metadatasUploadInConflict)
        } else {
            NCNetworkingProcessUpload.shared.createProcessUploads(metadatas: metadatasNOConflict, completion: { _ in })
            completion(metadatasNOConflict, metadatasUploadInConflict)
        }
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

                    Toggle(NSLocalizedString("_maintain_original_filename_", comment: ""), isOn: $isMaintainOriginalFilename)
                        .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))
                        .onChange(of: isMaintainOriginalFilename) { newValue in
                            CCUtility.setOriginalFileName(newValue, key: NCGlobal.shared.keyFileNameOriginal)
                            if newValue {
                                preview = ""
                            } else {
                                preview = setFileNameMask(fileName: fileName)
                            }
                        }

                    Toggle(NSLocalizedString("_add_filenametype_", comment: ""), isOn: $isAddFilenametype)
                        .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))
                        .onChange(of: isAddFilenametype) { newValue in
                            CCUtility.setFileNameType(newValue, key: NCGlobal.shared.keyFileNameType)
                            preview = setFileNameMask(fileName: fileName)
                        }
                }

                Section(header: Text(NSLocalizedString("_filename_", comment: ""))) {

                    HStack {
                        Text(NSLocalizedString("_filename_", comment: ""))
                        if isMaintainOriginalFilename {
                            Text(getOriginalFilename())
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            TextField(NSLocalizedString("_enter_filename_", comment: ""), text: $fileName)
                                .modifier(TextFieldClearButton(text: $fileName))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if !isMaintainOriginalFilename {
                        Text(preview)
                    }
                }
                .complexModifier { view in
                    if #available(iOS 15, *) {
                        view.listRowSeparator(.hidden)
                    }
                }

                Button(NSLocalizedString("_save_", comment: "")) {
                    save { metadatasNOConflict, metadatasUploadInConflict in
                        if metadatasUploadInConflict.isEmpty {
                            uploadAssets.dismiss = true
                        } else {
                            uploadAssets.metadatasNOConflict = metadatasNOConflict
                            uploadAssets.metadatasUploadInConflict = metadatasUploadInConflict
                            isPresentedUploadConflict = true
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(ButtonRounded(disabled: false))
                .listRowBackground(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle(NSLocalizedString("_upload_photos_videos_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isPresentedSelect) {
            SelectView(serverUrl: $uploadAssets.serverUrl)
        }
        .sheet(isPresented: $isPresentedUploadConflict) {
            UploadConflictView(delegate: uploadAssets, serverUrl: uploadAssets.serverUrl, metadatasUploadInConflict: uploadAssets.metadatasUploadInConflict, metadatasNOConflict: uploadAssets.metadatasNOConflict)
        }
        .onReceive(uploadAssets.$dismiss) { newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - Preview

struct UploadAssetsView_Previews: PreviewProvider {
    static var previews: some View {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            let uploadAssets = NCUploadAssets(assets: [], serverUrl: "/", userBaseUrl: appDelegate)
            UploadAssetsView(uploadAssets: uploadAssets)
        }
    }
}
