//
//  DataProtectionAgreementScreen.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 25.11.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

struct DataProtectionAgreementScreen: View {
    
    var body: some View {
        let titleFont = Font.system(size: 18.0, weight: .bold)
        let textFont = Font.system(size: 14.0)
        
        VStack (alignment: .leading) {
            HStack {
                Spacer()
                Image(.dataProtection)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                Spacer()
            }.padding([.top, .bottom], 32.0)
            
            Text(NSLocalizedString("_privacy_settings_", comment: ""))
                .font(titleFont)
                .foregroundStyle(.white)
                .padding(.bottom, 12.0)
            
            ScrollView {
                Text("_privacy_settings_description_")
                    .font(textFont)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.white)
            }.padding(.bottom, 24)
            
            Spacer()

            Button(NSLocalizedString("_settings_", comment: "")) {
                
            }
            .buttonStyle(ButtonStyleSecondary(maxWidth: .infinity))
            .padding(.bottom, 16.0)

            
            Button(NSLocalizedString("_agree_", comment: "")) {
                
            }
            .buttonStyle(ButtonStylePrimary(maxWidth: .infinity))
            .padding(.bottom, 10.0)
            
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

#Preview {
    DataProtectionAgreementScreen()
}
