//
//  NCSettingsView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 03/03/24.
//  Created by Marino Faggiana on 30/05/24.
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
struct NCSettingsView: View {
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
            Section(content: {
                NavigationLink(destination: LazyView {
                    NCAutoUploadView(model: NCAutoUploadModel(viewController: model.controller?.currentViewController()))
                }) {
                    HStack {
						Image(.Settings.camera)
                            .resizable()
                            .scaledToFit()
							.font(.settingsIconsFont)
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        Text(NSLocalizedString("_settings_autoupload_", comment: ""))
                    }
                    .font(.system(size: 16))
                }
            })
            /// `Privacy` Section
            Section(content: {
                Button(action: {
                    showPasscode.toggle()
                }, label: {
                    HStack {
						lockImage(isLocked: model.isLockActive)
                            .resizable()
                            .scaledToFit()
							.font(.settingsIconsFont)
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
                /// Enable Touch ID
                Toggle(NSLocalizedString("_enable_touch_face_id_", comment: ""), isOn: $model.enableTouchID)
                    .tint(Color(NCBrandColor.shared.brandElement))
                    .font(.system(size: 16))
                    .onChange(of: model.enableTouchID) { _ in
                        model.updateTouchIDSetting()
                    }
                /// Reset app wrong attempts
                Toggle(NSLocalizedString("_reset_wrong_passcode_", comment: ""), isOn: $model.resetWrongAttempts)
                    .tint(Color(NCBrandColor.shared.brandElement))
                    .font(.system(size: 16))
                    .onChange(of: model.resetWrongAttempts) { _ in
                        model.updateResetWrongAttemptsSetting()
                    }
            }, header: {
                Text(NSLocalizedString("_privacy_", comment: ""))
            }, footer: {
                Text(String(format: NSLocalizedString("_reset_wrong_passcode_desc_", comment: ""), NCBrandOptions.shared.resetAppPasscodeAttempts))
                    .font(.system(size: 12))
                    .lineSpacing(1)
            })
            /// Calender & Contacts
            if !NCBrandOptions.shared.disable_mobileconfig {
                Section(content: {
                    Button(action: {
                        model.getConfigFiles()
                    }, label: {
                        HStack {
							Image(.Settings.calendarUser)
                                .resizable()
								.renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 23, height: 20)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            Text(NSLocalizedString("_mobile_config_", comment: ""))
                        }
                        .font(.system(size: 16))
                    })
                    .tint(Color(NCBrandColor.shared.textColor))
                }, header: {
                    Text(NSLocalizedString("_calendar_contacts_", comment: ""))
                }, footer: {
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("_calendar_contacts_footer_warning_", comment: ""))
                            .font(.system(size: 12))
                        Spacer()
                        Text(NSLocalizedString("_calendar_contacts_footer_", comment: ""))
                            .font(.system(size: 12))
                    }

                })
            }
            /// `Advanced` Section
            Section {
                NavigationLink(destination: LazyView {
                    NCSettingsAdvancedView(model: NCSettingsAdvancedModel(viewController: model.controller?.currentViewController()),
                                           showExitAlert: false,
                                           showCacheAlert: false)
                }) {
                    HStack {
						Image(.Settings.gear)
                            .resizable()
							.renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
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
						Image(.Settings.handshake)
                            .resizable()
                            .renderingMode(.template)
							.scaledToFit()
                            .frame(width: 25, height: 20)
							.foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        Text(NSLocalizedString("_acknowledgements_", comment: ""))
                    }
                    .font(.system(size: 16))
                })
                .tint(Color(NCBrandColor.shared.textColor))
                .sheet(isPresented: $showAcknowledgements) {
                    NCAcknowledgementsView(browserTitle: NSLocalizedString("_acknowledgements_", comment: ""))
                }
                /// Terms & Privacy Conditions
                Button(action: {
                    showBrowser.toggle()
                }, label: {
                    HStack {
						Image(.Settings.shieldHalved)
                            .resizable()
							.renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        Text(NSLocalizedString("_privacy_legal_", comment: ""))
                    }
                    .font(.system(size: 16))
                })
                .tint(Color(NCBrandColor.shared.textColor))
                .sheet(isPresented: $showBrowser) {
                    NCBrowserWebView(urlBase: URL(string: NCBrandOptions.shared.privacy)!, browserTitle: NSLocalizedString("_privacy_legal_", comment: ""))
                }
                /// Source Code
                Button(action: {
                    showSourceCode.toggle()
                }, label: {
                    HStack {
						Image(.Settings.github)
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
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
                Text(model.footerApp + model.footerServer + model.footerSlogan)
            })
        }
        .navigationBarTitle(NSLocalizedString("_settings_", comment: ""))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    model.dismiss()
                }, label: {
                    Text(NSLocalizedString("_close_", comment: ""))
                        .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                })
            }
        }
        .applyGlobalFormStyle()
        .defaultViewModifier(model)
    }
	
	private func lockImage(isLocked: Bool) -> Image {
		isLocked ? Image(.itemLock) : Image(.itemLockOpen)
	}
}

struct E2EESection: View {
    @ObservedObject var model: NCSettingsModel

    var body: some View {
        Section(header: Text(NSLocalizedString("_e2e_settings_title_", comment: "")), content: {
            NavigationLink(destination: LazyView {
                NCManageE2EEView(model: NCManageE2EE(viewController: model.controller?.currentViewController()))
            }) {
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

extension Font {
	static var settingsIconsFont: Font {
		return Font(UIFont.settingsIconsFont)
	}
}

#Preview {
    NCSettingsView(model: NCSettingsModel(controller: nil))
}
