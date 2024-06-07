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
                        let account = model.accounts[index]
                        let status = model.getUserStatus(account: account)
                        let avatar = NCUtility().loadUserImage(for: account.user, displayName: account.displayName, userBaseUrl: account)
                        /// Avatar zone
                        VStack {
                            Image(uiImage: avatar)
                                .resizable()
                                .scaledToFit()
                                .frame(width: UIScreen.main.bounds.width, height: 75)
                                .clipped()
                            Text(model.getUserName(account: account))
                                .font(.system(size: 16))
                            if let message = status.statusMessage {
                                Spacer()
                                    .frame(height: 10)
                                Text(message)
                                    .font(.system(size: 10))
                            }
                            ///
                            Spacer()
                                .frame(height: 50)
                            /// Change alias
                            HStack {
                                Text(NSLocalizedString("_alias_", comment: ""))
                                    .font(.system(size: 17))
                                    .fontWeight(.medium)
                                Spacer()
                                TextField(NSLocalizedString("_alias_placeholder_", comment: ""), text: $model.alias)
                                    .onSubmit {
                                        model.submitChangedAlias(account: account)
                                    }
                                    .font(.system(size: 16))
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))

                            Text(NSLocalizedString("_alias_footer_", comment: ""))
                                .padding(EdgeInsets(top: 1, leading: 20, bottom: 0, trailing: 20))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.system(size: 12))
                                .lineLimit(2)
                                .foregroundStyle(Color(UIColor.lightGray))
                            ///
                            Divider()
                                .padding(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 0))
                            /// User Status
                            Button(action: {
                                showUserStatus.toggle()
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
                            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .sheet(isPresented: $showUserStatus) {
                            }
                            ///
                            Divider()
                                .padding(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 0))
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
                            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .sheet(isPresented: $showServerCertificate) {
                            }
                            ///
                            Divider()
                                .padding(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 0))
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
                            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .sheet(isPresented: $showPushCertificate) {
                            }
                            ///
                            Divider()
                                .padding(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 0))
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
                            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0))
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 390)
                .onChange(of: model.indexActiveAccount) { index in
                    if let account = model.getTableAccount(account: model.accounts[index].account) {
                        model.alias = account.alias
                    }
                }
            })
            /// All users
            Section(content: {
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
            })
        }
        .navigationBarTitle(NSLocalizedString("_credentials_", comment: ""))
        .defaultViewModifier(model)
    }
}

#Preview {
    NCManageAccountView(model: NCManageAccountModel(controller: nil))
}
