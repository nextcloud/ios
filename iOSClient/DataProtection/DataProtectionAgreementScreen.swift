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
    
    var body: some View {
        let titleFont = Font.system(size: isIPad ? 36.0 : 18.0, weight: .bold)
        let textFont = Font.system(size: isIPad ? 18.0 : 14.0)
        let textBoxRatio = isIPad ? 0.6 : 0.9
        
        GeometryReader { geometry in
            let size = geometry.size
            
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
                        Text("Diese Anwendung verwendet Cookies und ähnliche Technologien. Durch Klicken auf Zustimmen akzeptieren Sie die Verarbeitung und auch die Weitergabe Ihrer Daten an Dritte. Weitere Informationen, auch zur Datenverarbeitung durch Drittanbieter, finden Sie in den Einstellungen und in unserer [Datenschutzhinweise](https://google.com).Sie können die Nutzung der Tools [Ablehnen](https://google.com) oder Ihre Auswahl jederzeit über Ihre Einstellungenanpassen")
                            .font(textFont)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, 24)
                }
                .frame(width: size.width * textBoxRatio)
            
                
                Button(NSLocalizedString("_settings_", comment: "")) {
                    
                }
                .buttonStyle(ButtonStyleSecondary(maxWidth: 288.0))
                
                Button(NSLocalizedString("_agree_", comment: "")) {
                    
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
    }
}

#Preview {
    DataProtectionAgreementScreen()
}
