//
//  NCCapabilitiesView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/05/23.
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
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    init() {
        loadCapabilities()
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil, queue: nil) { _ in
            self.loadCapabilities()
        }
    }

    func loadCapabilities() {
        guard let activeAccount = NCManageDatabase.shared.getActiveAccount() else { return }
        var textEditor = false
        var onlyofficeEditors = false

        capabililies.removeAll()

        var image = utility.loadImage(named: "person.fill.badge.plus")
        capabililies.append(Capability(text: "File sharing", image: image, resize: false, available: NCGlobal.shared.capabilityFileSharingApiEnabled))

        image = utility.loadImage(named: "network")
        capabililies.append(Capability(text: "External site", image: image, resize: false, available: NCGlobal.shared.capabilityExternalSites))

        image = utility.loadImage(named: "lock")
        capabililies.append(Capability(text: "End-to-End Encryption", image: image, resize: false, available: NCGlobal.shared.capabilityE2EEEnabled))

        image = utility.loadImage(named: "bolt")
        capabililies.append(Capability(text: "Activity", image: image, resize: false, available: !NCGlobal.shared.capabilityActivity.isEmpty))

        image = utility.loadImage(named: "bell")
        capabililies.append(Capability(text: "Notification", image: image, resize: false, available: !NCGlobal.shared.capabilityNotification.isEmpty))

        image = utility.loadImage(named: "trash")
        capabililies.append(Capability(text: "Deleted files", image: image, resize: false, available: NCGlobal.shared.capabilityFilesUndelete))

        if let editors = NCManageDatabase.shared.getDirectEditingEditors(account: activeAccount.account) {
            for editor in editors {
                if editor.editor == NCGlobal.shared.editorText {
                    textEditor = true
                } else if editor.editor == NCGlobal.shared.editorOnlyoffice {
                    onlyofficeEditors = true
                }
            }
        }

        capabililies.append(Capability(text: "Text", image: utility.loadImage(named: "doc.text"), resize: false, available: textEditor))

        capabililies.append(Capability(text: "ONLYOFFICE", image: utility.loadImage(named: "onlyoffice"), resize: true, available: onlyofficeEditors))

        capabililies.append(Capability(text: "Collabora", image: utility.loadImage(named: "collabora"), resize: true, available: NCGlobal.shared.capabilityRichDocumentsEnabled))

        capabililies.append(Capability(text: "User Status", image: utility.loadImage(named: "moon"), resize: false, available: NCGlobal.shared.capabilityUserStatusEnabled))

        capabililies.append(Capability(text: "Comments", image: utility.loadImage(named: "ellipsis.bubble"), resize: false, available: NCGlobal.shared.capabilityFilesComments))

        capabililies.append(Capability(text: "Lock file", image: utility.loadImage(named: "lock"), resize: false, available: !NCGlobal.shared.capabilityFilesLockVersion.isEmpty))

        capabililies.append(Capability(text: "Group folders", image: utility.loadImage(named: "person.2"), resize: false, available: NCGlobal.shared.capabilityGroupfoldersEnabled))

        if NCBrandOptions.shared.brand != "Nextcloud" {
            capabililies.append(Capability(text: "Security Guard Diagnostics", image: utility.loadImage(named: "shield"), resize: false, available: NCGlobal.shared.capabilitySecurityGuardDiagnostics))
        }

        capabililies.append(Capability(text: "Assistant", image: utility.loadImage(named: "sparkles"), resize: false, available: NCGlobal.shared.capabilityAssistantEnabled))

        homeServer = utilityFileSystem.getHomeServer(urlBase: activeAccount.urlBase, userId: activeAccount.userId) + "/"
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
                            CapabilityName(text: Binding.constant(capability.text), image: Image(uiImage: capability.image), resize: capability.resize)
                            CapabilityStatus(available: capability.available)
                        }
                    }
                }
                Section {
                    CapabilityName(text: $capabilitiesViewOO.homeServer, image: Image(systemName: "house"), resize: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    struct CapabilityName: View {

        @Binding var text: String
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
                    .foregroundColor(.gray)
            }
        }
    }
}

#Preview {
    func getCapabilitiesViewOOForPreview() -> NCCapabilitiesViewOO {
        let capabilitiesViewOO = NCCapabilitiesViewOO()
        capabilitiesViewOO.capabililies = [
            NCCapabilitiesViewOO.Capability(text: "Collabora", image: UIImage(named: "collabora")!, resize: true, available: true),
            NCCapabilitiesViewOO.Capability(text: "XXX site", image: UIImage(systemName: "lock.shield")!, resize: false, available: false)
        ]
        capabilitiesViewOO.homeServer = "https://cloud.nextcloud.com/remote.php.dav/files/marino/"
        return capabilitiesViewOO
    }

    return NCCapabilitiesView(capabilitiesStatus: getCapabilitiesViewOOForPreview())
}
