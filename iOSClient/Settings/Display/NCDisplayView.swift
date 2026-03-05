// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCDisplayView: View {
    @ObservedObject var model: NCDisplayModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("_appearance_", comment: "")).font(.headline())) {
                VStack {
                    HStack {
                        Spacer()
                        VStack {
                            Image(systemName: "sun.max")
                                .resizable()
                                .scaledToFit()
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                                .frame(width: 50, height: 100)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            Text(NSLocalizedString("_light_", comment: ""))
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                            Image(systemName: colorScheme == .light ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                                .imageScale(.large)
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                                .fontWeight(.light)
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
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                                .frame(width: 50, height: 100)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            Text(NSLocalizedString("_dark_", comment: ""))
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                            Image(systemName: colorScheme == .dark ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                                .imageScale(.large)
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                                .fontWeight(.light)
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
                        .cappedFont(.body, maxDynamicType: .accessibility2)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .onChange(of: model.appearanceAutomatic) {
                            model.updateAppearanceAutomatic()
                        }
                }
            }

            Section(
                header: Text(NSLocalizedString("_additional_options_", comment: ""))
                    .font(.headline())
            ) {
                HStack {
                    Text(NSLocalizedString("_keep_screen_awake_", comment: ""))
                        .cappedFont(.body, maxDynamicType: .accessibility2)

                    Spacer()

                    Picker("", selection: $model.screenAwakeState) {
                        Text(NSLocalizedString("_off_", comment: "")).tag(AwakeMode.off)
                        Text(NSLocalizedString("_on_", comment: "")).tag(AwakeMode.on)
                        Text(NSLocalizedString("_while_charging_", comment: "")).tag(AwakeMode.whileCharging)
                    }
                    .pickerStyle(.menu)
                }
                .font(.callout())
            }
        }
        .id(dynamicTypeSize)
        .navigationBarTitle(NSLocalizedString("_display_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .defaultViewModifier(model)
        .padding(.top, 0)
    }
}

#Preview {
    NCDisplayView(model: NCDisplayModel(controller: nil))
}
