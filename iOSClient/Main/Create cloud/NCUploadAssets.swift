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
import QuickLook

@available(iOS 15, *)
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
    var asset: TLPHAsset
    var assetType: TLPHAsset.AssetType
    var data: Data?
    var fileName: String
    var image: UIImage
}

class NCUploadAssets: NSObject, ObservableObject, NCCreateFormUploadConflictDelegate {

    @Published var serverUrl: String
    @Published var assets: [TLPHAsset]
    @Published var userBaseUrl: NCUserBaseUrl
    @Published var dismiss = false
    @Published var isUseAutoUploadFolder: Bool = false
    @Published var isUseAutoUploadSubFolder: Bool = false
    @Published var previewStore: [PreviewStore] = []
    @Published var showHUD: Bool = false
    @Published var uploadInProgress: Bool = false

    var metadatasNOConflict: [tableMetadata] = []
    var metadatasUploadInConflict: [tableMetadata] = []
    var timer: Timer?

    init(assets: [TLPHAsset], serverUrl: String, userBaseUrl: NCUserBaseUrl) {

        self.assets = assets
        self.serverUrl = serverUrl
        self.userBaseUrl = userBaseUrl
    }

    func loadImages() {
        var previewStore: [PreviewStore] = []
        DispatchQueue.global().async {
            for asset in self.assets {
                guard let image = asset.fullResolutionImage?.resizeImage(size: CGSize(width: 300, height: 300), isAspectRation: true), let localIdentifier = asset.phAsset?.localIdentifier else { continue }
                previewStore.append(PreviewStore(id: localIdentifier, asset: asset, assetType: asset.type, fileName: "", image: image))
            }
            DispatchQueue.main.async {
                self.previewStore = previewStore
            }
        }
    }

    func startTimer(navigationItem: UINavigationItem) {
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { _ in
            guard let buttonDone = navigationItem.leftBarButtonItems?.first, let buttonCrop = navigationItem.leftBarButtonItems?.last else { return }
            buttonCrop.isEnabled = true
            buttonDone.isEnabled = true
            if let markup = navigationItem.rightBarButtonItems?.first(where: { $0.accessibilityIdentifier == "QLOverlayMarkupButtonAccessibilityIdentifier" }) {
                if let originalButton = markup.value(forKey: "originalButton") as AnyObject? {
                    if let symbolImageName = originalButton.value(forKey: "symbolImageName") as? String {
                        if symbolImageName == "pencil.tip.crop.circle.on" {
                            buttonCrop.isEnabled = false
                            buttonDone.isEnabled = false
                        }
                    }
                }
            }
        })
    }

    func stopTimer() {
        self.timer?.invalidate()
    }

    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        guard let metadatas = metadatas else {
            self.showHUD = false
            self.uploadInProgress.toggle()
            return
        }

        func createProcessUploads() {
            if !self.dismiss {
                NCNetworkingProcessUpload.shared.createProcessUploads(metadatas: metadatas, completion: { _ in
                    self.dismiss = true
                })
            }
        }

        if isUseAutoUploadFolder {
            DispatchQueue.global().async {
                let assets = self.assets.compactMap { $0.phAsset }
                let result = NCNetworking.shared.createFolder(assets: assets, selector: NCGlobal.shared.selectorUploadFile, useSubFolder: self.isUseAutoUploadSubFolder, account: self.userBaseUrl.account, urlBase: self.userBaseUrl.urlBase, userId: self.userBaseUrl.userId, withPush: false)
                DispatchQueue.main.async {
                    self.showHUD = false
                    self.uploadInProgress.toggle()
                    if result {
                        createProcessUploads()
                    } else {
                        let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_error_createsubfolders_upload_")
                        NCContentPresenter.shared.showError(error: error)
                    }
                }
            }
        } else {
            createProcessUploads()
        }
    }
}

// MARK: - View

@available(iOS 15, *)
struct UploadAssetsView: View {

    @State private var fileName: String = CCUtility.getFileNameMask(NCGlobal.shared.keyFileNameMask)
    @State private var isMaintainOriginalFilename: Bool = CCUtility.getOriginalFileName(NCGlobal.shared.keyFileNameOriginal)
    @State private var isAddFilenametype: Bool = CCUtility.getFileNameType(NCGlobal.shared.keyFileNameType)
    @State private var isPresentedSelect = false
    @State private var isPresentedUploadConflict = false
    @State private var isPresentedQuickLook = false
    @State private var isPresentedAlert = false
    @State private var fileNamePath = NSTemporaryDirectory() + "Photo.jpg"
    @State private var renameFileName: String = ""
    @State private var renameIndex: Int = 0
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

    func getTextServerUrl(_ serverUrl: String) -> String {

        if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", uploadAssets.userBaseUrl.account, serverUrl)), let metadata = NCManageDatabase.shared.getMetadataFromOcId(directory.ocId) {
            return (metadata.fileNameView)
        } else {
            return (serverUrl as NSString).lastPathComponent
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
        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: uploadAssets.userBaseUrl.urlBase, userId: uploadAssets.userBaseUrl.userId, account: uploadAssets.userBaseUrl.account)
        var serverUrl = uploadAssets.isUseAutoUploadFolder ? autoUploadPath : uploadAssets.serverUrl
        let autoUploadSubfolderGranularity = NCManageDatabase.shared.getAccountAutoUploadSubfolderGranularity()

        for tlAsset in uploadAssets.assets {
            guard let asset = tlAsset.phAsset,
                  let previewStore = uploadAssets.previewStore.first(where: { $0.id == asset.localIdentifier }),
                  let assetFileName = asset.value(forKey: "filename") as? NSString else { continue }

            var livePhoto: Bool = false
            let creationDate = asset.creationDate ?? Date()
            let ext = assetFileName.pathExtension.lowercased()
            let fileName = previewStore.fileName.isEmpty ?
            CCUtility.createFileName(assetFileName as String,
                                                    fileDate: creationDate,
                                                    fileType: asset.mediaType,
                                                    keyFileName: NCGlobal.shared.keyFileNameMask,
                                                    keyFileNameType: NCGlobal.shared.keyFileNameType,
                                                    keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginal,
                                                    forcedNewFileName: false)!
            : (previewStore.fileName + "." + ext)

            if previewStore.assetType == .livePhoto && CCUtility.getLivePhoto() && previewStore.data == nil {
                livePhoto = true
            }

            // Auto upload with subfolder
            if uploadAssets.isUseAutoUploadSubFolder {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy"
                let yearString = dateFormatter.string(from: creationDate)
                dateFormatter.dateFormat = "MM"
                let monthString = dateFormatter.string(from: creationDate)
                dateFormatter.dateFormat = "dd"
                let dayString = dateFormatter.string(from: creationDate)
                if autoUploadSubfolderGranularity == 0 {
                    serverUrl = autoUploadPath + "/" + yearString
                } else if autoUploadSubfolderGranularity == 2 {
                    serverUrl = autoUploadPath + "/" + yearString + "/" + monthString + "/" + dayString
                } else {  // Month Granularity is default
                    serverUrl = autoUploadPath + "/" + yearString + "/" + monthString
                }
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
            if let previewStore = uploadAssets.previewStore.first(where: { $0.id == asset.localIdentifier }), let data = previewStore.data {
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

        completion(metadatasNOConflict, metadatasUploadInConflict)
    }

    func presentedQuickLook(index: Int) {

        var image: UIImage?

        if let imageData = uploadAssets.previewStore[index].data {
            image = UIImage(data: imageData)
        } else if let imageFullResolution = uploadAssets.previewStore[index].asset.fullResolutionImage?.fixedOrientation() {
            image = imageFullResolution
        }

        if let image = image {
            if let data = image.jpegData(compressionQuality: 1) {
                do {
                    try data.write(to: URL(fileURLWithPath: fileNamePath))
                    self.index = index
                    isPresentedQuickLook = true
                } catch {
                }
            }
        }
    }

    func deleteAsset(index: Int) {

        uploadAssets.assets.remove(at: index)
        uploadAssets.previewStore.remove(at: index)
        if uploadAssets.previewStore.isEmpty {
            uploadAssets.dismiss = true
        }
    }

    var body: some View {

        NavigationView {
            ZStack(alignment: .top) {
                List {
                    Section(footer: Text(NSLocalizedString("_modify_image_desc_", comment: ""))) {
                        ScrollView(.horizontal) {
                            LazyHGrid(rows: gridItems, alignment: .center, spacing: 10) {
                                ForEach(0..<uploadAssets.previewStore.count, id: \.self) { index in
                                    let item = uploadAssets.previewStore[index]
                                    Menu {
                                        Button(action: {
                                            renameFileName = uploadAssets.previewStore[index].fileName
                                            renameIndex = index
                                            isPresentedAlert = true
                                        }) {
                                            Label(NSLocalizedString("_rename_", comment: ""), systemImage: "pencil")
                                        }
                                        if item.asset.type == .photo || item.asset.type == .livePhoto {
                                            Button(action: {
                                                presentedQuickLook(index: index)
                                            }) {
                                                Label(NSLocalizedString("_modify_", comment: ""), systemImage: "pencil.tip.crop.circle")
                                            }
                                        }
                                        if item.data != nil {
                                            Button(action: {
                                                if let image = uploadAssets.previewStore[index].asset.fullResolutionImage?.resizeImage(size: CGSize(width: 300, height: 300), isAspectRation: true) {
                                                    uploadAssets.previewStore[index].image = image
                                                    uploadAssets.previewStore[index].data = nil
                                                    uploadAssets.previewStore[index].assetType = uploadAssets.previewStore[index].asset.type
                                                }
                                            }) {
                                                Label(NSLocalizedString("_undo_modify_", comment: ""), systemImage: "arrow.uturn.backward.circle")
                                            }
                                        }
                                        if item.data == nil && item.asset.type == .livePhoto && item.assetType == .livePhoto {
                                            Button(action: {
                                                uploadAssets.previewStore[index].assetType = .photo
                                            }) {
                                                Label(NSLocalizedString("_disable_livephoto_", comment: ""), systemImage: "livephoto.slash")
                                            }
                                        } else if item.data == nil && item.asset.type == .livePhoto && item.assetType == .photo {
                                            Button(action: {
                                                uploadAssets.previewStore[index].assetType = .livePhoto
                                            }) {
                                                Label(NSLocalizedString("_enable_livephoto_", comment: ""), systemImage: "livephoto")
                                            }
                                        }
                                        Button(role: .destructive, action: {
                                            deleteAsset(index: index)
                                        }) {
                                            Label(NSLocalizedString("_remove_", comment: ""), systemImage: "trash")
                                        }
                                    } label: {
                                        ImageAsset(uploadAssets: uploadAssets, index: index)
                                        .alert(NSLocalizedString("_rename_file_", comment: ""), isPresented: $isPresentedAlert) {
                                            TextField(NSLocalizedString("_enter_filename_", comment: ""), text: $renameFileName)
                                                .autocapitalization(.none)
                                                .autocorrectionDisabled()
                                            Button(NSLocalizedString("_rename_", comment: ""), action: {
                                                uploadAssets.previewStore[renameIndex].fileName = renameFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                                            })
                                            Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel, action: {})
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .redacted(reason: uploadAssets.previewStore.isEmpty ? .placeholder : [])

                    Section {
                        Toggle(isOn: $isMaintainOriginalFilename, label: {
                            Text(NSLocalizedString("_maintain_original_filename_", comment: ""))
                                .font(.system(size: 15))
                        })
                        .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))

                        if !isMaintainOriginalFilename {
                            Toggle(isOn: $isAddFilenametype, label: {
                                Text(NSLocalizedString("_add_filenametype_", comment: ""))
                                    .font(.system(size: 15))
                            })
                            .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))
                        }
                    }

                    Section {
                        Toggle(isOn: $uploadAssets.isUseAutoUploadFolder, label: {
                            Text(NSLocalizedString("_use_folder_auto_upload_", comment: ""))
                                .font(.system(size: 15))
                        })
                        .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))

                        if uploadAssets.isUseAutoUploadFolder {
                            Toggle(isOn: $uploadAssets.isUseAutoUploadSubFolder, label: {
                                Text(NSLocalizedString("_autoupload_create_subfolder_", comment: ""))
                                    .font(.system(size: 15))
                            })
                            .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))
                        }

                        if !uploadAssets.isUseAutoUploadFolder {
                            HStack {
                                Label {
                                    if NCUtilityFileSystem.shared.getHomeServer(urlBase: uploadAssets.userBaseUrl.urlBase, userId: uploadAssets.userBaseUrl.userId) == uploadAssets.serverUrl {
                                        Text("/")
                                            .font(.system(size: 15))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    } else {
                                        Text(self.getTextServerUrl(uploadAssets.serverUrl))
                                            .font(.system(size: 15))
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
                    }

                    Section {
                        HStack {
                            Text(NSLocalizedString("_filename_", comment: ""))
                            if isMaintainOriginalFilename {
                                Text(getOriginalFilename())
                                    .font(.system(size: 15))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .foregroundColor(Color.gray)
                            } else {
                                TextField(NSLocalizedString("_enter_filename_", comment: ""), text: $fileName)
                                    .font(.system(size: 15))
                                    .modifier(TextFieldClearButton(text: $fileName))
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        if !isMaintainOriginalFilename {
                            Text(setFileNameMask(fileName: fileName))
                                .font(.system(size: 11))
                                .foregroundColor(Color.gray)
                        }
                    }
                    .complexModifier { view in
                        view.listRowSeparator(.hidden)
                    }

                    Button(NSLocalizedString("_save_", comment: "")) {
                        if uploadAssets.isUseAutoUploadFolder, uploadAssets.isUseAutoUploadSubFolder {
                            uploadAssets.showHUD = true
                        }
                        uploadAssets.uploadInProgress.toggle()
                        save { metadatasNOConflict, metadatasUploadInConflict in
                            if metadatasUploadInConflict.isEmpty {
                                uploadAssets.dismissCreateFormUploadConflict(metadatas: metadatasNOConflict)
                            } else {
                                uploadAssets.metadatasNOConflict = metadatasNOConflict
                                uploadAssets.metadatasUploadInConflict = metadatasUploadInConflict
                                isPresentedUploadConflict = true
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(ButtonRounded(disabled: uploadAssets.uploadInProgress))
                    .listRowBackground(Color(UIColor.systemGroupedBackground))
                    .disabled(uploadAssets.uploadInProgress)
                }
                .navigationTitle(NSLocalizedString("_upload_photos_videos_", comment: ""))
                .navigationBarTitleDisplayMode(.inline)

                HUDView(showHUD: $uploadAssets.showHUD, textLabel: NSLocalizedString("_wait_", comment: ""), image: "doc.badge.arrow.up")
                    .offset(y: uploadAssets.showHUD ? 5 : -200)
                    .animation(.easeOut)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $isPresentedSelect) {
            SelectView(serverUrl: $uploadAssets.serverUrl)
        }
        .sheet(isPresented: $isPresentedUploadConflict) {
            UploadConflictView(delegate: uploadAssets, serverUrl: uploadAssets.serverUrl, metadatasUploadInConflict: uploadAssets.metadatasUploadInConflict, metadatasNOConflict: uploadAssets.metadatasNOConflict)
        }
        .fullScreenCover(isPresented: $isPresentedQuickLook) {
            ViewerQuickLook(url: URL(fileURLWithPath: fileNamePath), index: $index, isPresentedQuickLook: $isPresentedQuickLook, uploadAssets: uploadAssets)
                .ignoresSafeArea()
        }
        .onReceive(uploadAssets.$dismiss) { newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onTapGesture {
            UIApplication.shared.windows.filter { $0.isKeyWindow }.first?.endEditing(true)
        }
        .onDisappear {
            uploadAssets.dismiss = true
        }
    }

    struct ImageAsset: View {

        @ObservedObject var uploadAssets: NCUploadAssets
        @State var index: Int

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                if index < uploadAssets.previewStore.count {
                    let item = uploadAssets.previewStore[index]
                    Image(uiImage: item.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80, alignment: .center)
                        .cornerRadius(10)
                    if item.assetType == .livePhoto && item.data == nil {
                        Image(systemName: "livephoto")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 5)
                    } else if item.assetType == .video {
                        Image(systemName: "video.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 5)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 15, *)
struct UploadAssetsView_Previews: PreviewProvider {
    static var previews: some View {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            let uploadAssets = NCUploadAssets(assets: [], serverUrl: "/", userBaseUrl: appDelegate)
            UploadAssetsView(uploadAssets: uploadAssets)
        }
    }
}
