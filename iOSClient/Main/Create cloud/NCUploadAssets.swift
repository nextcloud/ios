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
import TLPhotoPicker
import Mantis
import Photos

class NCHostingUploadAssetsView: NSObject {

    func makeShipDetailsUI(assets: [TLPHAsset], serverUrl: String, userBaseUrl: NCUserBaseUrl) -> UIViewController {

        let uploadAssets = NCUploadAssets(assets: assets, serverUrl: serverUrl, userBaseUrl: userBaseUrl )
        let details = UploadAssetsView(uploadAssets: uploadAssets)
        return UIHostingController(rootView: details)
    }
}

// MARK: - Class

struct PreviewStore {
    var id: String
    var image: UIImage
    var asset: TLPHAsset
    var hasChanges: Bool
}

class NCUploadAssets: NSObject, ObservableObject, NCCreateFormUploadConflictDelegate {

    @Published var serverUrl: String
    @Published var assets: [TLPHAsset]
    @Published var userBaseUrl: NCUserBaseUrl
    @Published var dismiss = false
    @Published var previewStore: [PreviewStore] = []

    var metadatasNOConflict: [tableMetadata] = []
    var metadatasUploadInConflict: [tableMetadata] = []
    var timer: Timer?

    /*

     */
    let resizeImagePreview: Double = 300
    let sizeImagePreview: Double = 100
    let compressionQuality: CGFloat = 0.5

    init(assets: [TLPHAsset], serverUrl: String, userBaseUrl: NCUserBaseUrl) {

        self.assets = assets
        self.serverUrl = serverUrl
        self.userBaseUrl = userBaseUrl
    }

    func loadImages() {
        DispatchQueue.global().async {
            for asset in self.assets {
                guard let image = asset.fullResolutionImage?.resizeImage(size: CGSize(width: self.resizeImagePreview, height: self.resizeImagePreview), isAspectRation: true), let localIdentifier = asset.phAsset?.localIdentifier else { continue }
                self.previewStore.append(PreviewStore(id: localIdentifier, image: image, asset: asset, hasChanges: false))
            }
        }
    }

    func startTimer(navigationItem: UINavigationItem) {
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true, block: { _ in
            let numItemsRight = navigationItem.rightBarButtonItems?.count ?? 0
            if let buttonDone = navigationItem.leftBarButtonItems?.first, let buttonCrop = navigationItem.leftBarButtonItems?.last {

                if numItemsRight > 2 && buttonCrop.isEnabled {
                    buttonCrop.isEnabled = false
                    buttonDone.isEnabled = false
                }

                if numItemsRight < 3 && !buttonCrop.isEnabled {
                    buttonCrop.isEnabled = true
                    buttonDone.isEnabled = true
                }
            }
        })
    }

    func stopTimer() {
        self.timer?.invalidate()
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
    @State private var isMaintainOriginalFilename: Bool = CCUtility.getOriginalFileName(NCGlobal.shared.keyFileNameOriginal)
    @State private var isAddFilenametype: Bool = CCUtility.getFileNameType(NCGlobal.shared.keyFileNameType)
    @State private var isPresentedSelect = false
    @State private var isPresentedUploadConflict = false
    @State private var isPresentedQuickLook = false
    @State private var fileNamePath = NSTemporaryDirectory() + "Photo.jpg"
    @State private var metadata: tableMetadata?
    @State private var index: Int = 0

    var gridItems: [GridItem] = [GridItem()]

    @ObservedObject var uploadAssets: NCUploadAssets

    @Environment(\.presentationMode) var presentationMode

    init(uploadAssets: NCUploadAssets) {
        self.uploadAssets = uploadAssets
        uploadAssets.loadImages()
    }

    func getOriginalFilename() -> String {

        CCUtility.setOriginalFileName(isMaintainOriginalFilename, key: NCGlobal.shared.keyFileNameOriginal)

        if let asset = uploadAssets.assets.first?.phAsset, let name = (asset.value(forKey: "filename") as? String) {
            return (name as NSString).deletingPathExtension
        } else {
            return ""
        }
    }

    func setFileNameMask(fileName: String?) -> String {

        guard let asset = uploadAssets.assets.first?.phAsset else { return "" }
        var preview: String = ""
        let creationDate = asset.creationDate ?? Date()

        CCUtility.setOriginalFileName(isMaintainOriginalFilename, key: NCGlobal.shared.keyFileNameOriginal)
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

        return String(format: NSLocalizedString("_preview_filename_", comment: ""), "MM, MMM, DD, YY, YYYY, HH, hh, mm, ss, ampm") + ":" + "\n\n" + (preview as NSString).deletingPathExtension
    }

    func save(completion: @escaping (_ metadatasNOConflict: [tableMetadata], _ metadatasUploadInConflict: [tableMetadata]) -> Void) {

        var metadatasNOConflict: [tableMetadata] = []
        var metadatasUploadInConflict: [tableMetadata] = []

        for asset in uploadAssets.assets {
            guard let asset = asset.phAsset, let previewStore = uploadAssets.previewStore.first(where: { $0.id == asset.localIdentifier }) else { continue }

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

            if asset.mediaSubtypes.contains(.photoLive) && CCUtility.getLivePhoto() && !previewStore.hasChanges {
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

            // Modified
            if let previewStore = uploadAssets.previewStore.first(where: { $0.id == asset.localIdentifier }), previewStore.hasChanges, let data = previewStore.image.jpegData(compressionQuality: 1) {
                if metadata.contentType == "image/heic" {
                    let fileNameNoExtension = (fileName as NSString).deletingPathExtension
                    metadata.contentType = "image/jpeg"
                    metadata.fileName = fileNameNoExtension + ".jpg"
                    metadata.fileNameView = fileNameNoExtension + ".jpg"
                }
                let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                do {
                    try data.write(to: URL(fileURLWithPath: fileNamePath))
                    metadata.isExtractFile = true
                    metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: fileNamePath)
                    metadata.creationDate = asset.creationDate as? NSDate ?? (Date() as NSDate)
                    metadata.date = asset.modificationDate as? NSDate ?? (Date() as NSDate)
                } catch {  }
            }

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

    func presentedQuickLook(size: CGFloat, index: Int) {

        let previewStore = uploadAssets.previewStore[index]
        var image = previewStore.image

        if !previewStore.hasChanges {
            if let fullResolutionImage = previewStore.asset.fullResolutionImage?.resizeImage(size: CGSize(width: size, height: size)) {
                image = fullResolutionImage
            }
        }

        if let data = image.jpegData(compressionQuality: uploadAssets.compressionQuality) {
            do {
                try data.write(to: URL(fileURLWithPath: fileNamePath))
                self.index = index
                isPresentedQuickLook = true
            } catch {
            }
        }
    }

    var body: some View {

        GeometryReader { geo in
            NavigationView {
                List {

                    if !uploadAssets.previewStore.isEmpty {
                        Section(header: Text(NSLocalizedString("_modify_photo_", comment: "")), footer: Text(NSLocalizedString("_modify_photo_desc_", comment: ""))) {
                            ScrollView(.horizontal) {
                                LazyHGrid(rows: gridItems, alignment: .center, spacing: 10) {
                                    ForEach(0..<uploadAssets.previewStore.count, id: \.self) { index in
                                        let item = uploadAssets.previewStore[index]
                                        ZStack(alignment: .bottomTrailing) {
                                            Image(uiImage: item.image)
                                                .resizable()
                                                .frame(width: uploadAssets.sizeImagePreview, height: uploadAssets.sizeImagePreview, alignment: .center)
                                                .cornerRadius(10)
                                                .scaledToFit()
                                            if item.asset.type == .livePhoto && !item.hasChanges {
                                                Image(systemName: "livephoto")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 15, height: 15)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 5)
                                            } else if item.asset.type == .video {
                                                Image(systemName: "video.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 15, height: 15)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 5)
                                            }
                                        }
                                        .onTapGesture {
                                            if item.asset.type == .photo || item.asset.type == .livePhoto {
                                                presentedQuickLook(size: max(geo.size.height, geo.size.height), index: index)
                                            }
                                        }
                                        .fullScreenCover(isPresented: $isPresentedQuickLook) {
                                            ViewerQuickLook(url: URL(fileURLWithPath: fileNamePath), index: $index, isPresentedQuickLook: $isPresentedQuickLook, uploadAssets: uploadAssets)
                                                .ignoresSafeArea()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Section(header: Text(NSLocalizedString("_mode_filename_", comment: ""))) {

                        Toggle(NSLocalizedString("_maintain_original_filename_", comment: ""), isOn: $isMaintainOriginalFilename)
                            .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))

                        if !isMaintainOriginalFilename {
                            Toggle(NSLocalizedString("_add_filenametype_", comment: ""), isOn: $isAddFilenametype)
                                .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))
                        }
                    }

                    Section {

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

                        HStack {
                            Text(NSLocalizedString("_filename_", comment: ""))
                            if isMaintainOriginalFilename {
                                Text(getOriginalFilename())
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .foregroundColor(Color.gray)
                            } else {
                                TextField(NSLocalizedString("_enter_filename_", comment: ""), text: $fileName)
                                    .modifier(TextFieldClearButton(text: $fileName))
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        if !isMaintainOriginalFilename {
                            Text(setFileNameMask(fileName: fileName))
                                .font(.system(size: 12))
                                .foregroundColor(Color.gray)
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
