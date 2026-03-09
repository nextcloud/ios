// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct NCAccountSettingsView: View {
    @ObservedObject var model: NCAccountSettingsModel

    @State private var isExpanded: Bool = false
    @State private var showServerCertificate = false
    @State private var showPushCertificate = false
    @State private var showDeleteAccountAlert: Bool = false
    @State private var showAddAccount: Bool = false
    @State private var animation: Bool = false

    var capabilities: NKCapabilities.Capabilities {
        NCNetworking.shared.capabilities[model.controller?.account ?? ""] ?? NKCapabilities.Capabilities()
    }

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(content: {
                    TabView(selection: $model.indexActiveAccount) {
                        ForEach(0..<model.tblAccounts.count, id: \.self) { index in
                            let status = model.getUserStatus()
                            let avatar = NCUtility().loadUserImage(for: model.tblAccounts[index].user, displayName: model.tblAccounts[index].displayName, urlBase: model.tblAccounts[index].urlBase)

                            //
                            // User
                            VStack {
                                Image(uiImage: avatar)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width, height: 65)
                                if let statusImage = status.statusImage {
                                    ZStack {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 30, height: 30)
                                        Image(uiImage: statusImage)
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 30, height: 30)
                                            .foregroundStyle(Color(uiColor: status.statusImageColor))
                                    }
                                    .offset(x: 30, y: -30)
                                }
                                Text(model.getUserName())
                                    .cappedFont(.subheadline, maxDynamicType: .xxxLarge)
                                    .font(.subheadline)
                                Spacer()
                                    .frame(height: 10)
                                Text(status.statusMessage)
                                    .cappedFont(.caption, maxDynamicType: .xxxLarge)
                                Spacer()
                                    .frame(height: 20)
                                //
                                // Personal data
                                if let tblAccount = model.tblAccount {
                                    if !tblAccount.email.isEmpty {
                                        HStack {
                                            Image(systemName: "mail")
                                                .font(.icon())
                                            Text(tblAccount.email)
                                                .cappedFont(.body, maxDynamicType: .xxxLarge)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                        }
                                        .frame(maxWidth: .infinity, maxHeight: 30)
                                    }
                                    if !tblAccount.phone.isEmpty {
                                        HStack {
                                            Image(systemName: "phone")
                                                .font(.icon())
                                            Text(tblAccount.phone)
                                                .cappedFont(.body, maxDynamicType: .xxxLarge)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: 30)
                                    }
                                    if !tblAccount.address.isEmpty {
                                        HStack {
                                            Image(systemName: "house")
                                                .font(.icon())
                                            Text(tblAccount.address)
                                                .cappedFont(.body, maxDynamicType: .xxxLarge)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: 30)
                                    }
                                }
                            }
                        }
                    }
                    .cappedFont(.subheadline, maxDynamicType: .accessibility1)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: model.getTableViewHeight())
                    .animation(.easeIn(duration: 0.3), value: animation)
                    .onChange(of: model.indexActiveAccount) { _, index in
                        animation.toggle()
                        model.setAccount(account: model.tblAccounts[index].account)
                    }
                    //
                    // Change alias
                    VStack {
                        HStack {
                            Text(NSLocalizedString("_alias_", comment: "") + ":")
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                            Spacer()
                            TextField(NSLocalizedString("_alias_placeholder_", comment: ""), text: $model.alias)
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: model.alias) { _, newValue in
                                    model.setAlias(newValue)
                                }
                        }
                        Text(NSLocalizedString("_alias_footer_", comment: ""))
                            .font(.footnote)
                            .foregroundStyle(Color(UIColor.lightGray))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    //
                    // User Status
                    if capabilities.userStatusEnabled {
                        if let account = model.tblAccount?.account {
                            NavigationLink(destination: NCUserStatusView(account: account, controller: model.controller)) {
                                HStack {
                                    Image(systemName: "moon.fill")
                                        .font(.icon())
                                        .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                                        .frame(width: 26)
                                    Text(NSLocalizedString("_set_user_status_", comment: ""))
                                        .cappedFont(.body, maxDynamicType: .accessibility2)
                                        .foregroundStyle(Color(NCBrandColor.shared.textColor))
                                }
                            }
                        }

                        if let account = model.tblAccount?.account {
                            NavigationLink(destination: NCStatusMessageView(account: account, controller: model.controller)) {
                                HStack {
                                    Image(systemName: "message.fill")
                                        .font(.icon())
                                        .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                                        .frame(width: 26)
                                    Text(NSLocalizedString("_set_user_status_message_", comment: ""))
                                        .cappedFont(.body, maxDynamicType: .accessibility2)
                                        .foregroundStyle(Color(NCBrandColor.shared.textColor))
                                }
                            }
                        }
                    }

                    //
                    // Certificate server
                    if model.isAdminGroup() {
                        Button(action: {
                            showServerCertificate.toggle()
                        }, label: {
                            HStack {
                                Image(systemName: "network.badge.shield.half.filled")
                                    .font(.icon())
                                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                                    .frame(width: 26)
                                Text(NSLocalizedString("_certificate_details_", comment: ""))
                                    .cappedFont(.body, maxDynamicType: .accessibility2)
                                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                            }
                            .font(.subheadline)
                        })
                        .sheet(isPresented: $showServerCertificate) {
                            if let url = URL(string: model.tblAccount?.urlBase), let host = url.host {
                                certificateDetailsView(privateKeyString: "", host: host, title: NSLocalizedString("_certificate_view_", comment: ""))
                            }
                        }
                        //
                        // Certificate push
                        Button(action: {
                            showPushCertificate.toggle()
                        }, label: {
                            HStack {
                                Image(systemName: "network.badge.shield.half.filled")
                                    .font(.icon())
                                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                                    .frame(width: 26)
                                Text(NSLocalizedString("_certificate_pn_details_", comment: ""))
                                    .cappedFont(.body, maxDynamicType: .accessibility2)
                                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                            }
                            .font(.subheadline)
                        })
                        .sheet(isPresented: $showPushCertificate) {
                            Group {
                                if let url = URL(string: NCBrandOptions.shared.pushNotificationServerProxy),
                                    let host = url.host {
                                    let privateKeyString: String = {
                                        if let account = model.tblAccount?.account,
                                           let privateKey = NCPreferences().getPushNotificationPrivateKey(account: account) {
                                                let prefixData = Data(privateKey.prefix(8))
                                                return prefixData.base64EncodedString()
                                            } else {
                                                return ""
                                            }
                                        }()
                                    certificateDetailsView(privateKeyString: privateKeyString, host: host, title: NSLocalizedString("_certificate_pn_view_", comment: ""))
                                }
                            }
                        }
                    }
                })
                //
                // Delete account
                Section(content: {
                    Button(action: {
                        showDeleteAccountAlert.toggle()
                    }, label: {
                        HStack {
                            Image(systemName: "trash")
                                .font(.icon())
                                .foregroundStyle(.red)
                                .frame(width: 26)
                            Text(NSLocalizedString("_remove_local_account_", comment: ""))
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                                .foregroundStyle(.red)
                        }
                        .font(.callout)
                    })
                    .alert(NSLocalizedString("_want_delete_account_", comment: ""), isPresented: $showDeleteAccountAlert) {
                        Button(NSLocalizedString("_remove_local_account_", comment: ""), role: .destructive) {
                            model.deleteAccount()
                        }
                        Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) { }
                    }
                })
            }
            .navigationBarTitle(NSLocalizedString("_account_settings_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
            })
        }
        .defaultViewModifier(model)
        .navigationViewStyle(StackNavigationViewStyle())
        .onReceive(model.$dismissView) { newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onDisappear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                model.delegate?.accountSettingsDidDismiss(tblAccount: model.tblAccount, controller: model.controller)
            }
        }
    }
}

#Preview {
    NCAccountSettingsView(model: NCAccountSettingsModel(controller: nil, delegate: nil))
}
