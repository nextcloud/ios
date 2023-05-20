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
    @Published var json = "Lorem ipsum dolor sit amet.\nEa voluptas aperiam aut inventore saepe in tenetur modi.\nCum sint tempore sed maiores quos aut quaerat deleniti.\nQui beatae quia qui repellat sunt in Quis libero aut quidem porro non explicabo tenetur et natus doloribus non voluptatum consequatur.\n"
    @Published var homeServer = ""

    init() {

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            capabililies = [Capability(text: "File sharing", image: UIImage(named: "share")!.resizeImage(size: CGSize(width: 25, height: 25))!, available: true),
                            Capability(text: "Externa site", image: UIImage(systemName: "network")!, available: false)
            ]
            homeServer = "https://cloud.nextcloud.com/remote.php.dav/files/marino/"
        } else {
            guard let activeAccount = NCManageDatabase.shared.getActiveAccount() else { return }
            homeServer = NCUtilityFileSystem.shared.getHomeServer(urlBase: activeAccount.urlBase, userId: activeAccount.userId) + "/"
            getCapabilities(account: activeAccount.account)
        }
    }

    func getCapabilities(account: String) {

        NextcloudKit.shared.getCapabilities { account, data, error in
            if error == .success, let data = data {
                NCManageDatabase.shared.addCapabilitiesJSon(data, account: account)
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

        updateCapabilities(account: account)
    }

    func updateCapabilities(account: String) {

        var available: Bool = false

        capabililies.removeAll()
        json = ""

        // FILE SHARING
        available = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFileSharingApiEnabled, exists: false)
        capabililies.append(Capability(text: "File sharing", image: UIImage(named: "share")!.resizeImage(size: CGSize(width: 25, height: 25))!, available: available))

        // EXTERNAL SITE
        available = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesExternalSites, exists: true)
        capabililies.append(Capability(text: "External site", image: UIImage(systemName: "network")!, available: available))

        // E2EE
        available = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesE2EEEnabled, exists: false)
        capabililies.append(Capability(text: "End-to-End Encryption", image: UIImage(systemName: "lock")!, available: available))

        // ACTIVITY
        if NCManageDatabase.shared.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesActivity) == nil {
            available = false
        } else {
            available = true
        }
        capabililies.append(Capability(text: "Activity", image: UIImage(systemName: "bolt")!, available: available))

        // NOTIFICATION
        if NCManageDatabase.shared.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesNotification) == nil {
            available = false
        } else {
            available = true
        }
        capabililies.append(Capability(text: "Notification", image: UIImage(systemName: "bell")!, available: available))

        // DELETE FILES
        available = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFilesUndelete, exists: false)
        capabililies.append(Capability(text: "Deleted files", image: UIImage(systemName: "trash")!, available: available))

        // TEXT - ONLYOFFICE
        var textEditor = false
        var onlyofficeEditors = false
        if let editors = NCManageDatabase.shared.getDirectEditingEditors(account: account) {
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

        // COLLABORA
        if NCManageDatabase.shared.getCapabilitiesServerArray(account: account, elements: NCElementsJSON.shared.capabilitiesRichdocumentsMimetypes) == nil {
            available = false
        } else {
            available = true
        }
        capabililies.append(Capability(text: "Collabora", image: UIImage(named: "collabora")!.resizeImage(size: CGSize(width: 25, height: 25))!, available: available))

        // USER STATUS
        available = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesUserStatusEnabled, exists: false)
        capabililies.append(Capability(text: "User Status", image: UIImage(systemName: "moon")!, available: available))

        // COMMENTS
        available = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFilesComments, exists: false)
        capabililies.append(Capability(text: "Comments", image: UIImage(systemName: "ellipsis.bubble")!, available: available))

        // LOCK FILE
        let hasLockCapability = NCManageDatabase.shared.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesFilesLockVersion) >= 1
        if hasLockCapability {
            available = false
        } else {
            available = true
        }
        capabililies.append(Capability(text: "Lock file", image: UIImage(systemName: "lock")!, available: available))

        // GROUP FOLDERS
        available = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesGroupfoldersEnabled, exists: false)
        capabililies.append(Capability(text: "Group folders", image: UIImage(systemName: "person.2")!, available: available))

        if let json = NCManageDatabase.shared.getCapabilities(account: account) {
            self.json = json
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
                Section {
                    ScrollView(.horizontal) {
                        Text(capabilitiesViewOO.json)
                            .font(.system(size: 12))
                    }
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
