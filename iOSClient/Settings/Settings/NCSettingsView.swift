// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Aditya Tyagi
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import Combine
import NextcloudKit
import FirebaseCrashlytics

/// Settings view for Nextcloud
@MainActor
struct NCSettingsView: View {
    // State to control the visibility of the acknowledgements view
    @State private var showAcknowledgements = false
    // State to control the visibility of the passcode view
    @State private var showPasscode = false
    // State to contorl the visibility of the change passcode view
    @State private var showChangePasscode = false
    // State to control the visibility of the Policy view
    @State private var showBrowser = false
    // State to control the visibility of the Source Code  view
    @State private var showSourceCode = false
#if DEBUG
    @State private var isExportingDatabase = false
    @State private var showDatabaseExportError = false
    @State private var databaseExportError = ""
#endif
    // Object of ViewModel of this view
    @ObservedObject var model: NCSettingsModel

    var capabilities: NKCapabilities.Capabilities {
        NCNetworking.shared.capabilities[model.controller?.account ?? ""] ?? NKCapabilities.Capabilities()
    }

    var body: some View {
        Form {
            // `Privacy` Section
            Section(content: {
                Button(action: {
                    showPasscode.toggle()
                }, label: {
                    HStack {
                        Image(systemName: model.isLockActive ? "lock" : "lock.open")
                            .font(.icon())
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            .opacity(NCBrandOptions.shared.enforce_passcode_lock ? 0.5 : 1)
                            .frame(width: 39)

                        Text(model.isLockActive ? NSLocalizedString("_turn_passcode_off_", comment: "") : NSLocalizedString("_turn_passcode_on_", comment: ""))
                            .font(.body)
                    }
                })
                .tint(Color(NCBrandColor.shared.textColor))
                .accessibilityIdentifier("settings.passcode.toggle")
                .disabled(NCBrandOptions.shared.enforce_passcode_lock)
            }, header: {
                Text(NSLocalizedString("_privacy_", comment: ""))
                    .font(.headline)
            }, footer: {
                if NCBrandOptions.shared.enforce_passcode_lock {
                    Text(NSLocalizedString("_lock_cannot_disable_mdm_", comment: ""))
                        .font(.footnote)
                }
            })

            if model.isLockActive {
                Section(content: {
                    Group {
                        // Change passcode
                        Button(action: {
                            showChangePasscode.toggle()
                        }, label: {
                            VStack {
                                Text(NSLocalizedString("_change_lock_passcode_", comment: ""))
                                    .font(.body)
                                    .tint(Color(NCBrandColor.shared.textColor))
                            }
                        })
                        .accessibilityIdentifier("settings.passcode.change")
                        // Enable Touch ID
                        Toggle(NSLocalizedString("_enable_touch_face_id_", comment: ""), isOn: Binding(
                            get: { model.enableTouchFaceID },
                            set: { enabled in
                                Task { @MainActor in
                                    await model.updateTouchIDSettingAsync(enabled)
                                }
                            }
                        ))
                        .font(.body)
                        .disabled(model.isUpdatingTouchID)

                        if !NCBrandOptions.shared.enforce_passcode_lock {
                            // Do not ask for passcode on startup
                            Toggle(NSLocalizedString("_lock_protection_no_screen_", comment: ""), isOn: $model.lockScreen)
                                .font(.body)
                                .onChange(of: model.lockScreen) {
                                    model.updateLockScreenSetting()
                                }
                        }

                        // Reset app wrong attempts
                        Toggle(NSLocalizedString("_reset_wrong_passcode_option_", comment: ""), isOn: $model.resetWrongAttempts)
                            .accessibilityIdentifier("settings.passcode.reset")
                            .font(.body)
                            .onChange(of: model.resetWrongAttempts) {
                                model.updateResetWrongAttemptsSetting()
                            }
                    }
                }, footer: {
                    Text(String(format: NSLocalizedString("_reset_wrong_passcode_desc_", comment: ""), NCBrandOptions.shared.resetAppPasscodeAttempts))
                        .font(.footnote)

                })
                .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
            }

            if !NCBrandOptions.shared.enforce_privacyScreenEnabled {
                Section(content: {
                    // Splash screen when app inactive
                    Toggle(NSLocalizedString("_privacy_screen_", comment: ""), isOn: $model.privacyScreen)
                        .font(.body)
                        .onChange(of: model.privacyScreen) {
                            model.updatePrivacyScreenSetting()
                        }
                }, footer: {
                    Text(NSLocalizedString("_privacy_screen_footer_", comment: ""))
                        .font(.footnote)
                })
                .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
            }

            // Display
            Section(header: Text(NSLocalizedString("_display_", comment: "")).font(.headline), content: {
                NavigationLink(destination: LazyView {
                    NCDisplayView(model: NCDisplayModel(controller: model.controller))
                }) {
                    HStack {
                        Image(systemName: "sun.max.circle")
                            .font(.icon())
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            .frame(width: 39)

                        Text(NSLocalizedString("_display_", comment: ""))
                            .font(.body)
                    }
                }
            })
            // Calender & Contacts
            if !NCBrandOptions.shared.disable_mobileconfig {
                Section(content: {
                    Button(action: {
                        model.getConfigFiles()
                    }, label: {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .font(.icon())
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                                .frame(width: 39)

                            Text(NSLocalizedString("_mobile_config_", comment: ""))
                                .font(.body)
                        }
                    })
                    .tint(Color(NCBrandColor.shared.textColor))
                }, header: {
                    Text(NSLocalizedString("_calendar_contacts_", comment: ""))
                        .font(.headline)
                }, footer: {
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("_calendar_contacts_footer_warning_", comment: ""))
                            .font(.footnote)

                        Spacer()
                        Text(NSLocalizedString("_calendar_contacts_footer_", comment: ""))
                            .font(.footnote)
                    }
                })
            }
            // Users
            Section(content: {
                Toggle(NSLocalizedString("_settings_account_request_", comment: ""), isOn: $model.accountRequest)
                    .font(.body)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.accountRequest) {
                        model.updateAccountRequest()
                    }
            }, header: {
                Text(NSLocalizedString("_users_", comment: ""))
                    .font(.headline)
            }, footer: {
                Text(NSLocalizedString("_users_footer_", comment: ""))
                    .font(.footnote)
            })
            // E2EEncryption` Section
            if capabilities.e2EEEnabled {
                E2EESection(model: model)
            }
            // `Advanced` Section
            Section {
                NavigationLink(destination: LazyView {
                    NCSettingsAdvancedView(model: NCSettingsAdvancedModel(controller: model.controller), showExitAlert: false, showCacheAlert: false)
                }) {
                    HStack {
                        Image(systemName: "gear")
                            .font(.icon())
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            .frame(width: 39)

                        Text(NSLocalizedString("_advanced_", comment: ""))
                            .font(.body)
                    }
                }
            }
            // `Information` Section
            Section(header: Text(NSLocalizedString("_information_", comment: "")).font(.headline), content: {
                // Acknowledgements
                Button(action: {
                    showAcknowledgements.toggle()
                }, label: {
                    HStack {
                        Image(systemName: "figure.2.circle")
                            .font(.icon())
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            .frame(width: 39)

                        Text(NSLocalizedString("_acknowledgements_", comment: ""))
                            .font(.body)
                    }
                })
                .tint(Color(NCBrandColor.shared.textColor))
                .sheet(isPresented: $showAcknowledgements) {
                    NCAcknowledgementsView(browserTitle: NSLocalizedString("_acknowledgements_", comment: ""))
                }
                // Terms & Privacy Conditions
                Button(action: {
                    showBrowser.toggle()
                }, label: {
                    HStack {
                        Image(systemName: "shield.checkerboard")
                            .font(.icon())
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            .frame(width: 39)

                        Text(NSLocalizedString("_privacy_legal_", comment: ""))
                            .font(.body)
                    }
                })
                .tint(Color(NCBrandColor.shared.textColor))
                .sheet(isPresented: $showBrowser) {
                    NCBrowserWebView(urlBase: URL(string: NCBrandOptions.shared.privacy)!, browserTitle: NSLocalizedString("_privacy_legal_", comment: ""))
                }
                // Source Code Nextcloud App
                if !NCBrandOptions.shared.disable_source_code_in_settings {
                    Button(action: {
                        showSourceCode.toggle()
                    }, label: {
                        HStack {
                            Image(systemName: "network")
                                .font(.icon())
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                                .frame(width: 39)

                            Text(NSLocalizedString("_source_code_", comment: ""))
                                .font(.body)
                        }
                    })
                    .tint(Color(NCBrandColor.shared.textColor))
                    .sheet(isPresented: $showSourceCode) {
                        NCBrowserWebView(urlBase: URL(string: NCBrandOptions.shared.sourceCode)!, browserTitle: NSLocalizedString("_source_code_", comment: ""))
                    }
                }
            })
#if DEBUG
            Section(header: Text("Debug").font(.headline), content: {
                Button(action: exportDebugDatabase, label: {
                    HStack {
                        Image(systemName: "cylinder.split.1x2")
                            .font(.icon())
                            .foregroundColor(.orange)
                            .frame(width: 39)

                        Text(isExportingDatabase ? "Exporting GRDB database…" : "Export GRDB database")
                            .font(.body)
                    }
                })
                .tint(Color(NCBrandColor.shared.textColor))
                .disabled(isExportingDatabase)

                Button(action: {
                    Crashlytics.crashlytics().log("Test crash triggered")
                    fatalError("🔥 Crash test")
                }, label: {
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.icon())
                            .foregroundColor(.red)
                            .frame(width: 39)

                        Text("Test crash triggered")
                            .font(.body)
                    }
                })
                .tint(Color(NCBrandColor.shared.textColor))
            })
#endif

            // `Watermark` Section
            Section(content: {
            }, footer: {
                Text(model.footerApp + model.footerServer + model.footerSlogan)
                    .font(.footnote)
            })
        }
        .onReceive(NotificationCenter.default.publisher(for: NCPasscodeModel.lockoutNotification)) { _ in
            // The scene's mandatory window takes over; do not leave the settings operation open underneath.
            if showPasscode || showChangePasscode {
                completePasscode(.cancelled)
            }
        }
        .sheet(isPresented: $showPasscode) {
            NCPasscodeView(mode: NCPreferences().passcode == nil ? .create : .disable,
                           allowCancel: true,
                           windowScene: SceneManager.shared.getWindowScene(controller: model.controller),
                           completion: completePasscode)
        }
        .sheet(isPresented: $showChangePasscode) {
            NCPasscodeView(mode: .change,
                           allowCancel: true,
                           windowScene: SceneManager.shared.getWindowScene(controller: model.controller),
                           completion: completePasscode)
        }
#if DEBUG
        .alert("Database export failed", isPresented: $showDatabaseExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(databaseExportError)
        }
#endif
        .navigationBarTitle(NSLocalizedString("_settings_", comment: ""))
        .defaultViewModifier(model)
    }

    /// Update the lock setting only after the passcode operation has completed.
    private func completePasscode(_ result: NCPasscodeModel.Result) {
        switch result {
        case .configured:
            model.isLockActive = true
        case .disabled:
            model.isLockActive = false
        case .reset:
            (UIApplication.shared.delegate as? AppDelegate)?.resetApplication()
        case .authenticated, .cancelled:
            break
        }
        showPasscode = false
        showChangePasscode = false
    }

#if DEBUG
    private func exportDebugDatabase() {
        isExportingDatabase = true

        Task {
            defer { isExportingDatabase = false }

            do {
                let exportURL = try await Task.detached(priority: .userInitiated) {
                    try NCLocalDatabase.shared.exportDebugDatabase()
                }.value

                guard let controller = model.controller else {
                    throw CocoaError(.coderInvalidValue)
                }
                let presentingViewController = controller.topMostViewController()

                let activityViewController = UIActivityViewController(
                    activityItems: [exportURL],
                    applicationActivities: nil
                )
                if let popover = activityViewController.popoverPresentationController {
                    popover.sourceView = presentingViewController.view
                    popover.sourceRect = CGRect(
                        x: presentingViewController.view.bounds.midX,
                        y: presentingViewController.view.bounds.midY,
                        width: 0,
                        height: 0
                    )
                }
                presentingViewController.present(activityViewController, animated: true)
            } catch {
                databaseExportError = error.localizedDescription
                showDatabaseExportError = true
            }
        }
    }
#endif
}

struct E2EESection: View {
    @ObservedObject var model: NCSettingsModel

    var body: some View {
        Section(header: Text(NSLocalizedString("_e2e_settings_title_", comment: "")).font(.headline), content: {
            NavigationLink(destination: LazyView {
                NCManageE2EEView(model: NCManageE2EE(controller: model.controller))
            }) {
                HStack {
                    Image(systemName: "lock")
                        .font(.icon())
                        .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        .frame(width: 39)

                    Text(NSLocalizedString("_e2e_settings_", comment: ""))
                        .font(.body)
                }
            }
        })
    }
}

#Preview {
    NCSettingsView(model: NCSettingsModel(controller: nil))
}
