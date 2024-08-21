//
//  NCAccountSettingsView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import SwiftUI

struct NCAccountSettingsView: View {
    @ObservedObject var model: NCAccountSettingsModel

    @State private var isExpanded: Bool = false
    @State private var showUserStatus = false
    @State private var showServerCertificate = false
    @State private var showPushCertificate = false
    @State private var showDeleteAccountAlert: Bool = false
    @State private var showAddAccount: Bool = false
    @State private var animation: Bool = false

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(content: {
                    TabView(selection: $model.indexActiveAccount) {
                        ForEach(0..<model.tblAccounts.count, id: \.self) { index in
                            let status = model.getUserStatus()
                            let avatar = NCUtility().loadUserImage(for: model.tblAccounts[index].user, displayName: model.tblAccounts[index].displayName, urlBase: model.tblAccounts[index].urlBase)
                            ///
                            /// User
                            VStack {
                                ZStack {
                                    Image(uiImage: avatar)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: UIScreen.main.bounds.width, height: 75)
                                    if let statusImage = status.statusImage {
                                        ZStack {
                                            Circle()
                                                .fill(.white)
                                                .frame(width: 30, height: 30)
                                            Image(uiImage: statusImage)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 30, height: 30)
                                        }
                                        .offset(x: 30, y: 30)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                Text(model.getUserName())
                                    .font(.system(size: 16))
                                Spacer()
                                    .frame(height: 10)
                                Text(status.statusMessage)
                                    .font(.system(size: 10))
                                Spacer()
                                    .frame(height: 20)
                                ///
                                /// Personal data
                                if let tblAccount = model.tblAccount {
                                    if !tblAccount.email.isEmpty {
                                        HStack {
                                            Image(systemName: "mail")
                                                .resizable()
                                                .scaledToFit()
                                                .font(Font.system(.body).weight(.light))
                                                .frame(width: 20, height: 20)
                                            Text(tblAccount.email)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                        }
                                        .frame(maxWidth: .infinity, maxHeight: 30)
                                    }
                                    if !tblAccount.phone.isEmpty {
                                        HStack {
                                            Image(systemName: "phone")
                                                .resizable()
                                                .scaledToFit()
                                                .font(Font.system(.body).weight(.light))
                                                .frame(width: 20, height: 20)
                                            Text(tblAccount.phone)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: 30)
                                    }
                                    if !tblAccount.address.isEmpty {
                                        HStack {
                                            Image(systemName: "house")
                                                .resizable()
                                                .scaledToFit()
                                                .font(Font.system(.body).weight(.light))
                                                .frame(width: 20, height: 20)
                                            Text(tblAccount.address)
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
                    .font(.system(size: 14))
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: model.getTableViewHeight())
                    .animation(.easeIn(duration: 0.3), value: animation)
                    .onChange(of: model.indexActiveAccount) { index in
                        animation.toggle()
                        model.setAccount(account: model.tblAccounts[index].account)
                    }
                    ///
                    /// Change alias
                    VStack {
                        HStack {
                            Text(NSLocalizedString("_alias_", comment: "") + ":")
                                .font(.system(size: 17))
                                .fontWeight(.medium)
                            Spacer()
                            TextField(NSLocalizedString("_alias_placeholder_", comment: ""), text: $model.alias)
                                .font(.system(size: 16))
                                .multilineTextAlignment(.trailing)
                                .onChange(of: model.alias) { newValue in
                                    model.setAlias(newValue)
                                }
                        }
                        Text(NSLocalizedString("_alias_footer_", comment: ""))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.system(size: 12))
                            .lineLimit(2)
                            .foregroundStyle(Color(UIColor.lightGray))
                    }
                    ///
                    /// User Status
                    if NCCapabilities.shared.getCapabilities(account: model.tblAccount?.account).capabilityUserStatusEnabled {
                        Button(action: {
                            showUserStatus = true
                        }, label: {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .font(Font.system(.body).weight(.light))
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                                Text(NSLocalizedString("_set_user_status_", comment: ""))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                            }
                            .font(.system(size: 14))
                        })
                        .sheet(isPresented: $showUserStatus) {
                            if let account = model.tblAccount?.account {
                                UserStatusView(showUserStatus: $showUserStatus, account: account)
                            }
                        }
                        .onChange(of: showUserStatus) { _ in }
                    }
                    ///
                    /// Certificate server
                    if model.isAdminGroup() {
                        Button(action: {
                            showServerCertificate.toggle()
                        }, label: {
                            HStack {
                                Image(systemName: "lock")
                                    .resizable()
                                    .scaledToFit()
                                    .font(Font.system(.body).weight(.light))
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                                Text(NSLocalizedString("_certificate_details_", comment: ""))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                            }
                            .font(.system(size: 14))
                        })
                        .sheet(isPresented: $showServerCertificate) {
                            if let url = URL(string: model.tblAccount?.urlBase), let host = url.host {
                                certificateDetailsView(host: host, title: NSLocalizedString("_certificate_view_", comment: ""))
                            }
                        }
                        ///
                        /// Certificate push
                        Button(action: {
                            showPushCertificate.toggle()
                        }, label: {
                            HStack {
                                Image(systemName: "lock")
                                    .resizable()
                                    .scaledToFit()
                                    .font(Font.system(.body).weight(.light))
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                                Text(NSLocalizedString("_certificate_pn_details_", comment: ""))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                            }
                            .font(.system(size: 14))
                        })
                        .sheet(isPresented: $showPushCertificate) {
                            if let url = URL(string: NCBrandOptions.shared.pushNotificationServerProxy), let host = url.host {
                                certificateDetailsView(host: host, title: NSLocalizedString("_certificate_pn_view_", comment: ""))
                            }
                        }
                    }
                })
                ///
                /// Delete account
                Section(content: {
                    Button(action: {
                        showDeleteAccountAlert.toggle()
                    }, label: {
                        HStack {
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .font(Font.system(.body).weight(.light))
                                .frame(width: 20, height: 20)
                                .foregroundStyle(.red)
                            Text(NSLocalizedString("_remove_local_account_", comment: ""))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.red)
                                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                        }
                        .font(.system(size: 14))
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
                    .font(Font.system(.body).weight(.light))
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
            model.delegate?.accountSettingsDidDismiss(tableAccount: model.tblAccount, controller: model.controller)
        }
    }
}

#Preview {
    NCAccountSettingsView(model: NCAccountSettingsModel(controller: nil, delegate: nil))
}
