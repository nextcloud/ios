//
//  NCManageDatabase+Capabilities.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 29/05/23.
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

import Foundation
import RealmSwift
import NextcloudKit

class tableCapabilities: Object {

    @objc dynamic var account = ""
    @objc dynamic var jsondata: Data?

    override static func primaryKey() -> String {
        return "account"
    }
}

extension NCManageDatabase {

    func addCapabilitiesJSon(_ data: Data, account: String) {

        do {
            let realm = try Realm()
            try realm.write {
                let addObject = tableCapabilities()
                addObject.account = account
                addObject.jsondata = data
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getCapabilities(account: String) -> Data? {

        do {
            let realm = try Realm()
            guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else { return nil }
            return result.jsondata
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }

        return nil
    }

    func setCapabilities(account: String, data: Data? = nil) {

        let jsonData: Data?

        struct CapabilityNextcloud: Codable {

            struct Ocs: Codable {
                let meta: Meta
                let data: Data

                struct Meta: Codable {
                    let status: String?
                    let message: String?
                    let statuscode: Int?
                }

                struct Data: Codable {
                    let version: Version
                    let capabilities: Capabilities

                    struct Version: Codable {
                        let string: String
                        let major: Int
                    }

                    struct Capabilities: Codable {
                        let filessharing: FilesSharing?
                        let theming: Theming?
                        let endtoendencryption: EndToEndEncryption?
                        let richdocuments: RichDocuments?
                        let activity: Activity?
                        let notifications: Notifications?
                        let files: Files?
                        let userstatus: UserStatus?
                        let external: External?
                        let groupfolders: GroupFolders?

                        enum CodingKeys: String, CodingKey {
                            case filessharing = "files_sharing"
                            case theming
                            case endtoendencryption = "end-to-end-encryption"
                            case richdocuments, activity, notifications, files
                            case userstatus = "user_status"
                            case external, groupfolders
                        }

                        struct FilesSharing: Codable {
                            let apienabled: Bool?
                            let groupsharing: Bool?
                            let resharing: Bool?
                            let defaultpermissions: Int?
                            let ncpublic: Public?

                            enum CodingKeys: String, CodingKey {
                                case apienabled = "api_enabled"
                                case groupsharing = "group_sharing"
                                case resharing
                                case defaultpermissions = "default_permissions"
                                case ncpublic = "public"
                            }

                            struct Public: Codable {
                                let upload: Bool
                                let enabled: Bool
                                let password: Password?
                                let sendmail: Bool
                                let uploadfilesdrop: Bool
                                let multiplelinks: Bool
                                let expiredate: ExpireDate?
                                let expiredateinternal: ExpireDate?
                                let expiredateremote: ExpireDate?

                                enum CodingKeys: String, CodingKey {
                                    case upload, enabled, password
                                    case sendmail = "send_mail"
                                    case uploadfilesdrop = "upload_files_drop"
                                    case multiplelinks = "multiple_links"
                                    case expiredate = "expire_date"
                                    case expiredateinternal = "expire_date_internal"
                                    case expiredateremote = "expire_date_remote"
                                }

                                struct Password: Codable {
                                    let enforced: Bool?
                                    let askForOptionalPassword: Bool?
                                }

                                struct ExpireDate: Codable {
                                    let enforced: Bool?
                                    let days: Int?
                                }
                            }
                        }

                        struct Theming: Codable {
                            let color: String?
                            let colorelement: String?
                            let colortext: String?
                            let colorelementbright: String?
                            let backgrounddefault: Bool?
                            let backgroundplain: Bool?
                            let colorelementdark: String?
                            let name: String?
                            let slogan: String?
                            let url: String?
                            let logo: String?
                            let background: String?
                            let logoheader: String?
                            let favicon: String?

                            enum CodingKeys: String, CodingKey {
                                case color
                                case colorelement = "color-element"
                                case colortext = "color-text"
                                case colorelementbright = "color-element-bright"
                                case backgrounddefault = "background-default"
                                case backgroundplain = "background-plain"
                                case colorelementdark = "color-element-dark"
                                case name, slogan, url, logo, background, logoheader, favicon
                            }
                        }

                        struct EndToEndEncryption: Codable {
                            let enabled: Bool?
                            let apiversion: String?
                            let keysexist: Bool?

                            enum CodingKeys: String, CodingKey {
                                case enabled
                                case apiversion = "api-version"
                                case keysexist = "keys-exist"
                            }
                        }

                        struct RichDocuments: Codable {
                            let mimetypes: [String]?
                        }

                        struct Activity: Codable {
                            let apiv2: [String]?
                        }

                        struct Notifications: Codable {
                            let ocsendpoints: [String]?

                            enum CodingKeys: String, CodingKey {
                                case ocsendpoints = "ocs-endpoints"
                            }
                        }

                        struct Files: Codable {
                            let undelete: Bool?
                            let locking: String?
                            let comments: Bool?
                            let versioning: Bool?
                            let directEditing: DirectEditing?
                            let bigfilechunking: Bool?
                            let versiondeletion: Bool?
                            let versionlabeling: Bool?

                            enum CodingKeys: String, CodingKey {
                                case undelete, locking, comments, versioning, directEditing, bigfilechunking
                                case versiondeletion = "version_deletion"
                                case versionlabeling = "version_labeling"
                            }

                            struct DirectEditing: Codable {
                                let url: String?
                                let etag: String?
                                let supportsFileId: Bool?
                            }
                        }

                        struct UserStatus: Codable {
                            let enabled: Bool?
                            let restore: Bool?
                            let supportsemoji: Bool?

                            enum CodingKeys: String, CodingKey {
                                case enabled, restore
                                case supportsemoji = "supports_emoji"
                            }
                        }

                        struct External: Codable {
                            let v1: [String]?
                        }

                        struct GroupFolders: Codable {
                            let hasGroupFolders: Bool?
                        }
                    }
                }
            }

            let ocs: Ocs
        }

        if let data = data {
            jsonData = data
        } else {
            do {
                let realm = try Realm()
                guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first,
                      let data = result.jsondata else {
                    return
                }
                jsonData = data
            } catch let error as NSError {
                NextcloudKit.shared.nkCommonInstance.writeLog("I cannot access to database: \(error)")
                return
            }
        }
        guard let jsonData = jsonData else { return }

        do {
            let json = try JSONDecoder().decode(CapabilityNextcloud.self, from: jsonData)
            NCGlobal.shared.capabilityServerVersion = json.ocs.data.version.string
            NCGlobal.shared.capabilityServerVersionMajor = json.ocs.data.version.major

            NCGlobal.shared.capabilityFileSharingApiEnabled = json.ocs.data.capabilities.filessharing?.apienabled ?? false
            NCGlobal.shared.capabilityFileSharingDefaultPermission = json.ocs.data.capabilities.filessharing?.defaultpermissions ?? 0
            NCGlobal.shared.capabilityFileSharingPubPasswdEnforced = json.ocs.data.capabilities.filessharing?.ncpublic?.password?.enforced ?? false
            NCGlobal.shared.capabilityFileSharingPubExpireDateEnforced = json.ocs.data.capabilities.filessharing?.ncpublic?.expiredate?.enforced ?? false
            NCGlobal.shared.capabilityFileSharingPubExpireDateDays = json.ocs.data.capabilities.filessharing?.ncpublic?.expiredate?.days ?? 0
            NCGlobal.shared.capabilityFileSharingInternalExpireDateEnforced = json.ocs.data.capabilities.filessharing?.ncpublic?.expiredateinternal?.enforced ?? false
            NCGlobal.shared.capabilityFileSharingInternalExpireDateDays = json.ocs.data.capabilities.filessharing?.ncpublic?.expiredateinternal?.days ?? 0
            NCGlobal.shared.capabilityFileSharingRemoteExpireDateEnforced = json.ocs.data.capabilities.filessharing?.ncpublic?.expiredateremote?.enforced ?? false
            NCGlobal.shared.capabilityFileSharingRemoteExpireDateDays = json.ocs.data.capabilities.filessharing?.ncpublic?.expiredateremote?.days ?? 0

            NCGlobal.shared.capabilityThemingColor = json.ocs.data.capabilities.theming?.color ?? ""
            NCGlobal.shared.capabilityThemingColorElement = json.ocs.data.capabilities.theming?.colorelement ?? ""
            NCGlobal.shared.capabilityThemingColorText = json.ocs.data.capabilities.theming?.colortext ?? ""
            NCGlobal.shared.capabilityThemingName = json.ocs.data.capabilities.theming?.name ?? ""
            NCGlobal.shared.capabilityThemingSlogan = json.ocs.data.capabilities.theming?.slogan ?? ""

            NCGlobal.shared.capabilityE2EEEnabled = json.ocs.data.capabilities.endtoendencryption?.enabled ?? false
            NCGlobal.shared.capabilityE2EEApiVersion = json.ocs.data.capabilities.endtoendencryption?.apiversion ?? ""

            NCGlobal.shared.capabilityRichdocumentsMimetypes.removeAll()
            if let mimetypes = json.ocs.data.capabilities.richdocuments?.mimetypes {
                for mimetype in mimetypes {
                    NCGlobal.shared.capabilityRichdocumentsMimetypes.append(mimetype)
                }
            }

            NCGlobal.shared.capabilityActivity.removeAll()
            if let activities = json.ocs.data.capabilities.activity?.apiv2 {
                for activity in activities {
                    NCGlobal.shared.capabilityActivity.append(activity)
                }
            }

            NCGlobal.shared.capabilityNotification.removeAll()
            if let notifications = json.ocs.data.capabilities.notifications?.ocsendpoints {
                for notification in notifications {
                    NCGlobal.shared.capabilityNotification.append(notification)
                }
            }

            NCGlobal.shared.capabilityFilesUndelete = json.ocs.data.capabilities.files?.undelete ?? false
            NCGlobal.shared.capabilityFilesLockVersion = json.ocs.data.capabilities.files?.locking ?? ""
            NCGlobal.shared.capabilityFilesComments = json.ocs.data.capabilities.files?.comments ?? false

            NCGlobal.shared.capabilityUserStatusEnabled = json.ocs.data.capabilities.files?.undelete ?? false
            if json.ocs.data.capabilities.external != nil {
                NCGlobal.shared.capabilityExternalSites = true
            }
            NCGlobal.shared.capabilityGroupfoldersEnabled = json.ocs.data.capabilities.groupfolders?.hasGroupFolders ?? false
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("I cannot access to database: \(error)")
            return
        }
    }
}
