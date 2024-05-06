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
struct AutoUploadView: View {
    @ObservedObject var model: AutoUploadModel
    var body: some View {
        Form {
            // Auto Upload
            Section(content: {
                Toggle(NSLocalizedString("_autoupload_", comment: ""), isOn: $model.autoUpload)
                    .onChange(of: model.autoUpload) { newValue in
                        model.handleAutoUploadChange(newValue: newValue)
                    }
                    .font(.system(size: 16))
            }, footer: {
                Text(NSLocalizedString("_autoupload_description_", comment: ""))
            })
            /// If `autoUpload` state will be true, we will animate out the whole `autoUploadOnView` section
            if model.autoUpload {
                autoUploadOnView
                    .animation(.easeInOut)
            }
        }
        .navigationBarTitle(NSLocalizedString("_auto_upload_", comment: ""))
        .onAppear {
            model.onViewAppear()
        }
        .alert(model.error, isPresented: $model.showErrorAlert) {
            Button(NSLocalizedString("_ok_", comment: ""), role: .cancel) { }
        }
    }
    @ViewBuilder
    var autoUploadOnView: some View {
        Section(content: {
            Button(action: {
                model.autoUploadFolder.toggle()
            }, label: {
                HStack {
                    Image("foldersOnTop")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("_autoupload_select_folder_", comment: ""))
                }
                .font(.system(size: 16))
            })
            .tint(Color(UIColor.label))
        }, footer: {
            Text("\(NSLocalizedString("_autoupload_current_folder_", comment: "")): \(model.returnPath())")
        })
        .sheet(isPresented: $model.autoUploadFolder) {
            SelectView(serverUrl: $model.serverUrl)
                .onDisappear {
                    model.setAutoUploadDirectory(serverUrl: model.serverUrl)
                }
        }
        // Auto Upload Photo
        Section(content: {
            Toggle(NSLocalizedString("_autoupload_photos_", comment: ""), isOn: $model.autoUploadImage)
                .onChange(of: model.autoUploadImage) { newValue in
                    model.handleAutoUploadImageChange(newValue: newValue)
                }
                .font(.system(size: 16))
            Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $model.autoUploadWWAnPhoto)
                .onChange(of: model.autoUploadWWAnPhoto) { newValue in
                    model.handleAutoUploadWWAnPhotoChange(newValue: newValue)
                }
                .font(.system(size: 16))
        })
        // Auto Upload Video
        Section(content: {
            Toggle(NSLocalizedString("_autoupload_videos_", comment: ""), isOn: $model.autoUploadVideo)
                .onChange(of: model.autoUploadVideo) { newValue in
                    model.handleAutoUploadVideoChange(newValue: newValue)
                }
                .font(.system(size: 16))
            Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $model.autoUploadWWAnVideo)
                .onChange(of: model.autoUploadWWAnVideo) { newValue in
                    model.handleAutoUploadWWAnVideoChange(newValue: newValue)
                }
                .font(.system(size: 16))
        })
        // Auto Upload Full
        Section(content: {
            Toggle(NSLocalizedString("_autoupload_fullphotos_", comment: ""), isOn: $model.autoUploadFull)
                .onChange(of: model.autoUploadFull) { newValue in
                    model.handleAutoUploadFullChange(newValue: newValue)
                }
                .font(.system(size: 16))
        }, footer: {
            Text(NSLocalizedString("_autoupload_fullphotos_footer_", comment: ""))
        })
        // Auto Upload create subfolder
        Section(content: {
            Toggle(NSLocalizedString("_autoupload_create_subfolder_", comment: ""), isOn: $model.autoUploadCreateSubfolder)
                .onChange(of: model.autoUploadCreateSubfolder) { newValue in
                    model.handleAutoUploadCreateSubfolderChange(newValue: newValue)
                }
                .font(.system(size: 16))
            Picker(NSLocalizedString("_autoupload_subfolder_granularity_", comment: ""), selection: $model.autoUploadSubfolderGranularity) {
                Text(NSLocalizedString("_daily_", comment: "")).tag(Granularity.daily)
                Text(NSLocalizedString("_monthly_", comment: "")).tag(Granularity.monthly)
                Text(NSLocalizedString("_yearly_", comment: "")).tag(Granularity.yearly)
            }
            .font(.system(size: 16))
            .onChange(of: model.autoUploadSubfolderGranularity) { newValue in
                model.handleAutoUploadSubfolderGranularityChange(newValue: newValue)
            }
        }, footer: {
            Text(NSLocalizedString("_autoupload_create_subfolder_footer_", comment: ""))
        })
        // Auto Upload file name
        Section(content: {
            NavigationLink(destination: AutoUploadFileNamesView(model: AutoUploadFileNamesModel()), label: {
                Text(NSLocalizedString("_autoupload_filenamemask_", comment: ""))
                    .font(.system(size: 16))
            })
        }, footer: {
            Text(NSLocalizedString("_autoupload_filenamemask_footer_", comment: ""))
        })
    }
}

#Preview {
    AutoUploadView(model: AutoUploadModel())
}
