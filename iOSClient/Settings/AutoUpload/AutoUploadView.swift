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
    
    /// A state variable that indicates whether auto upload is enabled or not
    @State var autoUpload: Bool = true
    
    /// A state variable that indicates whether auto upload for photos is enabled or not
    @State var autoUploadImage: Bool = false
    /// A state variable that indicates whether auto upload for photos is restricted to Wi-Fi only or not
    @State var autoUploadWWAnPhoto: Bool = false
    
    /// A state variable that indicates whether auto upload for videos is enabled or not
    @State var autoUploadVideo: Bool = false
    /// A state variable that indicates whether auto upload for videos is restricted to Wi-Fi only or not
    @State var autoUploadWWAnVideo: Bool = false
    
    /// A state variable that indicates whether auto upload for full resolution photos is enabled or not
    @State var autoUploadFull: Bool = false
    /// A state variable that indicates whether auto upload creates subfolders based on date or not
    @State var autoUploadCreateSubfolder: Bool = false
    
    /// A state variable that indicates the granularity of the subfolders, either daily, monthly, or yearly
    @State var autoUploadSubfolderGranularity: Granularity = .daily
    
    var body: some View {
        Form {
            
            // Auto Upload
            Section(content: {
                Toggle(NSLocalizedString("_autoupload_", comment: ""), isOn: $autoUpload)
                    .onChange(of: autoUpload) { newValue in
                        
                    }
            }, footer: {
                Text(NSLocalizedString("_autoupload_description_", comment: ""))
            })
            
            
            /// If `autoUpload` state will be true, we will animate out the whole `autoUploadOnView` section
            if autoUpload {
                autoUploadOnView
                    .animation(.easeInOut)
            }
            
        }
        .navigationBarTitle("Auto Upload")
        .transition(.slide)
        .onAppear {
            
        }
    }
    
    @ViewBuilder
    var autoUploadOnView: some View {
        
        // Auto Upload Directory
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
            Text("Currently selected folder: ")
        })
        
        
        // Auto Upload Photo
        Section(content: {
            Toggle(NSLocalizedString("_autoupload_photos_", comment: ""), isOn: $autoUploadImage)
                .onChange(of: autoUploadImage) { newValue in
                    
                }
            Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $autoUploadWWAnPhoto)
                .onChange(of: autoUploadWWAnPhoto) { newValue in
                    
                }
        })
        
        
        // Auto Upload Video
        Section(content: {
            Toggle(NSLocalizedString("_autoupload_videos_", comment: ""), isOn: $autoUploadVideo)
                .onChange(of: autoUploadVideo) { newValue in
                    
                }
            Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $autoUploadWWAnVideo)
                .onChange(of: autoUploadWWAnVideo) { newValue in
                    
                }
        })
        
        
        // Auto Upload Full
        Section(content: {
            HStack {
                Toggle(NSLocalizedString("_autoupload_fullphotos_", comment: ""), isOn: $autoUploadFull)
                    .onChange(of: autoUploadFull) { newValue in
                        
                    }
            }
        }, footer: {
            Text("Adjust the options above before uploading")
        })
        
        
        // Auto Upload create subfolder
        Section(content: {
            Toggle(NSLocalizedString("_autoupload_create_subfolder_", comment: ""), isOn: $autoUploadCreateSubfolder)
                .onChange(of: autoUploadCreateSubfolder) { newValue in
                    
                }
            Picker(NSLocalizedString("Subfolder Granularity", comment: ""), selection: $autoUploadSubfolderGranularity) {
                Text("Daily").tag(Granularity.daily)
                Text("Monthly").tag(Granularity.monthly)
                Text("Yearly").tag(Granularity.yearly)
            }
            .onChange(of: autoUploadSubfolderGranularity) { newValue in
                autoUploadSubfolderGranularity = newValue
            }
        }, footer: {
            Text("Store in subfolders based on year, month or daily")   // TODO: My proposed string, to be verified
        })
        
        
        // Auto Upload file name
        Section(content: {
            NavigationLink(destination: EmptyView(), label: {
                Text(NSLocalizedString("_autoupload_filenamemask_", comment: ""))
            })
        }, footer: {
            Text("Change the automatic filename mask")      // TODO: My proposed string, to be verified
        })
    }
}

#Preview {
    AutoUploadView()
}


/// An enum that represents the granularity of the subfolders for auto upload
enum Granularity: Int {
    /// Daily granularity, meaning the subfolders are named by day
    case daily = 2
    /// Monthly granularity, meaning the subfolders are named by month
    case monthly = 1
    /// Yearly granularity, meaning the subfolders are named by year
    case yearly = 0
}
