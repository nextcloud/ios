//
//  DataProtectionSettingsScreen.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 25.11.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

struct DataProtectionSettingsScreen: View {
    
    @ObservedObject var model: DataProtectionModel
    
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        let titleFont = Font.system(size: isIPad ? 24.0 : 16.0, weight: .bold)
        let textFont = Font.system(size: isIPad ? 18.0 : 16.0)
        let listRowTitleFont = Font.system(size: 16.0, weight: .bold)
        let listRowSubtitleFont = Font.system(size: 16.0)
        
        VStack {
            ScrollView {
                VStack(alignment: .leading){
                    Text(NSLocalizedString("_data_usage_for_app_optimization_", comment: ""))
                        .font(titleFont)
                        .foregroundStyle(Color(.ListCell.title))
                        .padding(EdgeInsets(top: 32.0,
                                            leading: 16.0,
                                            bottom: 0.0,
                                            trailing: 16.0))
                    
                    Text("_data_usage_for_app_optimization_description_")
                        .font(textFont)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(Color(.ListCell.title))
                        .padding(EdgeInsets(top: 0.0,
                                            leading: 16.0,
                                            bottom: 32.0,
                                            trailing: 16.0))
                    
                    VStack{
                        divider()
                        
                        VStack(alignment: .leading) {
                            Toggle(NSLocalizedString("_required_data_collection_", comment: ""), isOn: $model.requiredDataCollection)
                                .tint(Color(NCBrandColor.shared.switchColor))
                                .font(listRowTitleFont)
                                .foregroundStyle(Color(.ListCell.title))
                            Text("_required_data_collection_description_")
                                .font(listRowSubtitleFont)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(Color(.DataProtection.listRowSubtitle))
                        }
                        .padding(EdgeInsets(top: 12.0,
                                            leading: 16.0,
                                            bottom: 12.0,
                                            trailing: 16.0))
                        
                        divider()
                           
                        VStack(alignment: .leading) {
                            Toggle(NSLocalizedString("_analysis_of_data_collection_", comment: ""), isOn: $model.analysisOfDataCollection)
                                .tint(Color(NCBrandColor.shared.switchColor))
                                .font(listRowTitleFont)
                                .foregroundStyle(Color(.ListCell.title))
                            Text("_analysis_of_data_collection_description_")
                                .font(listRowSubtitleFont)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(Color(.DataProtection.listRowSubtitle))
                        }
                        .padding(EdgeInsets(top: 12.0,
                                            leading: 16.0,
                                            bottom: 12.0,
                                            trailing: 16.0))
                        
                        divider()
                    }
                    .background(Color(.DataProtection.listRow))
                }
            }
            .background(Color(.AppBackground.dataProtection))
            
            Spacer()
            
            Button(NSLocalizedString("_save_settings_", comment: "")) {
                DataProtectionAgreementManager.shared?.dismissView()
            }
            .buttonStyle(ButtonStylePrimary(maxWidth: 288.0))
            .padding(16.0)
            .hiddenConditionally(isHidden: model.isShownFromSettings)
        }
        .background(Color(.AppBackground.dataProtection))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(NSLocalizedString("_data_protection_", comment:""))
        .navigationBarTitleDisplayMode(isIPad ? .large : .inline)
    }
    
    private func divider() -> some View {
        Divider()
            .background(Color(.DataProtection.listSeparator))
            .frame(height: 1.0)
    }
}

#Preview {
    DataProtectionSettingsScreen(model: DataProtectionModel())
}
