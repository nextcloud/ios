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
    /// State to control the visibility of the Policy view
    @State private var showBrowser = false
    /// State to control the visibility of the Source Code  view
    @State private var showSourceCode = false
    /// Object of ViewModel of this view
    @ObservedObject var model = NCSettingsModel()
    var body: some View {
        Form {
            /// `Auto Upload` Section
            Section {
                NavigationLink(destination: AutoUploadView(model: AutoUploadModel())) {
                    HStack {
                        Image("autoUpload")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                        Text(NSLocalizedString("_settings_autoupload_", comment: ""))
                    }
                    .font(.system(size: 16))
                }
            }
            /// `Privacy` Section
            Section(content: {
                // Lock active YES/NO
                HStack {
                    Image(model.isLockActive ? "lock_open" : "lock")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                    Text(model.isLockActive ? NSLocalizedString("_lock_not_active_", comment: "") : NSLocalizedString("_lock_active_", comment: "") + NSLocalizedString("_extra_space_for_form_taps_", comment: ""))
                }
                .font(.system(size: 16))
                .onTapGesture {
                    model.isLockActive.toggle()
                }
                .sheet(isPresented: $model.isLockActive) {
                    PasscodeView(isPresented: $model.isLockActive, passcode: $model.passcode)
                }
                // Enable Touch ID
                Toggle(NSLocalizedString("_enable_touch_face_id_", comment: ""), isOn: $model.enableTouchID)
                    .font(.system(size: 16))
                    .onChange(of: model.enableTouchID) { _ in
                        model.updateTouchIDSetting()
                    }
                // Lock no screen
                Toggle(NSLocalizedString("_lock_protection_no_screen_", comment: ""), isOn: $model.lockScreen)
                    .font(.system(size: 16))
                    .onChange(of: model.lockScreen) { _ in
                        model.updateLockScreenSetting()
                    }
                // Privacy screen
                Toggle(NSLocalizedString("_privacy_screen_", comment: ""), isOn: $model.privacyScreen)
                    .font(.system(size: 16))
                    .onChange(of: model.privacyScreen) { _ in
                        model.updatePrivacyScreenSetting()
                    }
                // Reset app wrong attempts
                Toggle(NSLocalizedString("_reset_wrong_passcode_", comment: ""), isOn: $model.resetWrongAttempts)
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
                    HStack {
                        Image("caldavcardav")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("_mobile_config_", comment: ""))
                    }
                    .font(.system(size: 16))
                    .onTapGesture {
                        model.getConfigFiles()
                    }
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
                NavigationLink(destination: CCSettingsAdvanced(viewModel: CCSettingsAdvancedModel(), showExitAlert: false, showCacheAlert: false)) {
                    HStack {
                        Image("gear")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("_advanced_", comment: ""))
                    }
                    .font(.system(size: 16))
                }
            }
            /// `Information` Section
            Section(header: Text(NSLocalizedString("_information_", comment: "")), content: {
                // Acknowledgements
                HStack {
                    Image("acknowledgements")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("_acknowledgements_", comment: "") + NSLocalizedString("_extra_space_for_form_taps_", comment: ""))
                }
                .font(.system(size: 16))
                .onTapGesture {
                    showAcknowledgements = true
                }.sheet(isPresented: $showAcknowledgements) {
                    AcknowledgementsView(showText: $showAcknowledgements, browserTitle: "Acknowledgements")
                }
                // Terms & Privacy Conditions
                HStack {
                    Image("shield.checkerboard")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("_privacy_legal_", comment: "") + NSLocalizedString("_extra_space_for_form_taps_", comment: ""))
                }
                .font(.system(size: 16))
                .onTapGesture {
                    showBrowser = true
                }.sheet(isPresented: $showBrowser) {
                    NCBrowserWebView(isPresented: $showBrowser, urlBase: URL(string: NCBrandOptions.shared.privacy)!, browserTitle: "Privacy Policies")
                }
                // Source Code
                HStack {
                    Image("gitHub")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("_source_code_", comment: "") + NSLocalizedString("_extra_space_for_form_taps_", comment: ""))
                }
                .font(.system(size: 16))
                .onTapGesture {
                    showSourceCode = true
                }.sheet(isPresented: $showSourceCode) {
                    NCBrowserWebView(isPresented: $showSourceCode, urlBase: URL(string: NCBrandOptions.shared.sourceCode)!, browserTitle: "Source Code")
                }
            })
            /// `Watermark` Section
            Section(content: {
            }, footer: {
                Text("Nextcloud Liquid for iOS \(model.appVersion) © \(model.copyrightYear) \n\nNextcloud Server \(model.serverVersion)\n\(model.themingName) - \(model.themingSlogan)\n\n")

            })
        }.navigationBarTitle("Settings")
            .onAppear {
                model.onViewAppear()
            }
    }
}
 struct NCSettings_Previews: PreviewProvider {
     static var previews: some View {
         NCSettings(model: NCSettingsModel())
     }
 }

struct E2EESection: View {
    var body: some View {
        Section(header: Text(NSLocalizedString("_e2e_settings_title_", comment: "")), content: {
            NavigationLink(destination: NCViewE2EE(account: AppDelegate().account, rootViewController: nil)) {
                HStack {
                    Image("lock")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                    Text(NSLocalizedString("_e2e_settings_", comment: ""))
                }
                .font(.system(size: 16))
            }
        })
    }
}
