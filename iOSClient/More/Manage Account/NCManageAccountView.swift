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

    var body: some View {
        Form {
            TabView(selection: $model.indexActiveAccount) {
                ForEach(0..<model.accounts.count, id: \.self) { index in
                    HStack {
                        let account = model.accounts[index]
                        let status = model.getUserStatus(account: account)
                        let avatar = NCUtility().loadUserImage(for: account.user, displayName: account.displayName, userBaseUrl: account)
                        VStack {
                            Image(uiImage: avatar)
                                .resizable()
                                .scaledToFit()
                                .frame(width: UIScreen.main.bounds.width)
                                .clipped()
                            Spacer()
                            Text(model.getUserName(account: account))
                                .font(.system(size: 16))
                            Spacer()
                            if let message = status.statusMessage {
                                Text(message)
                                    .font(.system(size: 10))
                            }
                        }
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 100)
            .edgesIgnoringSafeArea(.all)
        }
        .navigationBarTitle(NSLocalizedString("_credentials_", comment: ""))
        .defaultViewModifier(model)
    }
}

#Preview {
    NCManageAccountView(model: NCManageAccountModel(controller: nil))
}
