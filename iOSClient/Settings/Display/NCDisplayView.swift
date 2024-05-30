//
//  NCDisplayView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 30/05/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct NCDisplayView: View {
    @ObservedObject var model: NCDisplayModel

    var body: some View {
        Form {
            // Specify Filename
            Section(header: Text(NSLocalizedString("_appearance_", comment: ""))) {
                VStack {
                    HStack {
                        Spacer()
                        VStack {
                            Image(systemName: "sun.max")
                                .resizable()
                                .scaledToFit()
                                .font(Font.system(.body).weight(.light))
                                .frame(width: 50, height: 100)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            Text(NSLocalizedString("_light_", comment: ""))
                            Button(action: {
                                // Azione da eseguire quando il bottone viene premuto
                                print("Button pressed")
                            }) {
                                Image(systemName: "circle")
                                    .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                                    .imageScale(.large)
                                    .font(Font.system(.body).weight(.light))
                                    .frame(width: .infinity, height: 40)
                            }
                        }
                        Spacer()
                        VStack {
                            Image(systemName: "moon.fill")
                                .resizable()
                                .scaledToFit()
                                .font(Font.system(.body).weight(.light))
                                .frame(width: 50, height: 100)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            Text(NSLocalizedString("_dark_", comment: ""))
                            Button(action: {
                                // Azione da eseguire quando il bottone viene premuto
                                print("Button pressed")
                            }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(NCBrandColor.shared.brandElement))
                                    .imageScale(.large)
                                    .font(Font.system(.body).weight(.light))
                                    .frame(width: .infinity, height: 40)
                            }
                        }
                        Spacer()
                    }
                    Divider()
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: -50))

                    Toggle(NSLocalizedString("_automatic_", comment: ""), isOn: $model.appearanceAutomatic)
                        .tint(Color(NCBrandColor.shared.brandElement))
                        .onChange(of: model.appearanceAutomatic) { _ in
                            model.updateAppearanceAutomatic()
                        }
                }
            }
            .font(.system(size: 16))
        }
        .navigationBarTitle(NSLocalizedString("_display_", comment: ""))
        .defaultViewModifier(model)
        .padding(.top, 0)
    }
}

#Preview {
    NCDisplayView(model: NCDisplayModel(controller: nil))
}
