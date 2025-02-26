//
//  NCCapabilitiesModel.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

///
 /// Data model for ``NCCapabilitiesView``.
 ///
 /// Compiles capabilities, their availability and symbol images for display.
 ///
class NCCapabilitiesModel: ObservableObject, ViewOnAppearHandling {
    struct Capability: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let image: UIImage
        let resize: Bool
        let available: Bool
    }
    @Published var capabililies: [Capability] = []
    @Published var homeServer = ""
    /// Root View Controller
    @Published var controller: NCMainTabBarController?
    /// Get session
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    init(controller: NCMainTabBarController?) {
        self.controller = controller
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        var textEditor = false
        var onlyofficeEditors = false
        let capability = NCCapabilities.shared.getCapabilities(account: session.account)
        capabililies.removeAll()

        var image = utility.loadImage(named: "person.fill.badge.plus")
        capabililies.append(Capability(text: "File sharing", image: image, resize: false, available: capability.capabilityFileSharingApiEnabled))

        image = utility.loadImage(named: "gauge.with.dots.needle.bottom.100percent")
        capabililies.append(Capability(text: "Download Limit", image: image, resize: false, available: capability.capabilityFileSharingDownloadLimit))

        image = utility.loadImage(named: "network")
        capabililies.append(Capability(text: "External site", image: image, resize: false, available: capability.capabilityExternalSites))

        image = utility.loadImage(named: "lock")
        capabililies.append(Capability(text: "End-to-End Encryption", image: image, resize: false, available: capability.capabilityE2EEEnabled))

        image = utility.loadImage(named: "bolt")
        capabililies.append(Capability(text: "Activity", image: image, resize: false, available: !capability.capabilityActivity.isEmpty))

        image = utility.loadImage(named: "bell")
        capabililies.append(Capability(text: "Notification", image: image, resize: false, available: !capability.capabilityNotification.isEmpty))

        image = utility.loadImage(named: "trash")
        capabililies.append(Capability(text: "Deleted files", image: image, resize: false, available: capability.capabilityFilesUndelete))

        if let editors = NCManageDatabase.shared.getDirectEditingEditors(account: session.account) {
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

        capabililies.append(Capability(text: "Collabora", image: utility.loadImage(named: "collabora"), resize: true, available: capability.capabilityRichDocumentsEnabled))

        capabililies.append(Capability(text: "User Status", image: utility.loadImage(named: "moon"), resize: false, available: capability.capabilityUserStatusEnabled))

        capabililies.append(Capability(text: "Comments", image: utility.loadImage(named: "ellipsis.bubble"), resize: false, available: capability.capabilityFilesComments))

        capabililies.append(Capability(text: "Lock file", image: utility.loadImage(named: "lock"), resize: false, available: !capability.capabilityFilesLockVersion.isEmpty))

        capabililies.append(Capability(text: "Group folders", image: utility.loadImage(named: "person.2"), resize: false, available: capability.capabilityGroupfoldersEnabled))

        if NCBrandOptions.shared.brand != "Nextcloud" {
            capabililies.append(Capability(text: "Security Guard Diagnostics", image: utility.loadImage(named: "shield"), resize: false, available: capability.capabilitySecurityGuardDiagnostics))
        }

        capabililies.append(Capability(text: "Assistant", image: utility.loadImage(named: "sparkles"), resize: false, available: capability.capabilityAssistantEnabled))

        homeServer = utilityFileSystem.getHomeServer(session: session) + "/"
    }
}
