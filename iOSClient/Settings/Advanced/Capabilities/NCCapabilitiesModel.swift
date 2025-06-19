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
import NextcloudKit

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
        let cap = NKCapabilities.shared.getCapabilitiesBlocking(for: session.account)
        capabililies.removeAll()

        var image = utility.loadImage(named: "person.fill.badge.plus")
        capabililies.append(Capability(text: "File sharing", image: image, resize: false, available: cap.fileSharingApiEnabled))

        image = utility.loadImage(named: "gauge.with.dots.needle.bottom.100percent")
        capabililies.append(Capability(text: "Download Limit", image: image, resize: false, available: cap.fileSharingDownloadLimit))

        image = utility.loadImage(named: "network")
        capabililies.append(Capability(text: "External site", image: image, resize: false, available: cap.externalSites))

        image = utility.loadImage(named: "lock")
        capabililies.append(Capability(text: "End-to-End Encryption", image: image, resize: false, available: cap.e2EEEnabled))

        image = utility.loadImage(named: "bolt")
        capabililies.append(Capability(text: "Activity", image: image, resize: false, available: !cap.activity.isEmpty))

        image = utility.loadImage(named: "bell")
        capabililies.append(Capability(text: "Notification", image: image, resize: false, available: !cap.notification.isEmpty))

        image = utility.loadImage(named: "trash")
        capabililies.append(Capability(text: "Deleted files", image: image, resize: false, available: cap.filesUndelete))

        let editors = cap.directEditingCreators
        for editor in editors {
            if editor.editor == "text" {
                textEditor = true
            } else if editor.editor == NCGlobal.shared.editorOnlyoffice {
                onlyofficeEditors = true
            }
        }

        capabililies.append(Capability(text: "Text", image: utility.loadImage(named: "doc.text"), resize: false, available: textEditor))

        capabililies.append(Capability(text: "ONLYOFFICE", image: utility.loadImage(named: "onlyoffice"), resize: true, available: onlyofficeEditors))

        capabililies.append(Capability(text: "Collabora", image: utility.loadImage(named: "collabora"), resize: true, available: cap.richDocumentsEnabled))

        capabililies.append(Capability(text: "User Status", image: utility.loadImage(named: "moon"), resize: false, available: cap.userStatusEnabled))

        capabililies.append(Capability(text: "Comments", image: utility.loadImage(named: "ellipsis.bubble"), resize: false, available: cap.filesComments))

        capabililies.append(Capability(text: "Lock file", image: utility.loadImage(named: "lock"), resize: false, available: !cap.filesLockVersion.isEmpty))

        capabililies.append(Capability(text: "Group folders", image: utility.loadImage(named: "person.2"), resize: false, available: cap.groupfoldersEnabled))

        if NCBrandOptions.shared.brand != "Nextcloud" {
            capabililies.append(Capability(text: "Security Guard Diagnostics", image: utility.loadImage(named: "shield"), resize: false, available: cap.securityGuardDiagnostics))
        }

        capabililies.append(Capability(text: "Assistant", image: utility.loadImage(named: "sparkles"), resize: false, available: cap.assistantEnabled))

        homeServer = utilityFileSystem.getHomeServer(session: session) + "/"
    }
}
