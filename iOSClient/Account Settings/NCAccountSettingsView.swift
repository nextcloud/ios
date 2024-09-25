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
                userAccountsSection
                changeAliasSection
                if NCGlobal.shared.capabilityUserStatusEnabled {
                    userStatusButtonView
                }
                if model.isAdminGroup() {
                    sertificateDetailsButtonView
                    sertificatePNButtonView
                }
                switchAccountSection
                addAccountSection
                deleteAccountSection
            }
            .applyGlobalFormStyle()
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
            model.delegate?.accountSettingsDidDismiss(tableAccount: model.activeAccount)
        }
    }
}

extension NCAccountSettingsView {
    
    private var userAccountsSection: some View {
        TabView(selection: $model.indexActiveAccount) {
            ForEach(0..<model.accounts.count, id: \.self) { index in
                let userStatus = model.getUserStatus()
                let userAvatar = NCUtility().loadUserImage(for: AppDelegate().user, displayName: model.activeAccount?.displayName, userBaseUrl: AppDelegate())
                AccountView(account: model.accounts[index], userAvatar: userAvatar, userStatus: userStatus)
            }
        }
        .font(.system(size: 14))
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(height: model.getTableViewHeight())
        .animation(.easeIn(duration: 0.3), value: animation)
        .onChange(of: model.indexActiveAccount) { index in
            animation.toggle()
            model.setAccount(account: model.accounts[index].account)
        }
    }
    
    private var changeAliasSection: some View {
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
    }
    
    private var userStatusButtonView: some View {
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
    }
    
    private var sertificateDetailsButtonView: some View {
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
            if let url = URL(string: model.activeAccount?.urlBase), let host = url.host {
                certificateDetailsView(host: host, title: NSLocalizedString("_certificate_view_", comment: ""))
            }
        }
    }
    
    private var sertificatePNButtonView: some View {
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
    
    private var switchAccountSection: some View {
        VStack {
            ForEach(0..<model.accounts.count, id: \.self) { index in
                let userAvatar = NCUtility().loadUserImage(for: model.accounts[index].user, displayName: model.accounts[index].displayName, userBaseUrl: model.accounts[index])
                Button(action: {
                    model.setAccount(account: model.accounts[index].account)
                    model.changeAccount()
                }) {
                    SwitchAccountRowView(
                        image: userAvatar,
                        userName: model.accounts[index].displayName,
                        userEmail: model.accounts[index].email,
                        isActive: model.accounts[index].active)
                }
                
            }
        }
    }
    
    private var addAccountSection: some View {
        Button(action: {
            model.openLogin()
        }, label: {
            HStack {
                Image(systemName: "plus")
                    .font(.system(size: 13).weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color(NCBrandColor.shared.brandElement)))
                    .padding(.trailing, 10)
                Text(NSLocalizedString("_add_account_", comment: ""))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
            }
            .font(.system(size: 16))
        })
    }
    
    private var deleteAccountSection: some View {
        Button(action: {
            showDeleteAccountAlert.toggle()
        }, label: {
            HStack {
                Image(systemName: "trash")
                    .resizable()
                    .scaledToFit()
                    .font(Font.system(.body).weight(.light))
                    .frame(width: 20, height: 20)
                    .padding(.trailing, 10)
                    .foregroundStyle(.red)
                Text(NSLocalizedString("_remove_local_account_", comment: ""))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
            }
            .font(.system(size: 16))
        })
        .alert(NSLocalizedString("_want_delete_account_", comment: ""), isPresented: $showDeleteAccountAlert) {
            Button(NSLocalizedString("_remove_local_account_", comment: ""), role: .destructive) {
                model.deleteAccount()
            }
            Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) { }
        }
    }
    
}

struct AccountView: View {
    let account: tableAccount
    let userAvatar: UIImage
    let userStatus: (statusImage: UIImage?, statusMessage: String, descriptionMessage: String)

    var body: some View {
        VStack {
            UserImageView(avatar: userAvatar, onlineStatus: userStatus.statusImage)
            Text(account.displayName)
                .font(.system(size: 16))
            Spacer().frame(height: 10)
            Text(userStatus.statusMessage)
                .font(.system(size: 10))
            Spacer().frame(height: 20)
            PersonalDataView(account: account)
        }
    }
}

struct PersonalDataView: View {
    let account: tableAccount

    var body: some View {
        VStack {
            if !account.email.isEmpty {
                PersonalDataRow(icon: "mail", data: account.email)
            }
            if !account.phone.isEmpty {
                PersonalDataRow(icon: "phone", data: account.phone)
            }
            if !account.address.isEmpty {
                PersonalDataRow(icon: "house", data: account.address)
            }
        }
    }
}

struct PersonalDataRow: View {
    let icon: String
    let data: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            Text(data)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: 30)
    }
}

struct UserImageView: View {
    let avatar: UIImage?
    let onlineStatus: UIImage?

    var body: some View {
        ZStack {
            if let avatar = avatar {
                Image(uiImage: avatar)
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width, height: 75)
            }
            if let onlineStatus = onlineStatus {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 30, height: 30)
                    Image(uiImage: onlineStatus)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
                .offset(x: 30, y: 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SwitchAccountRowView: View {
    let image: UIImage
    let userName: String
    let userEmail: String
    let isActive: Bool

    var body: some View {
        HStack {
            Image(uiImage: UIImage(named: "accountCheckmark")!)
                .resizable()
                .frame(width: 20, height: 15)
                .padding(.trailing, 10)
                .hiddenConditionally(isHidden: !isActive)
            VStack(alignment: .leading) {
                Text(userName)
                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                    .padding(.trailing, 20)
                    .font(.system(size: 17))
                Text(userEmail)
                    .foregroundStyle(Color(UIColor.lightGray))
                    .padding(.trailing, 20)
                    .font(.system(size: 16))
            }
            .lineLimit(1)
            Spacer()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 35, height: 35)
                .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
        }
        .font(.system(size: 14))
    }
}

#Preview {
    NCAccountSettingsView(model: NCAccountSettingsModel(delegate: nil))
}
