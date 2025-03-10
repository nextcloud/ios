//
//  NCAutoUploadView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 06/03/24.
//  Created by Marino Faggiana on 30/05/24.
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
struct NCAutoUploadView: View {
    @StateObject var model: NCAutoUploadModel
    @StateObject var albumModel: AlbumModel
    @State private var showUploadFolder: Bool = false
    @State private var showSelectAlbums: Bool = false
    @State private var showUploadAllPhotosWarning: Bool = false
    var body: some View {
        Form {
            autoUploadOnView
        }
        .navigationBarTitle(NSLocalizedString("_auto_upload_folder_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.onViewAppear()
        }
        .alert(model.error, isPresented: $model.showErrorAlert) {
            Button(NSLocalizedString("_ok_", comment: ""), role: .cancel) { }
        }
        .sheet(isPresented: $showUploadFolder) {
            SelectView(serverUrl: $model.serverUrl, session: model.session)
                .onDisappear {
                    model.setAutoUploadDirectory(serverUrl: model.serverUrl)
                }
        }
        .sheet(isPresented: $showSelectAlbums) {
            SelectAlbumView(model: albumModel)
        }
        
        .alert("_auto_upload_all_photos_warning_title_", isPresented: $showUploadAllPhotosWarning, actions: {
            Button("_confirm_") {
                albumModel.populateSelectedAlbums()
                model.handleAutoUploadChange(newValue: true, assetCollections: albumModel.selectedAlbums)
            }
            Button("_cancel_", role: .cancel) {
                model.autoUploadStart = false
            }
        }, message: {
            Text("_auto_upload_all_photos_warning_message_")
        })
        .onChange(of: model.autoUploadTimespan) { newValue in
            model.handleAutoUploadTimespanChange(newValue: newValue)
        }
        .tint(.primary)
    }
    
    @ViewBuilder
    var autoUploadOnView: some View {
        Group {
            Section(content: {
                Button(action: {
                    showUploadFolder.toggle()
                }, label: {
                    HStack {
                        Image(systemName: "folder")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                        Text(NSLocalizedString("_destination_", comment: ""))
                        Text(model.returnPath())
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                })
            })
            
            Section(content: {
                NavigationLink(destination: SelectAlbumView(model: albumModel)) {
                    Button(action: {
                        showSelectAlbums.toggle()
                    }, label: {
                        HStack {
                            Image(systemName: "person.2.crop.square.stack")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 25)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                            Text("\(NSLocalizedString("_upload_from_", comment: "")):")
                            Text(NSLocalizedString(model.createAlbumTitle(autoUploadAlbumIds: albumModel.autoUploadAlbumIds), comment: ""))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    })
                }
                
                Picker("_back_up_", selection: $model.autoUploadTimespan) {
                    ForEach(AutoUploadTimespan.allCases) { when in
                        Text(NSLocalizedString(when.rawValue, comment: ""))
                            .tag(when)
                    }
                }
                .pickerStyle(.menu)
            }, footer: {
                if model.autoUploadTimespan == .newPhotosOnly, let date = model.autoUploadDate {
                    Text("New photos since \(NCUtility().longDate(date))")
                }
            })
            
            /// Auto Upload Photo
            Section(content: {
                Toggle(NSLocalizedString("_autoupload_photos_", comment: ""), isOn: $model.autoUploadImage)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.autoUploadImage) { newValue in
                        if !newValue { model.autoUploadVideo = true }
                        model.handleAutoUploadImageChange(newValue: newValue)
                    }
                Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $model.autoUploadWWAnPhoto)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.autoUploadWWAnPhoto) { newValue in
                        model.handleAutoUploadWWAnPhotoChange(newValue: newValue)
                    }
            })
            /// Auto Upload Video
            Section(content: {
                Toggle(NSLocalizedString("_autoupload_videos_", comment: ""), isOn: $model.autoUploadVideo)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.autoUploadVideo) { newValue in
                        if !newValue { model.autoUploadImage = true }
                        model.handleAutoUploadVideoChange(newValue: newValue)
                    }
                Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $model.autoUploadWWAnVideo)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.autoUploadWWAnVideo) { newValue in
                        model.handleAutoUploadWWAnVideoChange(newValue: newValue)
                    }
            })
            
            /// Auto Upload create subfolder
            Section(content: {
                Toggle(NSLocalizedString("_autoupload_create_subfolder_", comment: ""), isOn: $model.autoUploadCreateSubfolder)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.autoUploadCreateSubfolder) { newValue in
                        model.handleAutoUploadCreateSubfolderChange(newValue: newValue)
                    }
                Picker(NSLocalizedString("_autoupload_subfolder_granularity_", comment: ""), selection: $model.autoUploadSubfolderGranularity) {
                    Text(NSLocalizedString("_daily_", comment: "")).tag(Granularity.daily)
                    Text(NSLocalizedString("_monthly_", comment: "")).tag(Granularity.monthly)
                    Text(NSLocalizedString("_yearly_", comment: "")).tag(Granularity.yearly)
                }
                .onChange(of: model.autoUploadSubfolderGranularity) { newValue in
                    model.handleAutoUploadSubfolderGranularityChange(newValue: newValue)
                }
            }, footer: {
                Text(NSLocalizedString("_autoupload_create_subfolder_footer_", comment: ""))
            })
        }
        .disabled(model.autoUploadStart)
        
        /// Auto Upload Full
        Section(content: {
            Toggle(isOn: $model.autoUploadStart) {
                Text(model.autoUploadStart ? "_stop_autoupload_" : "_start_autoupload_")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
            .onChange(of: model.autoUploadStart) { newValue in
                if newValue && model.autoUploadTimespan == .allPhotos {
                    showUploadAllPhotosWarning = true
                } else {
                    albumModel.populateSelectedAlbums()
                    model.handleAutoUploadChange(newValue: newValue, assetCollections: albumModel.selectedAlbums)
                }
            }
            .font(.headline)
            .toggleStyle(.button)
            .buttonStyle(.bordered)
        }, footer: {
            Text(NSLocalizedString("_autoupload_notice_", comment: ""))
                .padding(.vertical, 20)
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .listRowInsets(EdgeInsets())
        .background(Color(UIColor.systemGroupedBackground))
    }
}

#Preview {
    NCAutoUploadView(model: NCAutoUploadModel(controller: nil), albumModel: AlbumModel(controller: nil))
}
