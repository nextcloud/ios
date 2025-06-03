// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
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

    // MARK: - Realm write

    func addCapabilitiesJSon(_ data: Data, account: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let addObject = tableCapabilities()
            addObject.account = account
            addObject.jsondata = data
            realm.add(addObject, update: .all)
        }
    }

    @discardableResult
    func setCapabilities(account: String, data: Data? = nil) -> NCCapabilities.Capabilities? {
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
                        let downloadLimit: DownloadLimit?
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
                        let securityguard: SecurityGuard?
                        let assistant: Assistant?
                        let recommendations: Recommendations?

                        enum CodingKeys: String, CodingKey {
                            case downloadLimit = "downloadlimit"
                            case filessharing = "files_sharing"
                            case theming
                            case endtoendencryption = "end-to-end-encryption"
                            case richdocuments, activity, notifications, files
                            case userstatus = "user_status"
                            case external, groupfolders
                            case securityguard = "security_guard"
                            case assistant
                            case recommendations
                        }

                        struct DownloadLimit: Codable {
                            let enabled: Bool?
                            let defaultLimit: Int?
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
                                let enabled: Bool
                                let upload: Bool?
                                let password: Password?
                                let sendmail: Bool?
                                let uploadfilesdrop: Bool?
                                let multiplelinks: Bool?
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
                            let directediting: Bool?

                            enum CodingKeys: String, CodingKey {
                                case mimetypes
                                case directediting = "direct_editing"
                            }
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
                            let forbiddenFileNames: [String]?
                            let forbiddenFileNameBasenames: [String]?
                            let forbiddenFileNameCharacters: [String]?
                            let forbiddenFileNameExtensions: [String]?

                            enum CodingKeys: String, CodingKey {
                                case undelete, locking, comments, versioning, directEditing, bigfilechunking
                                case versiondeletion = "version_deletion"
                                case versionlabeling = "version_labeling"
                                case forbiddenFileNames = "forbidden_filenames"
                                case forbiddenFileNameBasenames = "forbidden_filename_basenames"
                                case forbiddenFileNameCharacters = "forbidden_filename_characters"
                                case forbiddenFileNameExtensions = "forbidden_filename_extensions"
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

                        struct SecurityGuard: Codable {
                            let diagnostics: Bool?
                        }

                        struct Assistant: Codable {
                            let enabled: Bool?
                            let version: String?
                        }

                        struct Recommendations: Codable {
                            let enabled: Bool?
                        }
                    }
                }
            }

            let ocs: Ocs
        }

        if let data {
            jsonData = data
        } else {
            jsonData = performRealmRead { realm in
                realm.objects(tableCapabilities.self)
                    .filter("account == %@", account)
                    .first?
                    .jsondata
            }
        }

        guard let jsonData
        else {
            return nil
        }

        do {
            let json = try JSONDecoder().decode(CapabilityNextcloud.self, from: jsonData)
            let data = json.ocs.data
            let capabilities = NCCapabilities.Capabilities()

            capabilities.capabilityServerVersion = data.version.string
            capabilities.capabilityServerVersionMajor = data.version.major

            if capabilities.capabilityServerVersionMajor > 0 {
                NextcloudKit.shared.updateSession(account: account, nextcloudVersion: capabilities.capabilityServerVersionMajor)
            }

            capabilities.capabilityFileSharingApiEnabled = data.capabilities.filessharing?.apienabled ?? false
            capabilities.capabilityFileSharingDefaultPermission = data.capabilities.filessharing?.defaultpermissions ?? 0
            capabilities.capabilityFileSharingPubPasswdEnforced = data.capabilities.filessharing?.ncpublic?.password?.enforced ?? false
            capabilities.capabilityFileSharingPubExpireDateEnforced = data.capabilities.filessharing?.ncpublic?.expiredate?.enforced ?? false
            capabilities.capabilityFileSharingPubExpireDateDays = data.capabilities.filessharing?.ncpublic?.expiredate?.days ?? 0
            capabilities.capabilityFileSharingInternalExpireDateEnforced = data.capabilities.filessharing?.ncpublic?.expiredateinternal?.enforced ?? false
            capabilities.capabilityFileSharingInternalExpireDateDays = data.capabilities.filessharing?.ncpublic?.expiredateinternal?.days ?? 0
            capabilities.capabilityFileSharingRemoteExpireDateEnforced = data.capabilities.filessharing?.ncpublic?.expiredateremote?.enforced ?? false
            capabilities.capabilityFileSharingRemoteExpireDateDays = data.capabilities.filessharing?.ncpublic?.expiredateremote?.days ?? 0
            capabilities.capabilityFileSharingDownloadLimit = data.capabilities.downloadLimit?.enabled ?? false
            capabilities.capabilityFileSharingDownloadLimitDefaultLimit = data.capabilities.downloadLimit?.defaultLimit ?? 1

            capabilities.capabilityThemingColor = data.capabilities.theming?.color ?? ""
            capabilities.capabilityThemingColorElement = data.capabilities.theming?.colorelement ?? ""
            capabilities.capabilityThemingColorText = data.capabilities.theming?.colortext ?? ""
            capabilities.capabilityThemingName = data.capabilities.theming?.name ?? ""
            capabilities.capabilityThemingSlogan = data.capabilities.theming?.slogan ?? ""

            capabilities.capabilityE2EEEnabled = data.capabilities.endtoendencryption?.enabled ?? false
            capabilities.capabilityE2EEApiVersion = data.capabilities.endtoendencryption?.apiversion ?? ""

            capabilities.capabilityRichDocumentsEnabled = json.ocs.data.capabilities.richdocuments?.directediting ?? false
            capabilities.capabilityRichDocumentsMimetypes.removeAll()
            if let mimetypes = data.capabilities.richdocuments?.mimetypes {
                for mimetype in mimetypes {
                    capabilities.capabilityRichDocumentsMimetypes.append(mimetype)
                }
            }

            capabilities.capabilityAssistantEnabled = data.capabilities.assistant?.enabled ?? false

            capabilities.capabilityActivityEnabled = data.capabilities.activity != nil

            capabilities.capabilityActivity.removeAll()
            if let activities = data.capabilities.activity?.apiv2 {
                for activity in activities {
                    capabilities.capabilityActivity.append(activity)
                }
            }

            capabilities.capabilityNotification.removeAll()
            if let notifications = data.capabilities.notifications?.ocsendpoints {
                for notification in notifications {
                    capabilities.capabilityNotification.append(notification)
                }
            }

            capabilities.capabilityFilesUndelete = data.capabilities.files?.undelete ?? false
            capabilities.capabilityFilesLockVersion = data.capabilities.files?.locking ?? ""
            capabilities.capabilityFilesComments = data.capabilities.files?.comments ?? false
            capabilities.capabilityFilesBigfilechunking = data.capabilities.files?.bigfilechunking ?? false

            capabilities.capabilityUserStatusEnabled = data.capabilities.userstatus?.enabled ?? false
            if data.capabilities.external != nil {
                capabilities.capabilityExternalSites = true
            }
            capabilities.capabilityGroupfoldersEnabled = data.capabilities.groupfolders?.hasGroupFolders ?? false

            if capabilities.capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion28 {
                capabilities.isLivePhotoServerAvailable = true
            }

            capabilities.capabilitySecurityGuardDiagnostics = data.capabilities.securityguard?.diagnostics ?? false

            capabilities.capabilityForbiddenFileNames = data.capabilities.files?.forbiddenFileNames ?? []
            capabilities.capabilityForbiddenFileNameBasenames = data.capabilities.files?.forbiddenFileNameBasenames ?? []
            capabilities.capabilityForbiddenFileNameCharacters = data.capabilities.files?.forbiddenFileNameCharacters ?? []
            capabilities.capabilityForbiddenFileNameExtensions = data.capabilities.files?.forbiddenFileNameExtensions ?? []

            capabilities.capabilityRecommendations = data.capabilities.recommendations?.enabled ?? false

            NCCapabilities.shared.appendCapabilities(account: account, capabilities: capabilities)

            return capabilities
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not decode json capabilities: \(error)")
            return nil
        }
    }
}
