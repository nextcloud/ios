//
//  NCManageE2EE.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/11/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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
import NextcloudKit
import TOPasscodeViewController
import LocalAuthentication

struct NCViewE2EE: View {
    @ObservedObject var manageE2EE: NCManageE2EE
    @State var account: String
    @State var controller: UITabBarController?

    init(account: String, controller: UITabBarController?) {
        self.manageE2EE = NCManageE2EE(controller: controller)
        self.account = account
        self.controller = controller
    }

    var body: some View {
        VStack {
            if manageE2EE.isEndToEndEnabled {
                List {
                    Section(header: Text(""), footer: Text(manageE2EE.statusOfService + "\n\n" + "End-to-End Encryption " + NCGlobal.shared.capabilityE2EEApiVersion)) {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_activated_", comment: ""))
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .font(Font.system(.body).weight(.light))
                                .foregroundColor(.green)
                        }
                    }
                    HStack {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_read_passphrase_", comment: ""))
                        } icon: {
                            Image(systemName: "eye")
                                .resizable()
                                .scaledToFit()
                                .font(Font.system(.body).weight(.light))
                                .foregroundColor(.black)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if NCKeychain().passcode != nil {
                            manageE2EE.requestPasscodeType("readPassphrase")
                        } else {
                            NCContentPresenter().showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                        }
                    }
                    HStack {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_remove_", comment: ""))
                        } icon: {
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .font(Font.system(.body).weight(.light))
                                .foregroundColor(.red)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if NCKeychain().passcode != nil {
                            manageE2EE.requestPasscodeType("removeLocallyEncryption")
                        } else {
                            NCContentPresenter().showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                        }
                    }
#if DEBUG
                    DeleteCerificateSection()
#endif
                }
            } else {
                List {
                    Section(header: Text(""), footer: Text(manageE2EE.statusOfService + "\n\n" + "End-to-End Encryption " + NCGlobal.shared.capabilityE2EEApiVersion)) {
                        HStack {
                            Label {
                                Text(NSLocalizedString("_e2e_settings_start_", comment: ""))
                            } icon: {
                                Image(systemName: "play.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .font(Font.system(.body).weight(.light))
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if NCKeychain().passcode != nil {
                                manageE2EE.requestPasscodeType("startE2E")
                            } else {
                                NCContentPresenter().showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                            }
                        }
                    }
#if DEBUG
                    DeleteCerificateSection()
#endif
                }
            }
        }
        .navigationBarTitle(NSLocalizedString("_e2e_settings_", comment: ""))
        .background(Color(UIColor.systemGroupedBackground))
        .defaultViewModifier(manageE2EE)
    }
}

struct DeleteCerificateSection: View {
    var body: some View {
        Section(header: Text("Delete Server keys"), footer: Text("Available only in debug mode")) {
            HStack {
                Label {
                    Text("Delete Certificate")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .font(Font.system(.body).weight(.light))
                        .foregroundColor(Color(NCBrandColor.shared.textColor2))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NextcloudKit.shared.deleteE2EECertificate { _, error in
                    if error == .success {
                        NCContentPresenter().messageNotification("E2E delete certificate", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .success)
                    } else {
                        NCContentPresenter().messageNotification("E2E delete certificate", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
                    }
                }
            }
            HStack {
                Label {
                    Text("Delete PrivateKey")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .font(Font.system(.body).weight(.light))
                        .foregroundColor(Color(NCBrandColor.shared.textColor2))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NextcloudKit.shared.deleteE2EEPrivateKey { _, error in
                    if error == .success {
                        NCContentPresenter().messageNotification("E2E delete privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .success)
                    } else {
                        NCContentPresenter().messageNotification("E2E delete privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
                    }
                }
            }
        }
    }
}

// MARK: - Preview / Test

struct SectionView: View {
    @State var height: CGFloat = 0
    @State var text: String = ""

    var body: some View {
        HStack {
            Text(text)
        }
        .frame(maxWidth: .infinity, minHeight: height, alignment: .bottomLeading)
    }
}

struct NCViewE2EETest: View {
    var body: some View {
        VStack {
            List {
                Section(header: SectionView(height: 50, text: "Section Header View")) {
                    Label {
                        Text(NSLocalizedString("_e2e_settings_activated_", comment: ""))
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .font(Font.system(.body).weight(.light))
                            .foregroundColor(.green)
                    }
                }
                Section(header: SectionView(text: "Section Header View 42")) {
                    Label {
                        Text(NSLocalizedString("_e2e_settings_activated_", comment: ""))
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .font(Font.system(.body).weight(.light))
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct NCViewE2EE_Previews: PreviewProvider {
    static var previews: some View {
        // swiftlint:disable force_cast
        let account = (UIApplication.shared.delegate as! AppDelegate).account
        NCViewE2EE(account: account, controller: nil)
        // swiftlint:enable force_cast
    }
}
