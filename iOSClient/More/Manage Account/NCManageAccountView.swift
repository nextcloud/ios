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
                    ///
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
                        Spacer()
                            .frame(height: 30)
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
                            Spacer()
                                .frame(width: 5)

                        }
                        Text(NSLocalizedString("_alias_footer_", comment: ""))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.system(size: 12))
                            .foregroundColor(Color(UIColor.lightGray))
                        Spacer()
                        ///
                        Divider()
                        ///
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
                            }
                            .font(.system(size: 14))
                        })
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tint(Color(NCBrandColor.shared.textColor))
                        .sheet(isPresented: $showServerCertificate) {
                        }
                        ///
                        Divider()

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
                            }
                            .multilineTextAlignment(.leading)
                            .font(.system(size: 14))
                        })
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tint(Color(NCBrandColor.shared.textColor))
                        .sheet(isPresented: $showPushCertificate) {
                        }
                        Spacer()
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 300)
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
