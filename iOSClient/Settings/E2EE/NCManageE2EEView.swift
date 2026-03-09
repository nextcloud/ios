// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct NCManageE2EEView: View {
    @ObservedObject var model: NCManageE2EE
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            if model.isEndToEndEnabled {
                List {
                    Section(header: Text("").font(.headline),
                            footer: Text(model.statusOfService + "\n\n" + "End-to-End Encryption " + model.capabilities.e2EEApiVersion).font(.footnote)) {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_activated_", comment: ""))
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                                .fontWeight(.light)
                                .frame(width: 25, height: 25)
                                .foregroundColor(.green)
                        }
                    }
                    HStack {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_read_passphrase_", comment: ""))
                                .cappedFont(.body, maxDynamicType: .accessibility2)

                        } icon: {
                            Image(systemName: "eye")
                                .resizable()
                                .scaledToFit()
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                                .fontWeight(.light)
                                .frame(width: 25, height: 25)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if NCPreferences().passcode != nil {
                            model.requestPasscodeType("readPassphrase")
                        } else {
                            Task {
                                await showInfoBanner(windowScene: model.windowScene, text: "_e2e_settings_lock_not_active_")
                            }
                        }
                    }
                    HStack {
                        Label {
                            Text(NSLocalizedString("_e2e_settings_remove_", comment: ""))
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                        } icon: {
                            Image(systemName: "xmark")
                                .resizable()
                                .scaledToFit()
                                .cappedFont(.body, maxDynamicType: .accessibility2)
                                .fontWeight(.light)
                                .frame(width: 25, height: 15)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if NCPreferences().passcode != nil {
                            model.requestPasscodeType("removeLocallyEncryption")
                        } else {
                            Task {
                                await showInfoBanner(windowScene: model.windowScene, text: "_e2e_settings_lock_not_active_")
                            }
                        }
                    }
#if DEBUG
                    deleteCerificateSection
#endif
                }
            } else {
                List {
                    Section(header: Text("").font(.headline),
                            footer: Text(model.statusOfService + "\n\n" + "End-to-End Encryption " + model.capabilities.e2EEApiVersion).font(.footnote)) {
                        HStack {
                            Label {
                                Text(NSLocalizedString("_e2e_settings_start_", comment: ""))
                                    .cappedFont(.body, maxDynamicType: .accessibility2)
                            } icon: {
                                Image(systemName: "play.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .cappedFont(.body, maxDynamicType: .accessibility2)
                                    .fontWeight(.light)
                                    .frame(width: 25, height: 25)
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if NCPreferences().passcode != nil {
                                model.requestPasscodeType("startE2E")
                            } else {
                                Task {
                                    await showInfoBanner(windowScene: model.windowScene, text: "_e2e_settings_lock_not_active_")
                                }
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
        .onChange(of: model.navigateBack) { _, newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    @ViewBuilder
    var deleteCerificateSection: some View {
        Section(header: Text("Delete Server keys").font(.headline),
                footer: Text("Available only in debug mode").font(.footnote)) {
            HStack {
                Label {
                    Text("Delete Certificate")
                        .cappedFont(.body, maxDynamicType: .accessibility2)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .cappedFont(.body, maxDynamicType: .accessibility2)
                        .fontWeight(.light)
                        .frame(width: 25, height: 25)
                        .foregroundColor(Color(NCBrandColor.shared.textColor2))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NextcloudKit.shared.deleteE2EECertificate(account: model.session.account) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: model.session.account,
                                                                                                    name: "deleteE2EECertificate")
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                } completion: { _, _, error in
                    Task {
                        if error == .success {
                            await showInfoBanner(windowScene: model.windowScene,
                                                 text: "E2E delete certificate")
                        } else {
                            await showErrorBanner(windowScene: model.windowScene,
                                                  text: error.errorDescription,
                                                  errorCode: error.errorCode)
                        }
                    }
                }
            }
            HStack {
                Label {
                    Text("Delete PrivateKey")
                        .cappedFont(.body, maxDynamicType: .accessibility2)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .cappedFont(.body, maxDynamicType: .accessibility2)
                        .fontWeight(.light)
                        .frame(width: 25, height: 25)
                        .foregroundColor(Color(NCBrandColor.shared.textColor2))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NextcloudKit.shared.deleteE2EEPrivateKey(account: model.session.account) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: model.session.account,
                                                                                                    name: "deleteE2EEPrivateKey")
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                } completion: { _, _, error in
                    Task {
                        if error == .success {
                            await showInfoBanner(windowScene: model.windowScene,
                                                 text: "E2E delete privateKey")
                        } else {
                            await showErrorBanner(windowScene: model.windowScene,
                                                  text: error.errorDescription,
                                                  errorCode: error.errorCode)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NCManageE2EEView(model: NCManageE2EE(controller: nil))
}
