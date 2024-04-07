//
//  CCSettingsAdvanced.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 08/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Aditya Tyagi <adityagi02@yahoo.com>
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

struct CCSettingsAdvanced<ViewModel: CCSettingsAdvancedViewModel>: View {
    @ObservedObject var viewModel: ViewModel
    
    /// State variable for indicating whether the exit alert is shown.
    @State var showExitAlert: Bool = false
    /// State variable for indicating whether the cache alert is shown.
    @State var showCacheAlert: Bool = false
    
    var body: some View {
        
        Form {
            
            // Show Hidden Files
            Section(content: {
                Toggle(NSLocalizedString("_show_hidden_files_", comment: ""), isOn: $viewModel.showHiddenFiles)
                    .onChange(of: viewModel.showHiddenFiles) { _ in
                        viewModel.updateShowHiddenFiles()
                    }
            }, footer: {
                Text("All Hidden files will be visible in every device")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.leading)
            })
            
            
            // Most Compatible & Enable Live Photo
            Section(content: {
                Toggle(NSLocalizedString("_format_compatibility_", comment: ""), isOn: $viewModel.mostCompatible)
                    .onChange(of: viewModel.mostCompatible) { _ in
                        viewModel.updateMostCompatible()
                    }
                
                Toggle(NSLocalizedString("_upload_mov_livephoto_", comment: ""), isOn: $viewModel.livePhoto)
                    .onChange(of: viewModel.livePhoto) { _ in
                        viewModel.updateLivePhoto()
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
                Toggle(NSLocalizedString("_remove_photo_CameraRoll_", comment: ""), isOn: $viewModel.removeFromCameraRoll)
                    .onChange(of: viewModel.removeFromCameraRoll) { _ in
                        viewModel.updateRemoveFromCameraRoll()
                    }
                
            }, footer: {
                Text(NSLocalizedString("_remove_photo_CameraRoll_desc_", comment: ""))
                    .font(.system(size: 12))
                    .multilineTextAlignment(.leading)
            })
            
            
            // Section : Files App
            if !NCBrandOptions.shared.disable_openin_file {
                Section(content: {
                    Toggle(NSLocalizedString("_disable_files_app_", comment: ""), isOn: $viewModel.appIntegration)
                        .onChange(of: viewModel.appIntegration) { _ in
                            viewModel.updateAppIntegration()
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
                        
                        Toggle(NSLocalizedString("_crashservice_title_", comment: ""), isOn: $viewModel.crashReporter)
                            .onChange(of: viewModel.crashReporter) { _ in
                                viewModel.updateCrashReporter()
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
                        viewModel.viewLogFile()
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
                        viewModel.clearLogFile()
                    })
                    .alert("Log file cleared successfully!", isPresented: $viewModel.logFileCleared) {
                        Button(NSLocalizedString("OK", comment: ""), role: .cancel) { }
                    }
                    
                    
                }, header: {
                    Text("_diagnostics_")
                }, footer: {
                    Text("Log files contains history of all your actions on Nextcloud.")
                        .font(.system(size: 12))
                        .multilineTextAlignment(.leading)
                })
                
                
                // Set Log Level() & Capabilities
                Section {
                    Picker("Set Log Level", selection: $viewModel.selectedLogLevel) {
                        ForEach(LogLevel.allCases){ level in
                            Text(level.displayText).tag(level)
                        }
                    }.onChange(of: viewModel.selectedLogLevel) { newValue in
                        viewModel.updateSelectedLogLevel()
                    }
                    
                    NavigationLink(destination: NCCapabilitiesView(capabilitiesStatus: NCCapabilitiesViewOO())) {
                        HStack {
                            Image("capabilities")
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 18, height: 18)
                                .foregroundColor(Color(UIColor.systemGray))
                            
                            Text(NSLocalizedString("_capabilities_", comment: ""))
                        }
                    }
                }
            }
            
            
            // Delete in Cache & Clear Cache
            Section(content: {
                // TODO: changing the section text to "Auto Delete Cache files after"
                Picker("Auto Delete Cache files after", selection: $viewModel.selectedInterval) {
                    ForEach(CacheDeletionInterval.allCases) { interval in
                        Text(interval.displayText).tag(interval)
                    }
                }.pickerStyle(.automatic)
                    .onChange(of: viewModel.selectedInterval) { newValue in
                        viewModel.updateSelectedInterval()
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
                        viewModel.clearAllCacheRequest()
                    }
                    Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) { }
                }
                .onTapGesture(perform: {
                    showCacheAlert.toggle()
                })
                
            },  header: {
                Text(NSLocalizedString("_delete_files_desc_", comment: ""))
            }, footer: {
                Text(viewModel.footerTitle)
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
                        viewModel.exitNextCloud(exit: showExitAlert)
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
            .onAppear {
                viewModel.onViewAppear()
            }
    }
}

#Preview {
    CCSettingsAdvanced(viewModel: CCSettingsAdvancedViewModel(), showExitAlert: false, showCacheAlert: false)
}
