//
//  DataProtectionAgreementScreen.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 25.11.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

struct DataProtectionAgreementScreen: View {
    
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    @State private var isShowingSettingsView = false
    
    var body: some View {
        let titleFont = Font.system(size: isIPad ? 36.0 : 18.0, weight: .bold)
        let textFont = Font.system(size: isIPad ? 18.0 : 14.0)
        let textBoxRatio = isIPad ? 0.6 : 0.9
        GeometryReader { geometry in
            let size = geometry.size
            
            NavigationView {
                VStack(alignment: .center, spacing: 16.0) {
                    HStack {
                        Spacer()
                        Image(.dataProtection)
                            .resizable()
                            .scaledToFit()
                            .frame(height: isIPad ? 128: 64)
                        Spacer()
                    }.padding([.top, .bottom], isIPad ? 94.0 :  32.0)
                    
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("_privacy_settings_", comment: ""))
                            .font(titleFont)
                            .foregroundStyle(.white)
                            .padding(.bottom, 12.0)
                        
                        ScrollView {
                            Text(.init(NSLocalizedString("_privacy_settings_description_", comment: "")))
                                .font(textFont)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.white)
                                .accentColor(Color(.DataProtection.link))
                                .environment(\.openURL, OpenURLAction { url in
                                    if url.absoluteString == "link://privacypolicy" {
                                        UIApplication.shared.open(URL(string:"https://google.com")!)
                                    }
                                    else if url.absoluteString == "link://reject" {
                                        DataProtectionAgreementManager.shared?.dismissView()
                                    }
                                    return .discarded
                                })
                        }
                        .padding(.bottom, 24)
                    }
                    .frame(width: size.width * textBoxRatio)
                    
                    NavigationLink(destination: DataProtectionSettingsScreen(), isActive: $isShowingSettingsView) { EmptyView() }
                        .navigationTitle("")

                    Button(NSLocalizedString("_settings_", comment: "")) {
                        isShowingSettingsView = true
                    }
                    .buttonStyle(ButtonStyleSecondary(maxWidth: 288.0))
                    
                    Button(NSLocalizedString("_agree_", comment: "")) {
                        DataProtectionAgreementManager.shared?.dismissView()
                    }
                    .buttonStyle(ButtonStylePrimary(maxWidth: 288.0))
                }
                .environment(\.colorScheme, .dark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16.0)
                .background {
                    Image(.gradientBackground)
                        .resizable()
                        .ignoresSafeArea()
                }
            }
            .accentColor(Color(.DataProtection.navigationBarTint))
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

#Preview {
    DataProtectionAgreementScreen()
}
