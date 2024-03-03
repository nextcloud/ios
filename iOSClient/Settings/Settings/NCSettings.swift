//
//  NCSettings.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 03/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

    /// Other temperory states/ will go inside viewModel
    @State var passcode: String?
    @State var enableTouchID: Bool
    @State var lockScreen: Bool
    @State var privacyScreen: Bool
    @State var resetWrongAttempts: Bool
    
    @State var isE2EEEnable: Bool = NCGlobal.shared.capabilityE2EEEnabled
    @State var versionE2EE: String = NCGlobal.shared.capabilityE2EEApiVersion
    
    var body: some View {
        Form {
            /// `Auto Upload` Section
            Section {
                NavigationLink(destination: EmptyView()) {
                    HStack {
                        Image("autoUpload")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                        Text(NSLocalizedString("_settings_autoupload_", comment: ""))
                    }
                }
            }
            
            /// `Privacy` Section
            Section(header: Text(NSLocalizedString("_privacy_", comment: "")), content: {
                
                // Lock active YES/NO
                HStack {
                    Image("lock_closed")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                    Text(NSLocalizedString("_lock_active_", comment: ""))
                }.onTapGesture {
                    
                }
                
                // Enable Touch ID
                Toggle(NSLocalizedString("_enable_touch_face_id_", comment: ""), isOn: $enableTouchID)
                    .onChange(of: enableTouchID) { _ in
                        
                    }
                
                // Lock no screen
                Toggle(NSLocalizedString("_lock_protection_no_screen_", comment: ""), isOn: $lockScreen)
                    .onChange(of: lockScreen) { _ in
                        
                    }
                
                // Privacy screen
                Toggle(NSLocalizedString("_privacy_screen_", comment: ""), isOn: $privacyScreen)
                    .onChange(of: privacyScreen) { _ in
                        
                    }
                
                // Reset app wrong attempts
                Toggle(NSLocalizedString("_reset_wrong_passcode_", comment: ""), isOn: $resetWrongAttempts)
                    .onChange(of: resetWrongAttempts) { _ in
                        
                    }
            })
            
            // Calender & Contacts
            if !NCBrandOptions.shared.disable_mobileconfig {
                Section(content: {
                    HStack {
                        Image("caldavcardav")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                        Text(NSLocalizedString("_mobile_config_", comment: ""))
                    }.onTapGesture {
                        
                    }
                }, header:{
                    Text(NSLocalizedString("_calendar_contacts_", comment: ""))
                }, footer: {
                    Text(NSLocalizedString("_mobile_config_", comment: ""))
                })
            }
            
            /// `E2EEncryption` Section
            if isE2EEEnable && NCGlobal.shared.e2eeVersions.contains(versionE2EE) {
                Section(header: Text(NSLocalizedString("_e2e_settings_title_", comment: "")), content: {
                    HStack {
                        Image("lock")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                        Text(NSLocalizedString("_e2e_settings_", comment: ""))
                    }.onTapGesture {
                        // Handle tap gesture
                    }
                })
            }
            
            /// `Advanced` Section
            Section {
                NavigationLink(destination: EmptyView()) {
                    HStack {
                        Image("gear")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                        Text(NSLocalizedString("_advanced_", comment: ""))
                    }
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
                    Text(NSLocalizedString("_acknowledgements_", comment: ""))
                }.onTapGesture {
                    showAcknowledgements = true
                }.sheet(isPresented: $showAcknowledgements) {
                    
                }
                
                // Terms & Privacy Conditions
                HStack {
                    Image("shield.checkerboard")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                    Text(NSLocalizedString("_privacy_legal_", comment: ""))
                }.onTapGesture {
                    showBrowser = true
                }.sheet(isPresented: $showBrowser) {
                    
                }
                
                // Source Code
                HStack {
                    Image("gitHub")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                    Text(NSLocalizedString("_source_code_", comment: ""))
                }.onTapGesture {
                    showSourceCode = true
                }.sheet(isPresented: $showSourceCode) {
                    
                }
            })
            
            
            /// `Watermark` Section
            Section(content: {
                
            }, footer: {
                Text("Nextcloud Liquid for iOS \(NCUtility().getVersionApp(withBuild: true)) © 2024 \n\nNextcloud Server \(NCGlobal.shared.capabilityServerVersion)\n\(NCGlobal.shared.capabilityThemingName) - \(NCGlobal.shared.capabilityThemingSlogan)")
                Text("Nextcloud Server \(NCGlobal.shared.capabilityServerVersion)")
                Text("\(NCGlobal.shared.capabilityThemingName) - \(NCGlobal.shared.capabilityThemingSlogan)")
            })
        }
        .navigationBarTitle("Settings")
    }
}

/*
 struct NCSettings_Previews: PreviewProvider {
     static var previews: some View {
         NCSettings()
     }
 }
 */
