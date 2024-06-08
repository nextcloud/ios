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

    var body: some View {
        Form {
            Section(content: {
                TabView(selection: $model.indexActiveAccount) {
                    ForEach(0..<model.accounts.count, id: \.self) { index in
                        let status = model.getUserStatus()
                        let avatar = NCUtility().loadUserImage(for: model.accounts[index].user, displayName: model.accounts[index].displayName, userBaseUrl: model.accounts[index])
                        /// Avatar zone
                        VStack {
                            Image(uiImage: avatar)
                                .resizable()
                                .scaledToFit()
                                .frame(width: UIScreen.main.bounds.width, height: 75)
                                .clipped()
                            Text(model.getUserName())
                                .font(.system(size: 16))
                            if let message = status.statusMessage {
                                Spacer()
                                    .frame(height: 10)
                                Text(message)
                                    .font(.system(size: 10))
                            }
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 150)
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
                ///
                /// Delete account
                Button(action: {

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
            })

            Section(content: {
                ///
                /// Add account
                Button(action: {

                }, label: {
                    HStack {
                        Image(systemName: "plus")
                            .resizable()
                            .scaledToFit()
                            .font(Font.system(.body).weight(.light))
                            .frame(width: 20, height: 20)
                            .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                        Text(NSLocalizedString("_add_account_", comment: ""))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                    }
                    .font(.system(size: 14))
                })
                ///
                /// Request account
                Toggle(NSLocalizedString("_settings_account_request_", comment: ""), isOn: $model.accountRequest)
                    .font(.system(size: 16))
                    .tint(Color(NCBrandColor.shared.brandElement))
                    .onChange(of: model.accountRequest, perform: { _ in
                        model.updateAccountRequest()
                    })
            })
        }
        .navigationBarTitle(NSLocalizedString("_credentials_", comment: ""))
        .defaultViewModifier(model)
    }
}

#Preview {
    NCManageAccountView(model: NCManageAccountModel(controller: nil))
}
