//
//  AutoUploadView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 06/03/24.
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
import UIKit

/// A view that allows the user to configure the `auto upload settings for Nextcloud`
struct AutoUploadView<ViewModel: AutoUploadViewModel>: View {
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        Form {
            
            // Auto Upload
            Section(content: {
                Toggle(NSLocalizedString("_autoupload_", comment: ""), isOn: $viewModel.autoUpload)
                    .onChange(of: viewModel.autoUpload) { newValue in
                        viewModel.handleAutoUploadChange(newValue: newValue)
                    }
            }, footer: {
                Text(NSLocalizedString("_autoupload_description_", comment: ""))
            })
            
            /// If `autoUpload` state will be true, we will animate out the whole `autoUploadOnView` section
            if viewModel.autoUpload {
                autoUploadOnView
                    .animation(.easeInOut)
            }
            
        }
        .navigationBarTitle("Auto Upload")
        .defaultViewModifier(viewModel)
        .transition(.slide)
        .alert(viewModel.error, isPresented: $viewModel.showErrorAlert) {
            Button(NSLocalizedString("_ok_", comment: ""), role: .cancel) { }
        }
    }
    
    @ViewBuilder
    var autoUploadOnView: some View {
        
        Section(content: {
            HStack {
                Image("foldersOnTop")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color(UIColor.systemGray))
                
                Text(NSLocalizedString("_autoupload_select_folder_", comment: ""))
            }
        }, footer: {
            Text("\(NSLocalizedString("_autoupload_current_folder_", comment: "")): \(viewModel.returnPath())")
        }).onTapGesture {
            viewModel.autoUploadFolder.toggle()
        }
        .sheet(isPresented: $viewModel.autoUploadFolder) {
            SelectView(serverUrl: $viewModel.appDelegate.activeServerUrl)
                .onDisappear {
                    viewModel.setAutoUploadDirectory(serverUrl: viewModel.appDelegate.activeServerUrl)
                }
        }
        
        
        // Auto Upload Photo
        Section(content: {
            Toggle(NSLocalizedString("_autoupload_photos_", comment: ""), isOn: $viewModel.autoUploadImage)
                .onChange(of: viewModel.autoUploadImage) { newValue in
                    viewModel.handleAutoUploadImageChange(newValue: newValue)
                }
            Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $viewModel.autoUploadWWAnPhoto)
                .onChange(of: viewModel.autoUploadWWAnPhoto) { newValue in
                    viewModel.handleAutoUploadWWAnPhotoChange(newValue: newValue)
                }
        })
        
        
        // Auto Upload Video
        Section(content: {
            Toggle(NSLocalizedString("_autoupload_videos_", comment: ""), isOn: $viewModel.autoUploadVideo)
                .onChange(of: viewModel.autoUploadVideo) { newValue in
                    viewModel.handleAutoUploadVideoChange(newValue: newValue)
                }
            Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $viewModel.autoUploadWWAnVideo)
                .onChange(of: viewModel.autoUploadWWAnVideo) { newValue in
                    viewModel.handleAutoUploadWWAnVideoChange(newValue: newValue)
                }
        })
        
        
        // Auto Upload Full
        Section(content: {
            HStack {
                Toggle(NSLocalizedString("_autoupload_fullphotos_", comment: ""), isOn: $viewModel.autoUploadFull)
                    .onChange(of: viewModel.autoUploadFull) { newValue in
                        viewModel.handleAutoUploadFullChange(newValue: newValue)
                    }
            }
        }, footer: {
            Text(NSLocalizedString("_autoupload_fullphotos_footer_", comment: ""))
        })
        
        
        // Auto Upload create subfolder
        Section(content: {
            Toggle(NSLocalizedString("_autoupload_create_subfolder_", comment: ""), isOn: $viewModel.autoUploadCreateSubfolder)
                .onChange(of: viewModel.autoUploadCreateSubfolder) { newValue in
                    viewModel.handleAutoUploadCreateSubfolderChange(newValue: newValue)
                }
            Picker(NSLocalizedString("Subfolder Granularity", comment: ""), selection: $viewModel.autoUploadSubfolderGranularity) {
                Text(NSLocalizedString("_daily_", comment: "")).tag(Granularity.daily)
                Text(NSLocalizedString("_monthly_", comment: "")).tag(Granularity.monthly)
                Text(NSLocalizedString("_yearly_", comment: "")).tag(Granularity.yearly)
            }
            .onChange(of: viewModel.autoUploadSubfolderGranularity) { newValue in
                viewModel.handleAutoUploadSubfolderGranularityChange(newValue: newValue)
            }
        }, footer: {
            Text(NSLocalizedString("_autoupload_create_subfolder_footer_", comment: ""))
        })
        
        
        // Auto Upload file name
        Section(content: {
            NavigationLink(destination: AutoUploadFileNamesView(viewModel: AutoUploadFileNamesViewModel()), label: {
                Text(NSLocalizedString("_autoupload_filenamemask_", comment: ""))
            })
        }, footer: {
            Text(NSLocalizedString("_autoupload_filenamemask_footer_", comment: ""))
        })
    }
}

#Preview {
    AutoUploadView(viewModel: AutoUploadViewModel())
}


