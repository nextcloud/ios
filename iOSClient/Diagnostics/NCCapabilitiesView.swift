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
        let available: Bool
    }

    @Published var capabililies: [Capability] = []
    @Published var homeServer = ""

    init() {

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            capabililies = [Capability(text: "File sharing", image: UIImage(named: "share")!.resizeImage(size: CGSize(width: 25, height: 25))!, available: true),
                            Capability(text: "Externa site", image: UIImage(systemName: "network")!, available: false)
            ]
            homeServer = "https://cloud.nextcloud.com/remote.php.dav/files/marino/"
        } else {
            guard let activeAccount = NCManageDatabase.shared.getActiveAccount() else { return }
            var textEditor = false
            var onlyofficeEditors = false

            capabililies.append(Capability(text: "File sharing", image: UIImage(named: "share")!.resizeImage(size: CGSize(width: 25, height: 25))!, available: NCGlobal.shared.capabilityFileSharingApiEnabled))
            capabililies.append(Capability(text: "External site", image: UIImage(systemName: "network")!, available: NCGlobal.shared.capabilityExternalSites))
            capabililies.append(Capability(text: "End-to-End Encryption", image: UIImage(systemName: "lock")!, available: NCGlobal.shared.capabilityE2EEEnabled))
            capabililies.append(Capability(text: "Activity", image: UIImage(systemName: "bolt")!, available: !NCGlobal.shared.capabilityActivity.isEmpty))
            capabililies.append(Capability(text: "Notification", image: UIImage(systemName: "bell")!, available: !NCGlobal.shared.capabilityNotification.isEmpty))
            capabililies.append(Capability(text: "Deleted files", image: UIImage(systemName: "trash")!, available: NCGlobal.shared.capabilityFilesUndelete))

            if let editors = NCManageDatabase.shared.getDirectEditingEditors(account: activeAccount.account) {
                for editor in editors {
                    if editor.editor == NCGlobal.shared.editorText {
                        textEditor = true
                    } else if editor.editor == NCGlobal.shared.editorOnlyoffice {
                        onlyofficeEditors = true
                    }
                }
            }
            capabililies.append(Capability(text: "Text", image: UIImage(named: "text")!.resizeImage(size: CGSize(width: 25, height: 25))!, available: textEditor))
            capabililies.append(Capability(text: "ONLYOFFICE", image: UIImage(named: "onlyoffice")!.resizeImage(size: CGSize(width: 25, height: 25))!, available: onlyofficeEditors))
            capabililies.append(Capability(text: "Collabora", image: UIImage(named: "collabora")!.resizeImage(size: CGSize(width: 25, height: 25))!, available: !NCGlobal.shared.capabilityRichdocumentsMimetypes.isEmpty))
            capabililies.append(Capability(text: "User Status", image: UIImage(systemName: "moon")!, available: NCGlobal.shared.capabilityUserStatusEnabled))
            capabililies.append(Capability(text: "Comments", image: UIImage(systemName: "ellipsis.bubble")!, available: NCGlobal.shared.capabilityFilesComments))
            capabililies.append(Capability(text: "Lock file", image: UIImage(systemName: "lock")!, available: !NCGlobal.shared.capabilityFilesLockVersion.isEmpty))
            capabililies.append(Capability(text: "Group folders", image: UIImage(systemName: "person.2")!, available: NCGlobal.shared.capabilityGroupfoldersEnabled))

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
                            CapabilityName(text: capability.text, image: Image(uiImage: capability.image))
                            CapabilityStatus(available: capability.available)
                        }
                    }
                }
                Section {
                    CapabilityName(text: capabilitiesViewOO.homeServer, image: Image(uiImage: UIImage(systemName: "house")!))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    struct CapabilityName: View {

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
