//
//  NCSettings.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 03/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Aditya Tyagi <adityagi02@yahoo.com>
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

/// Settings view for Nextcloud
struct NCSettings: View {
    /// State to control the visibility of the acknowledgements view
    @State private var showAcknowledgements = false
    /// State to control the visibility of the passcode view
    @State private var showPasscode = false
    /// State to control the visibility of the Policy view
    @State private var showBrowser = false
    /// State to control the visibility of the Source Code  view
    @State private var showSourceCode = false
    /// Object of ViewModel of this view
    @ObservedObject var model: NCSettingsModel
    var body: some View {
        Form {
            /// `Auto Upload` Section
            Section {
                NavigationLink(destination: NCAutoUploadView(model: NCAutoUploadModel(controller: model.tabBarControllerBaseView))) {
                    HStack {
                        Image(systemName: "photo.circle")
                            .resizable()
                            .scaledToFit()
                            .font(Font.system(.body).weight(.light))
                            .frame(width: 25, height: 25)
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        Text(NSLocalizedString("_settings_autoupload_", comment: ""))
                    }
                    .font(.system(size: 16))
                }
            }
            /// `Privacy` Section
            Section(content: {
                Button(action: {
                    showPasscode.toggle()
                }, label: {
                    HStack {
                        Image(systemName: model.isLockActive ? "lock" : "lock.open")
                            .resizable()
                            .scaledToFit()
                            .font(Font.system(.body).weight(.light))
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            .frame(width: 20, height: 20)
                        Text(model.isLockActive ? NSLocalizedString("_lock_active_", comment: "") : NSLocalizedString("_lock_not_active_", comment: ""))
                    }
                    .font(.system(size: 16))
                })
                .tint(Color(NCBrandColor.shared.textColor))
                .sheet(isPresented: $showPasscode) {
                    PasscodeView(isLockActive: $model.isLockActive)
                }
                // Enable Touch ID
                Toggle(NSLocalizedString("_enable_touch_face_id_", comment: ""), isOn: $model.enableTouchID)
                    .tint(Color(NCBrandColor.shared.brandElement))
                    .font(.system(size: 16))
                    .onChange(of: model.enableTouchID) { _ in
                        model.updateTouchIDSetting()
                    }
                // Lock no screen
                Toggle(NSLocalizedString("_lock_protection_no_screen_", comment: ""), isOn: $model.lockScreen)
                    .tint(Color(NCBrandColor.shared.brandElement))
                    .font(.system(size: 16))
                    .onChange(of: model.lockScreen) { _ in
                        model.updateLockScreenSetting()
                    }
                // Privacy screen
                Toggle(NSLocalizedString("_privacy_screen_", comment: ""), isOn: $model.privacyScreen)
                    .tint(Color(NCBrandColor.shared.brandElement))
                    .font(.system(size: 16))
                    .onChange(of: model.privacyScreen) { _ in
                        model.updatePrivacyScreenSetting()
                    }
                // Reset app wrong attempts
                Toggle(NSLocalizedString("_reset_wrong_passcode_", comment: ""), isOn: $model.resetWrongAttempts)
                    .tint(Color(NCBrandColor.shared.brandElement))
                    .font(.system(size: 16))
                    .onChange(of: model.resetWrongAttempts) { _ in
                        model.updateResetWrongAttemptsSetting()
                    }
            }, header: {
                Text(NSLocalizedString("_privacy_", comment: ""))
            }, footer: {
                Text(NSLocalizedString("_privacy_footer_", comment: ""))
                    .font(.system(size: 12))
                    .lineSpacing(1)
            })
            // Calender & Contacts
            if !NCBrandOptions.shared.disable_mobileconfig {
                Section(content: {
                    Button(action: {
                        model.getConfigFiles()
                    }, label: {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .resizable()
                                .scaledToFit()
                                .font(Font.system(.body).weight(.light))
                                .frame(width: 25, height: 25)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            Text(NSLocalizedString("_mobile_config_", comment: ""))
                        }
                        .font(.system(size: 16))
                    })
                    .tint(Color(NCBrandColor.shared.textColor))
                }, header: {
                    Text(NSLocalizedString("_calendar_contacts_", comment: ""))
                }, footer: {
                    Text(NSLocalizedString("_calendar_contacts_footer_", comment: ""))
                        .font(.system(size: 12))
                        .lineSpacing(1)
                })
            }
            /// `E2EEncryption` Section
            if model.isE2EEEnable && NCGlobal.shared.e2eeVersions.contains(model.versionE2EE) {
                E2EESection()
            }
            /// `Advanced` Section
            Section {
                NavigationLink(destination: NCSettingsAdvanced(viewModel: NCSettingsAdvancedModel(), showExitAlert: false, showCacheAlert: false)) {
                    HStack {
                        Image(systemName: "gear")
                            .resizable()
                            .scaledToFit()
                            .font(Font.system(.body).weight(.light))
                            .frame(width: 25, height: 25)
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        Text(NSLocalizedString("_advanced_", comment: ""))
                    }
                    .font(.system(size: 16))
                }
            }
            /// `Information` Section
            Section(header: Text(NSLocalizedString("_information_", comment: "")), content: {
                // Acknowledgements
                Button(action: {
                    showAcknowledgements.toggle()
                }, label: {
                    HStack {
                        Image("acknowledgements")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 25, height: 25)
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        Text(NSLocalizedString("_acknowledgements_", comment: ""))
                    }
                    .font(.system(size: 16))
                })
                .tint(Color(NCBrandColor.shared.textColor))
                .sheet(isPresented: $showAcknowledgements) {
                    NCAcknowledgementsView(browserTitle: NSLocalizedString("_acknowledgements_", comment: ""))
                }
                // Terms & Privacy Conditions
                Button(action: {
                    showBrowser.toggle()
                }, label: {
                    HStack {
                        Image(systemName: "shield.checkerboard")
                            .resizable()
                            .scaledToFit()
                            .font(Font.system(.body).weight(.light))
                            .frame(width: 25, height: 25)
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        Text(NSLocalizedString("_privacy_legal_", comment: ""))
                    }
                    .font(.system(size: 16))
                })
                .tint(Color(NCBrandColor.shared.textColor))
                .sheet(isPresented: $showBrowser) {
                    NCBrowserWebView(urlBase: URL(string: NCBrandOptions.shared.privacy)!, browserTitle: NSLocalizedString("_privacy_legal_", comment: ""))
                }
                // Source Code
                Button(action: {
                    showSourceCode.toggle()
                }, label: {
                    HStack {
                        Image("gitHub")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 25, height: 25)
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        Text(NSLocalizedString("_source_code_", comment: ""))
                    }
                    .font(.system(size: 16))
                })
                .tint(Color(NCBrandColor.shared.textColor))
                .sheet(isPresented: $showSourceCode) {
                    NCBrowserWebView(urlBase: URL(string: NCBrandOptions.shared.sourceCode)!, browserTitle: NSLocalizedString("_source_code_", comment: ""))
                }
            })
            /// `Watermark` Section
            Section(content: {
            }, footer: {
                Text("Nextcloud Liquid for iOS \(model.appVersion) © \(model.copyrightYear) \n\nNextcloud Server \(model.serverVersion)\n\(model.themingName) - \(model.themingSlogan)\n\n")

            })
        }.navigationBarTitle("Settings")
        .defaultViewModifier(model)
    }
}

struct E2EESection: View {
    var body: some View {
        Section(header: Text(NSLocalizedString("_e2e_settings_title_", comment: "")), content: {
            NavigationLink(destination: NCViewE2EE(account: AppDelegate().account, rootViewController: nil)) {
                HStack {
                    Image(systemName: "lock")
                        .resizable()
                        .scaledToFit()
                        .font(Font.system(.body).weight(.light))
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                    Text(NSLocalizedString("_e2e_settings_", comment: ""))
                }
                .font(.system(size: 16))
            }
        })
    }
}

