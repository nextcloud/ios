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

    init(assets: [PHAsset], cryptated: Bool, session: String, userBaseUrl: NCUserBaseUrl, serverUrl: String) {
        self.assets = assets
        self.cryptated = cryptated
        self.session = session
        self.userBaseUrl = userBaseUrl
        self.serverUrl = serverUrl
    }

    func previewFileName(fileName: String?) -> String {

        var returnString: String = ""
        let asset = assets[0]
        let creationDate = asset.creationDate ?? Date()

        if CCUtility.getOriginalFileName(NCGlobal.shared.keyFileNameOriginal), let asset = assets.first, let name = (asset.value(forKey: "filename") as? String) {

            return NSLocalizedString("_filename_", comment: "") + ": \(name)"

        } else if let fileName = fileName {

            let fileName = fileName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            if !fileName.isEmpty {

                CCUtility.setFileNameMask(fileName, key: NCGlobal.shared.keyFileNameMask)

                returnString = CCUtility.createFileName(asset.value(forKey: "filename") as? String,
                                                        fileDate: creationDate, fileType: asset.mediaType,
                                                        keyFileName: NCGlobal.shared.keyFileNameMask,
                                                        keyFileNameType: NCGlobal.shared.keyFileNameType,
                                                        keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginal,
                                                        forcedNewFileName: false)

            } else {

                CCUtility.setFileNameMask("", key: NCGlobal.shared.keyFileNameMask)
                returnString = CCUtility.createFileName(asset.value(forKey: "filename") as? String,
                                                        fileDate: creationDate,
                                                        fileType: asset.mediaType,
                                                        keyFileName: nil,
                                                        keyFileNameType: NCGlobal.shared.keyFileNameType,
                                                        keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginal,
                                                        forcedNewFileName: false)
            }

        } else {

            CCUtility.setFileNameMask("", key: NCGlobal.shared.keyFileNameMask)
            returnString = CCUtility.createFileName(asset.value(forKey: "filename") as? String,
                                                    fileDate: creationDate,
                                                    fileType: asset.mediaType,
                                                    keyFileName: nil,
                                                    keyFileNameType: NCGlobal.shared.keyFileNameType,
                                                    keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginal,
                                                    forcedNewFileName: false)
        }

        return String(format: NSLocalizedString("_preview_filename_", comment: ""), "MM, MMM, DD, YY, YYYY, HH, hh, mm, ss, ampm") + ":" + "\n\n" + returnString
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
    @State var isMaintainOriginalFilename: Bool = false
    @State var isAddFilenametype: Bool = false
    @State var fileNameonChange: Bool = true
    @State var example: String = ""

    @ObservedObject var uploadAssets: NCUploadAssets

    init(_ uploadAssets: NCUploadAssets) {
        self.uploadAssets = uploadAssets
    }

    var body: some View {
        ZStack(alignment: .top) {
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
                        .complexModifier { view in
                            if #available(iOS 16, *) {
                                view.alignmentGuide(.listRowSeparatorLeading) { _ in
                                    return 0
                                }
                            }
                        }
                    }

                    Section(header: Text(NSLocalizedString("_mode_filename_", comment: ""))) {

                        Toggle(NSLocalizedString("_maintain_original_filename_", comment: ""), isOn: $isMaintainOriginalFilename)
                            .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))
                            .onChange(of: isMaintainOriginalFilename) { newValue in
                            }

                        Toggle(NSLocalizedString("_add_filenametype_", comment: ""), isOn: $isAddFilenametype)
                            .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))
                            .onChange(of: isAddFilenametype) { newValue in
                            }
                    }

                    Section(header: Text(NSLocalizedString("_filename_", comment: ""))) {

                        HStack {
                            Text(NSLocalizedString("_filename_", comment: ""))
                            TextField(NSLocalizedString("_enter_filename_", comment: ""), text: $fileName)
                                .modifier(TextFieldClearButton(text: $fileName))
                                .multilineTextAlignment(.trailing)
                        }
                        if !uploadAssets.assets.isEmpty {
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
                    .buttonStyle(ButtonUploadScanDocumenStyle(disabled: fileName.isEmpty))
                    .background(Color(UIColor.systemGroupedBackground))
                }
                .navigationTitle(NSLocalizedString("_upload_photos_videos_", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
            }
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
