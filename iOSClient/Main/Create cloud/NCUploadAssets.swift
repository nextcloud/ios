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
        vc.title = NSLocalizedString("_upload_photos_videos_", comment: "")
        return vc
    }
}

class NCUploadAssets: ObservableObject {

    internal var assets: [PHAsset]
    internal var cryptated: Bool
    internal var session: String
    internal var userBaseUrl: NCUserBaseUrl
    internal var serverUrl: String

    init(assets: [PHAsset], cryptated: Bool, session: String, userBaseUrl: NCUserBaseUrl, serverUrl: String) {
        self.assets = assets
        self.cryptated = cryptated
        self.session = session
        self.userBaseUrl = userBaseUrl
        self.serverUrl = serverUrl
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

    @State var isPresentedSelect = false

    @ObservedObject var uploadAssets: NCUploadAssets

    init(_ uploadAssets: NCUploadAssets) {
        self.uploadAssets = uploadAssets
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
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
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $isPresentedSelect) {
            NCSelectUploadAssets(delegate: uploadAssets)
        }
    }
}

// MARK: - UIViewControllerRepresentable

struct NCSelectUploadAssets: UIViewControllerRepresentable {

    typealias UIViewControllerType = UINavigationController
    @ObservedObject var delegate: NCUploadAssets

    func makeUIViewController(context: Context) -> UINavigationController {

        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController
        let viewController = navigationController?.topViewController as? NCSelect

        viewController?.delegate = delegate
        viewController?.typeOfCommandView = .selectCreateFolder
        viewController?.includeDirectoryE2EEncryption = true

        return navigationController!
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }
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
