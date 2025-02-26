//
//  NCManageE2EEView.swift
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

struct NCManageE2EEView: View {
    @ObservedObject var model: NCManageE2EE
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            if model.isEndToEndEnabled {
                List {
                    Section(header: Text(""), footer: Text(model.statusOfService + "\n\n" + "End-to-End Encryption " + model.capabilities.capabilityE2EEApiVersion)) {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_activated_", comment: ""))
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .font(Font.system(.body).weight(.light))
                                .frame(width: 25, height: 25)
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
                                .frame(width: 25, height: 25)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if NCKeychain().passcode != nil {
                            model.requestPasscodeType("readPassphrase")
                        } else {
                            NCContentPresenter().showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                        }
                    }
                    HStack {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_remove_", comment: ""))
                        } icon: {
                            Image(systemName: "xmark")
                                .resizable()
                                .scaledToFit()
                                .font(Font.system(.body).weight(.light))
                                .frame(width: 25, height: 15)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if NCKeychain().passcode != nil {
                            model.requestPasscodeType("removeLocallyEncryption")
                        } else {
                            NCContentPresenter().showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                        }
                    }
#if DEBUG
                    deleteCerificateSection
#endif
                }
            } else {
                List {
                    Section(header: Text(""), footer: Text(model.statusOfService + "\n\n" + "End-to-End Encryption " + model.capabilities.capabilityE2EEApiVersion)) {
                        HStack {
                            Label {
                                Text(NSLocalizedString("_e2e_settings_start_", comment: ""))
                            } icon: {
                                Image(systemName: "play.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .font(Font.system(.body).weight(.light))
                                    .frame(width: 25, height: 25)
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if NCKeychain().passcode != nil {
                                model.requestPasscodeType("startE2E")
                            } else {
                                NCContentPresenter().showInfo(error: NKError(errorCode: 0, errorDescription: "_e2e_settings_lock_not_active_"))
                            }
                        }
                    }
#if DEBUG
                    deleteCerificateSection
#endif
                }
            }
        }
        .navigationBarTitle(NSLocalizedString("_e2e_settings_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground))
        .defaultViewModifier(model)
        .onChange(of: model.navigateBack) { newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    @ViewBuilder
    var deleteCerificateSection: some View {
        Section(header: Text("Delete Server keys"), footer: Text("Available only in debug mode")) {
            HStack {
                Label {
                    Text("Delete Certificate")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .font(Font.system(.body).weight(.light))
                        .frame(width: 25, height: 25)
                        .foregroundColor(Color(NCBrandColor.shared.textColor2))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NextcloudKit.shared.deleteE2EECertificate(account: model.session.account) { _, _, error in
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
                        .frame(width: 25, height: 25)
                        .foregroundColor(Color(NCBrandColor.shared.textColor2))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NextcloudKit.shared.deleteE2EEPrivateKey(account: model.session.account) { _, _, error in
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

#Preview {
    NCManageE2EEView(model: NCManageE2EE(controller: nil))
}
