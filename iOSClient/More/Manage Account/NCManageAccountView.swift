//
//  NCManageAccountView.swift
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

struct NCManageAccountView: View {
    @ObservedObject var model: NCManageAccountModel
    @State private var showUserStatus = false
    @State private var showServerCertificate = false
    @State private var showPushCertificate = false
    @State private var showDeleteAccountAlert: Bool = false
    @State private var showAddAccount: Bool = false

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Form {
            Section(content: {
                TabView(selection: $model.indexActiveAccount) {
                    ForEach(0..<model.accounts.count, id: \.self) { index in
                        let status = model.getUserStatus()
                        let avatar = NCUtility().loadUserImage(for: model.accounts[index].user, displayName: model.accounts[index].displayName, userBaseUrl: model.accounts[index])
                        ///
                        /// User
                        VStack {
                            ZStack {
                                Image(uiImage: avatar)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width, height: 75)
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 30, height: 30)
                                    Image(uiImage: status.statusImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30)
                                    }
                                    .offset(x: 30, y: 30)
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
                            /// Personal data
                            if let tableAccount = model.tableAccount, !tableAccount.email.isEmpty {
                                HStack {
                                    Image(systemName: "mail")
                                        .resizable()
                                        .scaledToFit()
                                        .font(Font.system(.body).weight(.light))
                                        .frame(width: 20, height: 20)
                                    Text(tableAccount.email)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                }
                                .frame(maxWidth: .infinity, maxHeight: 30)
                            }
                            if let tableAccount = model.tableAccount, !tableAccount.phone.isEmpty {
                                HStack {
                                    Image(systemName: "phone")
                                        .resizable()
                                        .scaledToFit()
                                        .font(Font.system(.body).weight(.light))
                                        .frame(width: 20, height: 20)
                                    Text(tableAccount.phone)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity, maxHeight: 30)
                            }
                            if let tableAccount = model.tableAccount, !tableAccount.address.isEmpty {
                                HStack {
                                    Image(systemName: "house")
                                        .resizable()
                                        .scaledToFit()
                                        .font(Font.system(.body).weight(.light))
                                        .frame(width: 20, height: 20)
                                    Text(tableAccount.address)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity, maxHeight: 30)
                            }
                        }
                    }
                }
                .font(.system(size: 14))
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: model.getTableViewHeight())
                .onChange(of: model.indexActiveAccount) { index in
                    model.setAccount(account: model.accounts[index].account)
                }
                ///
                /// Change alias
                VStack {
                    HStack {
                        Text(NSLocalizedString("_alias_", comment: ""))
                            .font(.system(size: 17))
                            .fontWeight(.medium)
                        Spacer()
                        TextField(NSLocalizedString("_alias_placeholder_", comment: ""), text: $model.alias)
                            .font(.system(size: 16))
                            .multilineTextAlignment(.trailing)
                    }

                    Text(NSLocalizedString("_alias_footer_", comment: ""))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 12))
                        .lineLimit(2)
                        .foregroundStyle(Color(UIColor.lightGray))
                }
                ///
                /// User Status
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
                    UserStatusView(showUserStatus: $showUserStatus)
                }
                .onChange(of: showUserStatus) { _ in }
                ///
                /// Certificate server
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
                    if let url = URL(string: model.tableAccount?.urlBase), let host = url.host {
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
        .navigationBarTitle(NSLocalizedString("_credentials_", comment: ""))
        .defaultViewModifier(model)
        .onReceive(model.$dismissView) { newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

#Preview {
    NCManageAccountView(model: NCManageAccountModel(controller: nil))
}
