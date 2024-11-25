//
//  DataProtectionSettingsScreen.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 25.11.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

struct DataProtectionSettingsScreen: View {
    
    @ObservedObject var model = DataProtectionModel()
    
    var body: some View {
        VStack {
            List {
                let titleFont = Font.system(size: 16.0, weight: .bold)
                let textFont = Font.system(size: 16.0)
                Section {
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("_data_usage_for_app_optimization_", comment: ""))
                            .font(titleFont)
                            .foregroundStyle(.white)
                            .padding(.bottom, 12.0)
                        
                        Text("_data_usage_for_app_optimization_description_")
                            .font(textFont)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.white)
                    }
                }.listRowSeparatorTint(Color(NCBrandColor.shared.formSeparatorColor))
                    .listRowBackground(Color(.AppBackground.form))

                Section {
                    VStack(alignment: .leading) {
                        Toggle(NSLocalizedString("_required_data_collection_", comment: ""), isOn: $model.requiredDataCollection)
                            .tint(Color(NCBrandColor.shared.switchColor))
                            .font(titleFont)
                        Text("_required_data_collection_description_")
                            .font(textFont)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(Color(.ListCell.subtitle))
                    }
                }.listRowSeparatorTint(Color(NCBrandColor.shared.formSeparatorColor))
                    .listRowBackground(Color(.AppBackground.form))
                Section {
                    VStack(alignment: .leading) {
                        Toggle(NSLocalizedString("_analysis_of_data_collection_", comment: ""), isOn: $model.analysisOfDataCollection)
                            .tint(Color(NCBrandColor.shared.switchColor))
                            .font(titleFont)
                        Text("_analysis_of_data_collection_description_")
                            .font(textFont)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(Color(.ListCell.subtitle))
                    }
                }.listRowSeparatorTint(Color(NCBrandColor.shared.formSeparatorColor))
                    .listRowBackground(Color(.AppBackground.form))
            }
            .environment(\.colorScheme, .dark)
            .background(Color(.AppBackground.form))
            .listStyle(.plain)
            
            Spacer()
            
            Button(NSLocalizedString("_save_settings_", comment: "")) {
                
            }
            .buttonStyle(ButtonStylePrimary(maxWidth: .infinity))
            .padding(16.0)
        }
        .background(Color(.AppBackground.form))
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DataProtectionSettingsScreen()
}
