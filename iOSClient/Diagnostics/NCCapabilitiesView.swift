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

        let capabilitiesStatus = NCCapabilitiesViewOO()
        let view = NCCapabilitiesView(capabilitiesStatus: capabilitiesStatus)
        let vc = UIHostingController(rootView: view)
        vc.title = NSLocalizedString("_capabilities_", comment: "")
        return vc
    }
}

class NCCapabilitiesViewOO: ObservableObject {

    struct Capability: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let image: UIImage
        let resize: Bool
        let available: Bool
    }

    @Published var capabililies: [Capability] = []
    @Published var homeServer = ""

    init() {

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            capabililies = [Capability(text: "Collabora", image: UIImage(named: "collabora")!, resize: true, available: true),
                            Capability(text: "XXX site", image: UIImage(systemName: "lock.shield")!, resize: false, available: false)
            ]
            homeServer = "https://cloud.nextcloud.com/remote.php.dav/files/marino/"
        } else {
            guard let activeAccount = NCManageDatabase.shared.getActiveAccount() else { return }
            var textEditor = false
            var onlyofficeEditors = false

            if let image = UIImage(named: "share") {
                capabililies.append(Capability(text: "File sharing", image: image, resize: true, available: NCGlobal.shared.capabilityFileSharingApiEnabled))
            }
            if let image = UIImage(systemName: "network") {
                capabililies.append(Capability(text: "External site", image: image, resize: false, available: NCGlobal.shared.capabilityExternalSites))
            }
            if let image = UIImage(systemName: "lock") {
                capabililies.append(Capability(text: "End-to-End Encryption", image: image, resize: false, available: NCGlobal.shared.capabilityE2EEEnabled))
            }
            if let image = UIImage(systemName: "bolt") {
                capabililies.append(Capability(text: "Activity", image: image, resize: false, available: !NCGlobal.shared.capabilityActivity.isEmpty))
            }
            if let image = UIImage(systemName: "bell") {
                capabililies.append(Capability(text: "Notification", image: image, resize: false, available: !NCGlobal.shared.capabilityNotification.isEmpty))
            }
            if let image = UIImage(systemName: "trash") {
                capabililies.append(Capability(text: "Deleted files", image: image, resize: false, available: NCGlobal.shared.capabilityFilesUndelete))
            }

            if let editors = NCManageDatabase.shared.getDirectEditingEditors(account: activeAccount.account) {
                for editor in editors {
                    if editor.editor == NCGlobal.shared.editorText {
                        textEditor = true
                    } else if editor.editor == NCGlobal.shared.editorOnlyoffice {
                        onlyofficeEditors = true
                    }
                }
            }

            if let image = UIImage(systemName: "doc.text") {
                capabililies.append(Capability(text: "Text", image: image, resize: false, available: textEditor))
            }
            if let image = UIImage(named: "onlyoffice") {
                capabililies.append(Capability(text: "ONLYOFFICE", image: image, resize: true, available: onlyofficeEditors))
            }
            if let image = UIImage(named: "collabora") {
                capabililies.append(Capability(text: "Collabora", image: image, resize: true, available: !NCGlobal.shared.capabilityRichdocumentsMimetypes.isEmpty))
            }
            if let image = UIImage(systemName: "moon") {
                capabililies.append(Capability(text: "User Status", image: image, resize: false, available: NCGlobal.shared.capabilityUserStatusEnabled))
            }
            if let image = UIImage(systemName: "ellipsis.bubble") {
                capabililies.append(Capability(text: "Comments", image: image, resize: false, available: NCGlobal.shared.capabilityFilesComments))
            }
            if let image = UIImage(systemName: "lock") {
                capabililies.append(Capability(text: "Lock file", image: image, resize: false, available: !NCGlobal.shared.capabilityFilesLockVersion.isEmpty))
            }
            if let image = UIImage(systemName: "person.2") {
                capabililies.append(Capability(text: "Group folders", image: image, resize: false, available: NCGlobal.shared.capabilityGroupfoldersEnabled))
            }

            homeServer = NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, userId: activeAccount.userId) + "/"
        }
    }
}

struct NCCapabilitiesView: View {

    @ObservedObject var capabilitiesViewOO: NCCapabilitiesViewOO

    init(capabilitiesStatus: NCCapabilitiesViewOO) {
        self.capabilitiesViewOO = capabilitiesStatus
    }

    var body: some View {
        VStack {
            List {
                Section {
                    ForEach(capabilitiesViewOO.capabililies, id: \.id) { capability in
                        HStack {
                            CapabilityName(text: capability.text, image: Image(uiImage: capability.image), resize: capability.resize)
                            CapabilityStatus(available: capability.available)
                        }
                    }
                }
                Section {
                    CapabilityName(text: capabilitiesViewOO.homeServer, image: Image(systemName: "house"), resize: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    struct CapabilityName: View {

        @State var text: String = ""
        @State var image: Image
        @State var resize: Bool

        var body: some View {
            Label {
                Text(text)
                    .font(.system(size: 15))
            } icon: {
                if resize {
                    image
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 23.0, height: 23.0)
                        .foregroundColor(.primary)
                } else {
                    image
                        .renderingMode(.template)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct CapabilityStatus: View {

        @State var available: Bool

        var body: some View {
            if available {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "multiply.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
}

struct NCCapabilitiesView_Previews: PreviewProvider {
    static var previews: some View {
        NCCapabilitiesView(capabilitiesStatus: NCCapabilitiesViewOO())
    }
}
