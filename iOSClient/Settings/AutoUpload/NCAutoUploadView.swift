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

    var body: some View {
        VStack {
            Form {
                /// Auto Upload
                Section(content: {
                    Toggle(NSLocalizedString("_autoupload_", comment: ""), isOn: $model.autoUpload)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .onChange(of: model.autoUpload) { newValue in
                            model.handleAutoUploadChange(newValue: newValue)
                            albumModel.initAlbums()
                        }
                }, footer: {
                    Text(NSLocalizedString("_autoupload_notice_", comment: ""))
                })
                /// If `autoUpload` state will be true, we will animate out the whole `autoUploadOnView` section
                if model.autoUpload {
                    autoUploadOnView
                        .transition(.slide)
                        .animation(.easeInOut, value: model.autoUpload)
                }
            }
            .navigationBarTitle(NSLocalizedString("_auto_upload_folder_", comment: ""))
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
            .tint(.primary)
        }
    }

    @ViewBuilder
    var autoUploadOnView: some View {
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
                    Text(NSLocalizedString("_autoupload_select_folder_", comment: ""))
                }
            })
        }, footer: {
            Text("\(NSLocalizedString("_autoupload_current_folder_", comment: "")): \(model.returnPath())")
        })

        Group {
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
                            Text(NSLocalizedString("_upload_from_", comment: ""))
                            Text(NSLocalizedString(model.createAlbumTitle(autoUploadAlbumIds: albumModel.autoUploadAlbumIds), comment: ""))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    })
                }
            })

            /// Auto Upload Photo
            Section(content: {
                Toggle(NSLocalizedString("_autoupload_photos_", comment: ""), isOn: $model.autoUploadImage)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.autoUploadImage) { newValue in
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
                        model.handleAutoUploadVideoChange(newValue: newValue)
                    }
                Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $model.autoUploadWWAnVideo)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.autoUploadWWAnVideo) { newValue in
                        model.handleAutoUploadWWAnVideoChange(newValue: newValue)
                    }
            })
            /// Only upload favorites if desired
            Section(content: {
                Toggle(NSLocalizedString("_autoupload_favorites_", comment: ""), isOn: $model.autoUploadFavoritesOnly)
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .onChange(of: model.autoUploadFavoritesOnly) { newValue in
                        model.handleAutoUploadFavoritesOnlyChange(newValue: newValue)
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
        .disabled(model.autoUploadFull)

        /// Auto Upload Full
        Section(content: {
            Toggle(isOn: $model.autoUploadFull) {
                Text(model.autoUploadFull ? "_stop_autoupload_" : "_start_autoupload_")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
            .onChange(of: model.autoUploadFull) { newValue in
                albumModel.populateSelectedAlbums()
                model.handleAutoUploadChange(newValue: newValue, assetCollections: albumModel.selectedAlbums)
            }
            .font(.headline)
            .toggleStyle(.button)
            .buttonStyle(.bordered)
        }, footer: {
            Text(NSLocalizedString("_autoupload_fullphotos_footer_", comment: "") + "\n \n")
                .padding(5)
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .listRowInsets(EdgeInsets())
        .background(Color(UIColor.systemGroupedBackground))
    }
}

#Preview {
    NCAutoUploadView(model: NCAutoUploadModel(controller: nil), albumModel: AlbumModel(controller: nil))
}
