//
//  AutoUploadView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 06/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI

/// A view that allows the user to configure the `auto upload settings for Nextcloud`
struct AutoUploadView: View {
    @ObservedObject var viewModel = AutoUploadViewModel()
    
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
        .transition(.slide)
        .onAppear {
            if viewModel.autoUpload {
                viewModel.requestAuthorization()
            }
        }
    }
    
    @ViewBuilder
    var autoUploadOnView: some View {
        
        // TODO: Auto Upload Directory
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
            Text(NSLocalizedString("_autoupload_current_folder_", comment: ""))
        })
        
        
        
        
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
    AutoUploadView()
}
