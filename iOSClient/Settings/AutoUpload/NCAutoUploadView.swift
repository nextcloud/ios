//
//  NCAutoUploadView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 06/03/24.
//  Created by Marino Faggiana on 30/05/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//  Copyright © 2024 STRATO GmbH
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
    @State private var showUploadFolder = false
    @State private var showSelectAlbums = false
    @State private var showUploadAllPhotosWarning = false
    @State private var startAutoUpload = false

    var body: some View {
        ZStack {
            if model.photosPermissionsGranted {
                autoUploadOnView
            } else {
                noPermissionsView
            }
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
                    model.resetAutoUploadLastUploadedDate()
                }
        }
        .sheet(isPresented: $showSelectAlbums) {
            SelectAlbumView(model: albumModel)
        }
        .alert(NSLocalizedString("_auto_upload_all_photos_warning_title_", comment: ""), isPresented: $showUploadAllPhotosWarning, actions: {
            Button("_confirm_") {
                model.autoUploadStart = true
            }
            Button("_cancel_", role: .cancel) {
                model.autoUploadStart = false
            }
        }, message: {
            Text("_auto_upload_all_photos_warning_message_")
        })
        .tint(.primary)
    }

    @ViewBuilder
    var autoUploadOnView: some View {
        Form {
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
				.applyGlobalFormSectionStyle()

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
					.applyGlobalFormSectionStyle()

                    Toggle(NSLocalizedString("_back_up_new_photos_only_", comment: ""), isOn: $model.autoUploadNewPhotosOnly)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .onChange(of: model.autoUploadNewPhotosOnly) { newValue in
                            model.handleAutoUploadNewPhotosOnly(newValue: newValue)
                        }
                        .accessibilityIdentifier("NewPhotosToggle")
                }, footer: {
                    if model.autoUploadNewPhotosOnly == true, let date = model.autoUploadSinceDate {
                        Text(String(format: NSLocalizedString("_new_photos_starting_", comment: ""), NCUtility().longDate(date)))
                    }
                })
				.applyGlobalFormSectionStyle()

                /// Auto Upload Photo
                Section(content: {
                    Toggle(NSLocalizedString("_autoupload_photos_", comment: ""), isOn: $model.autoUploadImage)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .onChange(of: model.autoUploadImage) { newValue in
                            if !newValue { model.autoUploadVideo = true }
                            model.handleAutoUploadImageChange(newValue: newValue)
                        }

                    if model.autoUploadImage {
                        Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $model.autoUploadWWAnPhoto)
                            .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                            .onChange(of: model.autoUploadWWAnPhoto) { newValue in
                                model.handleAutoUploadWWAnPhotoChange(newValue: newValue)
                            }
                    }
                })
				.applyGlobalFormSectionStyle()

                /// Auto Upload Video
                Section(content: {
                    Toggle(NSLocalizedString("_autoupload_videos_", comment: ""), isOn: $model.autoUploadVideo)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .onChange(of: model.autoUploadVideo) { newValue in
                            if !newValue { model.autoUploadImage = true }
                            model.handleAutoUploadVideoChange(newValue: newValue)
                        }

                    if model.autoUploadVideo {
                        Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $model.autoUploadWWAnVideo)
                            .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                            .onChange(of: model.autoUploadWWAnVideo) { newValue in
                                model.handleAutoUploadWWAnVideoChange(newValue: newValue)
                            }
                    }
                })
				.applyGlobalFormSectionStyle()

                /// Auto Upload create subfolder
                Section(content: {
                    Toggle(NSLocalizedString("_autoupload_create_subfolder_", comment: ""), isOn: $model.autoUploadCreateSubfolder)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .onChange(of: model.autoUploadCreateSubfolder) { newValue in
                            model.handleAutoUploadCreateSubfolderChange(newValue: newValue)
                        }

                    if model.autoUploadCreateSubfolder {
                        Picker(NSLocalizedString("_autoupload_subfolder_granularity_", comment: ""), selection: $model.autoUploadSubfolderGranularity) {
                            Text(NSLocalizedString("_daily_", comment: "")).tag(Granularity.daily)
                            Text(NSLocalizedString("_monthly_", comment: "")).tag(Granularity.monthly)
                            Text(NSLocalizedString("_yearly_", comment: "")).tag(Granularity.yearly)
                        }
                        .onChange(of: model.autoUploadSubfolderGranularity) { newValue in
                            model.handleAutoUploadSubfolderGranularityChange(newValue: newValue)
                        }
                    }
                }, footer: {
                    Text(NSLocalizedString("_autoupload_create_subfolder_footer_", comment: ""))
                })
				.applyGlobalFormSectionStyle()

            }
            .disabled(model.autoUploadStart)

            /// Auto Upload Full
            Section(content: {
#if DEBUG
                Button("[DEBUG] Reset last uploaded date") {
                    model.resetAutoUploadLastUploadedDate()
                }.buttonStyle(.borderedProminent)
					.foregroundStyle(Color(NCBrandColor.shared.customer))
#endif

                Toggle(isOn: model.autoUploadNewPhotosOnly || model.autoUploadStart ? $model.autoUploadStart : $showUploadAllPhotosWarning) {
                    Text(model.autoUploadStart ? "_stop_autoupload_" : "_start_autoupload_")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                .onChange(of: model.autoUploadStart) { newValue in
                    albumModel.populateSelectedAlbums()
                    model.handleAutoUploadChange(newValue: newValue, assetCollections: albumModel.selectedAlbums)
                }
                .font(.headline)
                .toggleStyle(.button)
                .buttonStyle(.bordered)
            }, footer: {
                Text(NSLocalizedString("_autoupload_notice_", comment: ""))
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .listRowInsets(EdgeInsets())
			.background(Color(NCBrandColor.shared.formBackgroundColor))
        }
		.applyGlobalFormStyle()
    }
}

@ViewBuilder
var noPermissionsView: some View {
    VStack {
        Text("_access_photo_not_enabled_").font(.title3)
            .padding()
        Text("_access_photo_not_enabled_msg_")
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview {
    NCAutoUploadView(model: NCAutoUploadModel(controller: nil), albumModel: AlbumModel(controller: nil))
}
