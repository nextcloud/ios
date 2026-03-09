// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Aditya Tyagi
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct NCSettingsAdvancedView: View {
    @ObservedObject var model: NCSettingsAdvancedModel
    // State variable for indicating whether the exit alert is shown.
    @State var showExitAlert: Bool = false
    // State variable for indicating whether the cache alert is shown.
    @State var showCacheAlert: Bool = false
    // State variable for indicating whether to disable crash reporter.
    @State var showCrashReporter: Bool = false

    var body: some View {
        Form {
            // file name
            Section(content: {
               NavigationLink(destination: LazyView {
                   NCFileNameView(model: NCFileNameModel(controller: model.controller))
               }) {
                   Text(NSLocalizedString("_filenamemask_", comment: ""))
                       .font(.body)
               }
            }, footer: {
                Text(fileNameMaskFooter)
                    .font(.footnote)
            })
            // Most Compatible & Enable Live Photo
            Section(content: {
                Toggle(NSLocalizedString("_format_compatibility_", comment: ""), isOn: $model.mostCompatible)
                    .font(.body)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.mostCompatible) {
                        model.updateMostCompatible()
                    }
            }, footer: {
                Text(NSLocalizedString("_format_compatibility_footer_", comment: ""))
                    .font(.footnote)
            })

            Section(content: {
                Toggle(NSLocalizedString("_upload_mov_livephoto_", comment: ""), isOn: $model.livePhoto)
                    .font(.body)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.livePhoto) {
                        model.updateLivePhoto()
                    }
            }, footer: {
                Text(NSLocalizedString("_upload_mov_livephoto_footer_", comment: ""))
                    .font(.footnote)
            })

            // Remove from Camera Roll
            Section(content: {
                Toggle(NSLocalizedString("_remove_photo_CameraRoll_", comment: ""), isOn: $model.removeFromCameraRoll)
                    .font(.body)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.removeFromCameraRoll) {
                        model.updateRemoveFromCameraRoll()
                }
            }, footer: {
                Text(NSLocalizedString("_remove_photo_CameraRoll_desc_", comment: ""))
                    .font(.footnote)
            })
            // Section : Files App
            if !NCBrandOptions.shared.disable_openin_file {
                Section(content: {
                    Toggle(NSLocalizedString("_disable_files_app_", comment: ""), isOn: $model.appIntegration)
                        .font(.body)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .onChange(of: model.appIntegration) {
                            model.updateAppIntegration()
                    }
                }, footer: {
                    Text(NSLocalizedString("_disable_files_app_footer_", comment: ""))
                        .font(.footnote)
                })
            }
            // Section: Privacy
            if !NCBrandOptions.shared.disable_crash_service {
                Section(content: {
                    Toggle(NSLocalizedString("_crashservice_title_", comment: ""), isOn: $model.crashReporter)
                        .font(.body)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .onChange(of: model.crashReporter) {
                            model.updateCrashReporter()
                            showCrashReporter.toggle()
                    }
                    .alert(NSLocalizedString("_crashservice_title_", comment: ""), isPresented: $showCrashReporter, actions: {
                        Button(NSLocalizedString("OK", comment: ""), role: .cancel) {
                            model.exitNextCloud(ext: showCrashReporter)
                        }
                    }, message: {
                        Text(NSLocalizedString("_crashservice_alert_", comment: ""))
                            .font(.body)
                    })
                }, header: {
                    Text(NSLocalizedString("_privacy_", comment: ""))
                        .font(.headline)
                }, footer: {
                    Text(NSLocalizedString("_privacy_footer_", comment: ""))
                        .font(.footnote)
                })
            }
            // Section: Diagnostic
            if !NCBrandOptions.shared.disable_log {
                Section(content: {
                    /// View Log File
                    Button(action: {
                        model.viewLogFile()
                    }, label: {
                        HStack {
                            Image(systemName: "doc.badge.gearshape")
                                .font(.icon())
                                .frame(width: 26)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            Text(NSLocalizedString("_view_log_", comment: ""))
                                .font(.body)
                        }
                    })
                    .tint(Color(UIColor.label))
                    // Set Log Level()
                    Picker(NSLocalizedString("_set_log_level_", comment: ""), selection: $model.selectedLogLevel) {
                        ForEach(NKLogLevel.allCases) { level in
                            Text(level.displayText).tag(level)
                                .font(.body)
                        }
                    }
                    .cappedFont(.body, maxDynamicType: .accessibility2)
                    .onChange(of: model.selectedLogLevel) {
                        model.updateSelectedLogLevel()
                    }
                    // Clear Log File
                    Button(action: {
                        model.clearLogFile()
                    }, label: {
                        HStack {
                            Image(systemName: "xmark")
                                .font(.icon())
                                .frame(width: 26)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            Text(NSLocalizedString("_clear_log_", comment: ""))
                                .font(.body)
                        }
                    })
                    .tint(Color(UIColor.label))
                }, header: {
                    Text(NSLocalizedString("_diagnostics_", comment: ""))
                        .font(.headline)
                }, footer: {
                    Text(NSLocalizedString("_diagnostics_footer_", comment: ""))
                        .font(.footnote)
                })
                // Set Log Level() & Capabilities
                if model.isAdminGroup {
                    Section(content: {
                        NavigationLink(destination: LazyView {
                            NCCapabilitiesView(model: NCCapabilitiesModel(controller: model.controller))
                        }) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .font(.icon())
                                    .frame(width: 26)
                                    .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                                Text(NSLocalizedString("_capabilities_", comment: ""))
                                    .font(.body)
                            }
                        }
                    }, header: {
                        Text(NSLocalizedString("_capabilities_", comment: ""))
                            .font(.headline)
                    }, footer: {
                        Text(NSLocalizedString("_capabilities_footer_", comment: ""))
                            .font(.footnote)
                    })
                }
            }
            // Delete in Cache & Clear Cache
            Section(content: {
                Picker(NSLocalizedString("_delete_old_files_", comment: ""), selection: $model.selectedInterval) {
                    ForEach(CacheDeletionInterval.allCases) { interval in
                        Text(interval.displayText)
                            .tag(interval)
                            .font(.body)
                    }
                }
                .cappedFont(.body, maxDynamicType: .accessibility2)
                .pickerStyle(.automatic)
                .onChange(of: model.selectedInterval) {
                    model.updateSelectedInterval()
                }
                Button(action: {
                    showCacheAlert.toggle()
                }, label: {
                    HStack {
                        Image(systemName: "xmark")
                            .font(.icon())
                            .frame(width: 26)
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        Text(NSLocalizedString("_clear_cache_", comment: ""))
                            .font(.body)
                    }
                })
                .tint(Color(UIColor.label))
                .alert(NSLocalizedString("_want_delete_cache_", comment: ""), isPresented: $showCacheAlert) {
                    Button(NSLocalizedString("_yes_", comment: ""), role: .destructive) {
                        model.clearCache()
                    }
                    Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) { }
                }
            }, header: {
                Text(NSLocalizedString("_delete_files_desc_", comment: ""))
                    .font(.headline)
            }, footer: {
                Text("_clear_cache_footer_")
                    .multilineTextAlignment(.leading)
                    .font(.footnote)
            })
            // Reset Application
            Section(content: {
                Button(action: {
                    showExitAlert.toggle()
                }, label: {
                    HStack {
                        Image(systemName: "xmark")
                            .font(.icon())
                            .frame(width: 26)
                            .foregroundColor(Color(UIColor.systemRed))
                        Text(NSLocalizedString("_exit_", comment: ""))
                            .font(.body)
                            .foregroundColor(Color(UIColor.systemRed))
                    }
                })
                .tint(Color(UIColor.label))
                .alert(NSLocalizedString("_want_exit_", comment: ""), isPresented: $showExitAlert) {
                    Button(NSLocalizedString("_ok_", comment: ""), role: .destructive) {
                        model.resetNextCloud()
                    }
                    Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) { }
                }
            }, footer: {
               (
                Text(NSLocalizedString("_exit_footer_", comment: ""))
                    .font(.footnote)
                +
                Text("\n\n")
                    .font(.footnote)
               )
            })
        }
        .navigationBarTitle(NSLocalizedString("_advanced_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .defaultViewModifier(model)
    }

    private var fileNameMaskFooter: AttributedString {
        let boldPart = NSLocalizedString("_filenamemask_format_", comment: "")
        let localizedString = String(
            format: NSLocalizedString("_filenamemask_footer_", comment: ""),
            boldPart
        )

        var attributedString = AttributedString(localizedString)

        if let range = attributedString.range(of: boldPart) {
            attributedString[range].font = .footnote.weight(.semibold)
        }

        return attributedString
    }
}

#Preview {
    NCSettingsAdvancedView(model: NCSettingsAdvancedModel(controller: nil), showExitAlert: false, showCacheAlert: false)
}
