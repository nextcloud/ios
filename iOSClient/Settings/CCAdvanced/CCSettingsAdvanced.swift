//
//  CCSettingsAdvanced.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 08/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit

struct CCSettingsAdvanced: View {
    // Published properties for the toggles
    
    /// State variable for indicating whether hidden files are shown.
    @State var showHiddenFiles: Bool
    /// State variable for indicating the most compatible format.
    @State var mostCompatible: Bool
    /// State variable for enabling live photo uploads.
    @State var livePhoto: Bool
    /// State variable for indicating whether to remove photos from the camera roll after upload.
    @State var removeFromCameraRoll: Bool
    /// State variable for app integration.
    @State var appIntegration: Bool
    /// State variable for enabling the crash reporter.
    @State var crashReporter: Bool
    /// State variable for indicating whether the exit alert is shown.
    @State var showExitAlert: Bool = false
    /// State variable for indicating whether the cache alert is shown.
    @State var showCacheAlert: Bool = false
    
    // Properties for log level and cache deletion
    
    /// State variable for storing the selected log level.
    @State var selectedLogLevel: LogLevel
    /// State variable for storing the selected cache deletion interval.
    @State var selectedInterval: CacheDeletionInterval
    /// State variable for storing the footer title, usually used for cache deletion.
    @State var footerTitle: String = NSLocalizedString("_clear_cache_footer_", comment: "")
    
    
    var body: some View {
        
        Form {
            
            // Show Hidden Files
            Section(content: {
                Toggle(NSLocalizedString("_show_hidden_files_", comment: ""), isOn: $showHiddenFiles)
                    .onChange(of: showHiddenFiles) { _ in
                        
                    }
            }, footer: {
                Text("All Hidden files will be visible in every device")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.leading)
            })
            
            
            // Most Compatible & Enable Live Photo
            Section(content: {
                Toggle(NSLocalizedString("_format_compatibility_", comment: ""), isOn: $mostCompatible)
                    .onChange(of: mostCompatible) { _ in
                        
                    }
                
                Toggle(NSLocalizedString("_upload_mov_livephoto_", comment: ""), isOn: $livePhoto)
                    .onChange(of: livePhoto) { _ in
                        
                    }
                
            }, footer: {
                (
                    Text(NSLocalizedString("_format_compatibility_footer_", comment: ""))
                    +
                    Text(NSLocalizedString("_upload_mov_livephoto_footer_", comment: ""))
                    
                ).font(.system(size: 12))
                    .multilineTextAlignment(.leading)
                
            })
            
            
            // Remove from Camera Roll
            Section(content: {
                Toggle(NSLocalizedString("_remove_photo_CameraRoll_", comment: ""), isOn: $removeFromCameraRoll)
                    .onChange(of: removeFromCameraRoll) { _ in
                        
                    }
                
            }, footer: {
                Text(NSLocalizedString("_remove_photo_CameraRoll_desc_", comment: ""))
                    .font(.system(size: 12))
                    .multilineTextAlignment(.leading)
            })
            
            
            // Section : Files App
            if !NCBrandOptions.shared.disable_openin_file {
                Section(content: {
                    Toggle(NSLocalizedString("_disable_files_app_", comment: ""), isOn: $appIntegration)
                        .onChange(of: appIntegration) { _ in
                            
                        }
                }, footer: {
                    Text(NSLocalizedString("_disable_files_app_footer_", comment: ""))
                        .font(.system(size: 12))
                        .multilineTextAlignment(.leading)
                })
            }
            
            
            // Section: Privacy
            if !NCBrandOptions.shared.disable_crash_service {
                Section(content: {
                    HStack {
                        Image("crashservice")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(UIColor.systemGray))
                        
                        Toggle(NSLocalizedString("_crashservice_title_", comment: ""), isOn: $crashReporter)
                            .onChange(of: crashReporter) { _ in
                                
                            }
                    }
                }, header: {
                    Text(NSLocalizedString("_privacy_", comment: ""))
                }, footer: {
                    Text(NSLocalizedString("_privacy_footer_", comment: ""))
                        .font(.system(size: 12))
                        .multilineTextAlignment(.leading)
                })
            }
            
            
            // Section: Diagnostic
            if FileManager.default.fileExists(atPath: NextcloudKit.shared.nkCommonInstance.filenamePathLog) && !NCBrandOptions.shared.disable_log {
                Section(content: {
                    
                    // View Log File
                    HStack {
                        Image("log")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(UIColor.systemGray))
                        
                        Text(NSLocalizedString("_view_log_", comment: ""))
                    }
                    .onTapGesture(perform: {
                        
                    })
                    
                    // Clear Log File
                    HStack {
                        Image("clear")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(UIColor.systemGray))
                        
                        Text(NSLocalizedString("_clear_log_", comment: ""))
                    }.onTapGesture(perform: {
                        
                    })
                }, header: {
                    Text("_diagnostics_")
                }, footer: {
                    Text("Log files contains history of all your actions on Nextcloud.")
                        .font(.system(size: 12))
                        .multilineTextAlignment(.leading)
                })
                
                
                // Set Log Level() & Capabilities
                
                Section {
                    
                    Picker("Set Log Level", selection: $selectedLogLevel) {
                        Text("Disabled").tag(LogLevel.disabled)
                        Text("Standard").tag(LogLevel.standard)
                        Text("Maximum").tag(LogLevel.maximum)
                    }.onChange(of: selectedLogLevel) { newValue in
                        
                    }
                    
                    HStack {
                        Image("capabilities")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 18, height: 18)
                            .foregroundColor(Color(UIColor.systemGray))
                        
                        Text(NSLocalizedString("_capabilities_", comment: ""))
                    }
                    .onTapGesture {
                        
                    }
                }
            }
            
            
            // Delete in Cache & Clear Cache
            Section(content: {
                // TODO: changing the section text to "Auto Delete"
                Picker("Auto Delete files older than", selection: $selectedInterval) {
                    ForEach(CacheDeletionInterval.allCases) { interval in
                        Text(interval.rawValue).tag(interval)
                    }
                }.pickerStyle(.automatic)
                    .onChange(of: selectedInterval) { newValue in
                        
                    }
                
                HStack {
                    Image("trash")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 22, height: 20)
                        .foregroundColor(Color(UIColor.systemRed))
                    
                    Text(NSLocalizedString("_clear_cache_", comment: ""))
                }
                .alert(NSLocalizedString("_want_delete_cache_", comment: ""), isPresented: $showCacheAlert) {
                    Button(NSLocalizedString("_yes_", comment: ""), role: .destructive) {
                        
                    }
                    Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) { }
                }
                .onTapGesture(perform: {
                    showCacheAlert.toggle()
                })
                
            },  header: {
                Text("FREE UP SPACE")
            }, footer: {
                Text(footerTitle)
                    .font(.system(size: 12))
                    .multilineTextAlignment(.leading)
            })
            
            
            // Reset Application
            Section(content: {
                
                HStack {
                    Image("xmark")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 22, height: 20)
                        .foregroundColor(Color(UIColor.systemRed))
                    
                    Text(NSLocalizedString("_exit_", comment: ""))
                        .foregroundColor(Color(UIColor.systemRed))
                }
                .alert(NSLocalizedString("_want_exit_", comment: ""), isPresented: $showExitAlert) {
                    Button(NSLocalizedString("_ok_", comment: ""), role: .destructive) {
                        
                    }
                    Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) { }
                }
                .onTapGesture(perform: {
                    showExitAlert.toggle()
                })
            }, footer: {
                Text(NSLocalizedString("_exit_footer_", comment: ""))
                    .font(.system(size: 12))
                    .multilineTextAlignment(.leading)
            })
        }.navigationBarTitle("Advanced")
            .onAppear(perform: {
                
            })
        
    }
}

#Preview {
    CCSettingsAdvanced(showHiddenFiles: false, mostCompatible: false, livePhoto: false, removeFromCameraRoll: false, appIntegration: false, crashReporter: false, showExitAlert: false, showCacheAlert: false, selectedLogLevel: .disabled, selectedInterval: .oneWeek, footerTitle: "Hello")
}

/// An enum that represents the level of the log
enum LogLevel: Int, Equatable {
    /// Represents that logging is disabled
    case disabled = 0
    /// Represents standard logging level
    case standard = 1
    /// Represents maximum logging level
    case maximum = 2
}

/// An enum that represents the intervals for cache deletion
enum CacheDeletionInterval: String, CaseIterable, Identifiable {
    case never = "Never"
    case oneYear = "1 Year"
    case sixMonths = "6 Months"
    case threeMonths = "3 Months"
    case oneMonth = "1 Month"
    case oneWeek = "1 Week"
    
    /// Unique identifier for each case, using the raw value
    var id: String { self.rawValue }
}
