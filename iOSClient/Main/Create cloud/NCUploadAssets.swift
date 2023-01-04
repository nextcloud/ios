//
//  NCUploadAssets.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 04/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

class NCHostingUploadAssetsView: NSObject {

    @objc func makeShipDetailsUI(assets: [PHAsset], cryptated: Bool, session: String, userBaseUrl: NCUserBaseUrl, serverUrl: String) -> UIViewController {

        let uploadAssets = NCUploadAssets(assets: assets, cryptated: cryptated, session: session, userBaseUrl: userBaseUrl, serverUrl: serverUrl)
        let details = UploadAssetsView(uploadAssets)
        let vc = UIHostingController(rootView: details)
        return vc
    }
}

class NCUploadAssets: ObservableObject {

    internal var assets: [PHAsset]
    internal var cryptated: Bool
    internal var session: String
    internal var userBaseUrl: NCUserBaseUrl

    @Published var serverUrl: String
    @Published var isMaintainOriginalFilename: Bool = CCUtility.getOriginalFileName(NCGlobal.shared.keyFileNameOriginal)
    @Published var isAddFilenametype: Bool = CCUtility.getFileNameType(NCGlobal.shared.keyFileNameType)

    init(assets: [PHAsset], cryptated: Bool, session: String, userBaseUrl: NCUserBaseUrl, serverUrl: String) {
        self.assets = assets
        self.cryptated = cryptated
        self.session = session
        self.userBaseUrl = userBaseUrl
        self.serverUrl = serverUrl
    }

    func previewFileName(fileName: String?) -> String {

        guard let asset = assets.first else { return "" }
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

    func getOriginalFilename() -> String {

        if let asset = assets.first, let name = (asset.value(forKey: "filename") as? String) {
            return name
        } else {
            return ""
        }
    }

    func save() {

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

struct UploadAssetsView: View {

    @State var fileName: String = CCUtility.getFileNameMask(NCGlobal.shared.keyFileNameMask)
    @State var isPresentedSelect = false
    @State var example: String = ""

    @ObservedObject var uploadAssets: NCUploadAssets

    init(_ uploadAssets: NCUploadAssets) {
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
                        .onChange(of: uploadAssets.isMaintainOriginalFilename) { newValue in
                            CCUtility.setOriginalFileName(newValue, key: NCGlobal.shared.keyFileNameOriginal)
                        }

                    Toggle(NSLocalizedString("_add_filenametype_", comment: ""), isOn: $uploadAssets.isAddFilenametype)
                        .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))
                        .onChange(of: uploadAssets.isAddFilenametype) { newValue in
                            CCUtility.setFileNameType(newValue, key: NCGlobal.shared.keyFileNameType)
                        }
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
                        Text(uploadAssets.previewFileName(fileName: fileName))
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
                .buttonStyle(ButtonUploadScanDocumenStyle(disabled: false))
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
            let uploadAssets = NCUploadAssets(assets: [], cryptated: false, session: "", userBaseUrl: appDelegate, serverUrl: "/")
            UploadAssetsView(uploadAssets)
        }
    }
}
