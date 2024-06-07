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
    @State private var showServerCertificate = false
    @State private var showPushCertificate = false

    var body: some View {
        Form {
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
                        .padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))

                        Text(NSLocalizedString("_alias_footer_", comment: ""))
                            .padding(EdgeInsets(top: 1, leading: 15, bottom: 0, trailing: 15))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.system(size: 12))
                            .foregroundColor(Color(UIColor.lightGray))
                        ///
                        Divider()
                            .padding(EdgeInsets(top: 5, leading: 15, bottom: 5, trailing: 5))
                        /// Certificates
                        Button(action: {
                            showServerCertificate.toggle()
                        }, label: {
                            HStack {
                                Image(systemName: "lock")
                                    .resizable()
                                    .scaledToFit()
                                    .font(Font.system(.body).weight(.light))
                                    .frame(width: 25, height: 25)
                                    .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                                Text(NSLocalizedString("_certificate_details_", comment: ""))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 15))
                            }
                            .font(.system(size: 14))
                        })
                        .padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 0))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tint(Color(NCBrandColor.shared.textColor))
                        .sheet(isPresented: $showServerCertificate) {
                        }
                        ///
                        Divider()
                            .padding(EdgeInsets(top: 5, leading: 15, bottom: 5, trailing: 0))
                        ///
                        Button(action: {
                            showPushCertificate.toggle()
                        }, label: {
                            HStack {
                                Image(systemName: "lock")
                                    .resizable()
                                    .scaledToFit()
                                    .font(Font.system(.body).weight(.light))
                                    .frame(width: 25, height: 25)
                                    .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                                Text(NSLocalizedString("_certificate_pn_details_", comment: ""))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 15))
                            }
                            .font(.system(size: 14))
                        })
                        .padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 0))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tint(Color(NCBrandColor.shared.textColor))
                        .sheet(isPresented: $showPushCertificate) {
                        }
                        Spacer()
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 500)
            .onChange(of: model.indexActiveAccount) { index in
                if let account = model.getTableAccount(account: model.accounts[index].account) {
                    model.alias = account.alias
                }
            }
        }
        .navigationBarTitle(NSLocalizedString("_credentials_", comment: ""))
        .defaultViewModifier(model)
    }
}

#Preview {
    NCManageAccountView(model: NCManageAccountModel(controller: nil))
}
