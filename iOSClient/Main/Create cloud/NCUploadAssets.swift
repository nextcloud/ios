//
//  NCUploadAssets.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 04/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

class NCHostingUploadAssetsView: NSObject {

    @objc func makeShipDetailsUI(assets: [PHAsset], cryptated: Bool, session: String ,userBaseUrl: NCUserBaseUrl, serverUrl: String) -> UIViewController {

        let uploadAssets = NCUploadAssets(assets: assets, cryptated: cryptated, session: session, userBaseUrl: userBaseUrl, serverUrl: serverUrl)
        let details = UploadAssetsView(uploadAssets: uploadAssets)
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

struct UploadAssetsView: View {

    @ObservedObject var uploadAssets: NCUploadAssets

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

// MARK: - Preview

struct UploadAssetsView_Previews: PreviewProvider {
    static var previews: some View {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            let uploadAssets = NCUploadAssets(assets: [], cryptated: false, session: "", userBaseUrl: appDelegate, serverUrl: "ABCD")
            UploadAssetsView(uploadAssets: uploadAssets)
        }
    }
}
