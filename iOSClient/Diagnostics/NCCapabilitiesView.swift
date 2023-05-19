//
//  NCCapabilitiesView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/05/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit

@objc class NCHostingCapabilitiesView: NSObject {

    @objc func makeShipDetailsUI() -> UIViewController {

        let capabilitiesStatus = NCCapabilitiesStatus()
        let view = NCCapabilitiesView(capabilitiesStatus: capabilitiesStatus)
        let vc = UIHostingController(rootView: view)
        vc.title = NSLocalizedString("_capabilities_", comment: "")
        return vc
    }
}

class NCCapabilitiesStatus: ObservableObject {

    struct Capability: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let image: UIImage
        let available: Bool
    }

    @Published var capabililies: [Capability] = []

    init(preview: Bool = false) {

        if preview {
            capabililies = [Capability(text: "File sharing", image: UIImage(named: "share")!, available: true),
                            Capability(text: "Externa site", image: UIImage(systemName: "network")!, available: false)
            ]
        } else {
            guard let account = NCManageDatabase.shared.getActiveAccount()?.account else { return }
            getCapabilities(account: account)
            updateCapabilities(account: account)
        }
    }

    func getCapabilities(account: String) {

        NextcloudKit.shared.getCapabilities { account, data, error in
            if error == .success && data != nil {
                NCManageDatabase.shared.addCapabilitiesJSon(data!, account: account)
                let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
                if serverVersionMajor >= NCGlobal.shared.nextcloudVersion18 {
                    NextcloudKit.shared.NCTextObtainEditorDetails { account, editors, creators, _, error in
                        if error == .success {
                            NCManageDatabase.shared.addDirectEditing(account: account, editors: editors, creators: creators)
                            self.updateCapabilities(account: account)
                        }
                    }
                } else {
                    self.updateCapabilities(account: account)
                }
            } else {
                self.updateCapabilities(account: account)
            }
        }
    }

    func updateCapabilities(account: String) {

        var available: Bool = false
        capabililies.removeAll()

        // File Sharing
        available = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFileSharingApiEnabled, exists: false)
        capabililies.append(Capability(text: "File sharing", image: UIImage(named: "share")!.resizeImage(size: CGSize(width: 25, height: 25))!, available: available))

        // ExternalSites
        available = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesExternalSitesExists, exists: true)
        capabililies.append(Capability(text: "External site", image: UIImage(systemName: "network")!, available: available))

        // E2EE
        available = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesE2EEEnabled, exists: false)
        capabililies.append(Capability(text: "End-to-End Encryption", image: UIImage(systemName: "lock")!, available: available))


        if let text = NCManageDatabase.shared.getCapabilities(account: account) {
            // self.capabilitiesText = text
        }
    }
}

struct NCCapabilitiesView: View {

    @ObservedObject var capabilitiesStatus: NCCapabilitiesStatus

    init(capabilitiesStatus: NCCapabilitiesStatus) {
        self.capabilitiesStatus = capabilitiesStatus
    }

    var body: some View {
        VStack {
            List {
                ForEach(capabilitiesStatus.capabililies, id: \.id) { capability in
                    HStack {
                        Capability(text: capability.text, image: Image(uiImage: capability.image))
                        CapabilityAvailable(available: capability.available)
                    }
                    .complexModifier { view in
                        if #available(iOS 15, *) {
                            view.listRowSeparator(.hidden)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct Capability: View {

    @State var text: String = ""
    @State var image: Image

    var body: some View {
        Label {
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color(UIColor.systemGray))
        } icon: {
            image
                .renderingMode(.template)
                .foregroundColor(Color(UIColor.systemGray))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CapabilityAvailable: View {

    @State private var text: String

    init(available: Bool) {
        if available {
            _text = State(initialValue: NSLocalizedString("_available_", comment: ""))
        } else {
            _text = State(initialValue: NSLocalizedString("_not_available_", comment: ""))

        }
    }

    var body: some View {
        Text(text)
            .frame(width: 100)
            .font(.system(size: 12))
            .padding(EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12))
            .foregroundColor(.primary)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(UIColor.systemGray), lineWidth: 0.5)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct NCCapabilitiesView_Previews: PreviewProvider {
    static var previews: some View {
        NCCapabilitiesView(capabilitiesStatus: NCCapabilitiesStatus(preview: true))
    }
}
