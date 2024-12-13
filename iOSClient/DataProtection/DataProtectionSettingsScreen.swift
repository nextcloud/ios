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
        if isIPad {
            iPadView()
        } else {
            iPhoneView()
        }
    }
    
    private func iPhoneView() -> some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading){
                    header()
                        .padding(EdgeInsets(top: 16.0,
                                            leading: 16.0,
                                            bottom: 32.0,
                                            trailing: 16.0))
                    
                    VStack{
                        divider()
                        
                        VStack(alignment: .leading) {
                            requiredDataCollectionToggle()
                            requiredDataCollectionFooter()
                        }
                        .padding(EdgeInsets(top: 12.0,
                                            leading: 16.0,
                                            bottom: 12.0,
                                            trailing: 16.0))
                        
                        divider()
                        
                        VStack(alignment: .leading) {
                            analysisOfDataCollectionToggle()
                            analysisOfDataCollectionFooter()
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
            saveSettingsButton()
        }
        .background(Color(.AppBackground.dataProtection))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(NSLocalizedString("_data_protection_", comment:""))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func iPadView() -> some View {
        VStack(alignment: .leading) {
            header()
                .padding(EdgeInsets(top: 10.0,
                                    leading: 16.0,
                                    bottom: 0.0,
                                    trailing: 16.0))
            
            Form {
                Section(content: {
                    requiredDataCollectionToggle()
                }, footer: {
                    requiredDataCollectionFooter()
                }).applyGlobalFormSectionStyle()
                
                Section(content: {
                    analysisOfDataCollectionToggle()
                }, footer: {
                    analysisOfDataCollectionFooter()
                }).applyGlobalFormSectionStyle()
            }
            .applyGlobalFormStyle()
            
            Spacer()
            
            HStack {
                Spacer()
                saveSettingsButton()
                Spacer()
            }
        }
        .background(Color(.AppBackground.dataProtection))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(NSLocalizedString("_data_protection_", comment:""))
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func divider() -> some View {
        Divider()
            .background(Color(.DataProtection.listSeparator))
            .frame(height: 1.0)
    }
    
    private func header() -> some View {
        let textFont = Font.system(size: 16.0)
        return Text("_data_usage_for_app_optimization_description_")
            .font(textFont)
            .multilineTextAlignment(.leading)
            .foregroundStyle(Color(.ListCell.title))
    }
    
    private func requiredDataCollectionToggle() -> some View {
        let listRowTitleFont = Font.system(size: 16.0, weight: .bold)
        return Toggle(NSLocalizedString("_required_data_collection_", comment: ""), isOn: $model.requiredDataCollection)
            .tint(Color(NCBrandColor.shared.switchColor))
            .font(listRowTitleFont)
            .foregroundStyle(Color(.ListCell.title))
            .disabled(true)
    }
    
    private func requiredDataCollectionFooter() -> some View {
        let listRowSubtitleFont = Font.system(size: 16.0)
        return Text("_required_data_collection_description_")
            .font(listRowSubtitleFont)
            .multilineTextAlignment(.leading)
            .foregroundStyle(Color(.DataProtection.listRowSubtitle))
    }
    
    private func analysisOfDataCollectionToggle() -> some View {
        let listRowTitleFont = Font.system(size: 16.0, weight: .bold)
        return Toggle(NSLocalizedString("_analysis_of_data_collection_", comment: ""), isOn: $model.analysisOfDataCollection)
            .tint(Color(NCBrandColor.shared.switchColor))
            .font(listRowTitleFont)
            .foregroundStyle(Color(.ListCell.title))
            .onChange(of: model.analysisOfDataCollection) { allowAnalysis in
                model.allowAnalysisOfDataCollection(allowAnalysis)
            }
            .alert(NSLocalizedString("_alert_tracking_access", comment: ""), isPresented: $model.redirectToSettings, actions: {
                Button(NSLocalizedString("_cancel_", comment: ""),
                       role: .none,
                       action: {
                    model.cancelOpenSettings()
                })
                Button(NSLocalizedString("_settings_", comment: ""),
                       role: .none,
                       action: {
                    model.openSettings()
                })
            })
    }
    
    private func analysisOfDataCollectionFooter() -> some View {
        let listRowSubtitleFont = Font.system(size: 16.0)
        return Text("_analysis_of_data_collection_description_")
            .font(listRowSubtitleFont)
            .multilineTextAlignment(.leading)
            .foregroundStyle(Color(.DataProtection.listRowSubtitle))
    }
    
    private func saveSettingsButton() -> some View {
        Button(NSLocalizedString("_save_settings_", comment: "")) {
            model.saveSettings()
        }
        .buttonStyle(ButtonStylePrimary(maxWidth: 288.0))
        .padding(16.0)
        .hiddenConditionally(isHidden: model.isShownFromSettings)
    }
}

#Preview {
    DataProtectionSettingsScreen(model: DataProtectionModel())
}
