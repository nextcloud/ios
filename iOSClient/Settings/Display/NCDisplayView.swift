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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Form {
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
                            Image(systemName: colorScheme == .light ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                                .imageScale(.large)
                                .font(Font.system(.body).weight(.light))
                                .frame(width: 50, height: 50)
                        }
                        .onTapGesture {
                            model.userInterfaceStyle(.light)
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
                            Image(systemName: colorScheme == .dark ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                                .imageScale(.large)
                                .font(Font.system(.body).weight(.light))
                                .frame(width: 50, height: 50)
                        }
                        .onTapGesture {
                            model.userInterfaceStyle(.dark)
                        }
                        Spacer()
                    }
                    Divider()
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: -50))

                    Toggle(NSLocalizedString("_use_system_style_", comment: ""), isOn: $model.appearanceAutomatic)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .onChange(of: model.appearanceAutomatic) { _ in
                            model.updateAppearanceAutomatic()
                        }
                }
            }
            .font(.system(size: 16))

            Section(header: Text(NSLocalizedString("_additional_options_", comment: ""))) {

                Picker(NSLocalizedString("_keep_screen_awake_", comment: ""),
                       selection: $model.screenAwakeState) {
                    Text(NSLocalizedString("_off_", comment: "")).tag(AwakeMode.off)
                    Text(NSLocalizedString("_on_", comment: "")).tag(AwakeMode.on)
                    Text(NSLocalizedString("_while_charging_", comment: "")).tag(AwakeMode.whileCharging)
                }
                       .frame(height: 50)
            }
            .pickerStyle(.menu)
        }
        .navigationBarTitle(NSLocalizedString("_display_", comment: ""))
        .defaultViewModifier(model)
        .padding(.top, 0)
    }
}

#Preview {
    NCDisplayView(model: NCDisplayModel(controller: nil))
}
