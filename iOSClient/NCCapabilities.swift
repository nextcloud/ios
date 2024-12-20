//
//  NCCapabilities.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/08/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//
//  NCSession.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/08/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

import Foundation
import UIKit

public class NCCapabilities: NSObject {
    static let shared = NCCapabilities()

    public class Capabilities {
        var capabilityServerVersionMajor: Int                       = 0
        var capabilityServerVersion: String                         = ""
        var capabilityFileSharingApiEnabled: Bool                   = false
        var capabilityFileSharingPubPasswdEnforced: Bool            = false
        var capabilityFileSharingPubExpireDateEnforced: Bool        = false
        var capabilityFileSharingPubExpireDateDays: Int             = 0
        var capabilityFileSharingInternalExpireDateEnforced: Bool   = false
        var capabilityFileSharingInternalExpireDateDays: Int        = 0
        var capabilityFileSharingRemoteExpireDateEnforced: Bool     = false
        var capabilityFileSharingRemoteExpireDateDays: Int          = 0
        var capabilityFileSharingDefaultPermission: Int             = 0
        var capabilityThemingColor: String                          = ""
        var capabilityThemingColorElement: String                   = ""
        var capabilityThemingColorText: String                      = ""
        var capabilityThemingName: String                           = ""
        var capabilityThemingSlogan: String                         = ""
        var capabilityE2EEEnabled: Bool                             = false
        var capabilityE2EEApiVersion: String                        = ""
        var capabilityRichDocumentsEnabled: Bool                    = false
        var capabilityRichDocumentsMimetypes = ThreadSafeArray<String>()
        var capabilityActivity = ThreadSafeArray<String>()
        var capabilityNotification = ThreadSafeArray<String>()
        var capabilityFilesUndelete: Bool                           = false
        var capabilityFilesLockVersion: String                      = ""    // NC 24
        var capabilityFilesComments: Bool                           = false // NC 20
        var capabilityFilesBigfilechunking: Bool                    = false
        var capabilityUserStatusEnabled: Bool                       = false
        var capabilityExternalSites: Bool                           = false
        var capabilityGroupfoldersEnabled: Bool                     = false // NC27
        var capabilityAssistantEnabled: Bool                        = false // NC28
        var isLivePhotoServerAvailable: Bool                        = false // NC28
        var capabilitySecurityGuardDiagnostics                      = false
        var capabilityForbiddenFileNames: [String]                  = []
        var capabilityForbiddenFileNameBasenames: [String]          = []
        var capabilityForbiddenFileNameCharacters: [String]         = []
        var capabilityForbiddenFileNameExtensions: [String]         = []
        var capabilityRecommendations: Bool                         = false
    }

    private var capabilities = ThreadSafeDictionary<String, Capabilities>()

    override private init() {}

    func disableSharesView(account: String) -> Bool {
        guard let capability = capabilities[account] else {
            return true
        }
        return (!capability.capabilityFileSharingApiEnabled && !capability.capabilityFilesComments && capability.capabilityActivity.isEmpty)
    }

    func getCapabilities(account: String?) -> Capabilities {
        if let account, let capability = capabilities[account] {
            return capability
        }
        return Capabilities()
    }

    func appendCapabilities(account: String, capabilities: Capabilities) {
        self.capabilities[account] = capabilities
    }
}
