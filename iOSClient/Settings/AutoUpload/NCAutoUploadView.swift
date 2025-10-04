// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Aditya Tyagi
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

/// A view that allows the user to configure the `auto upload settings for Nextcloud`
struct NCAutoUploadView: View {
    @State private var reachedAnchor = false

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
        .onDisappear {
            model.onViewDisappear()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            model.checkPermission()
        }
        .alert(model.error, isPresented: $model.showErrorAlert) {
            Button(NSLocalizedString("_ok_", comment: ""), role: .cancel) { }
        }
        .sheet(isPresented: $showUploadFolder) {
            SelectView(serverUrl: $model.serverUrl, includeDirectoryE2EEncryption: false, session: model.session)
                .onDisappear {
                    model.setAutoUploadDirectory(serverUrl: model.serverUrl)
                }
        }
        .sheet(isPresented: $showSelectAlbums) {
            SelectAlbumView(model: albumModel)
        }
        .sheet(isPresented: $showUploadAllPhotosWarning) {
            ConfirmAutoUploadSheet(model: model, isPresented: $showUploadAllPhotosWarning)
            .presentationDetents([.medium, .large])
        }
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
                                .opacity(model.autoUploadStart ? 0.15 : 1)
                            Text(NSLocalizedString("_destination_", comment: ""))
                                .opacity(model.autoUploadStart ? 0.5 : 1)
                            Text(model.returnPath())
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .opacity(model.autoUploadStart ? 0.5 : 1)
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
                                    .opacity(model.autoUploadStart ? 0.3 : 1)
                                Text(NSLocalizedString("_upload_from_", comment: ""))
                                Text(NSLocalizedString(model.createAlbumTitle(autoUploadAlbumIds: albumModel.autoUploadAlbumIds), comment: ""))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        })
                    }

                    Toggle(NSLocalizedString("_back_up_new_photos_only_", comment: ""), isOn: Binding(
                        get: {
                            model.autoUploadSinceDate != nil
                        },
                        set: { newValue in
                            model.handleAutoUploadOnlyNew(newValue: newValue)
                        }
                    ))
                    .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .opacity(model.autoUploadStart ? 0.15 : 1)
                    .accessibilityIdentifier("NewPhotosToggle")
                }, footer: {
                    if let date = model.autoUploadSinceDate {
                        Text(String(format: NSLocalizedString("_new_photos_starting_", comment: ""), NCUtility().longDate(date)))
                    }
                })

                // Auto Upload Photo
                Section(content: {
                    Toggle(NSLocalizedString("_autoupload_photos_", comment: ""), isOn: $model.autoUploadImage)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .opacity(model.autoUploadStart ? 0.15 : 1)
                        .onChange(of: model.autoUploadImage) { _, newValue in
                            if !newValue { model.autoUploadVideo = true }
                            model.handleAutoUploadImageChange(newValue: newValue)
                        }

                    if model.autoUploadImage {
                        Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $model.autoUploadWWAnPhoto)
                            .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                            .opacity(model.autoUploadStart ? 0.15 : 1)
                            .onChange(of: model.autoUploadWWAnPhoto) { _, newValue in
                                model.handleAutoUploadWWAnPhotoChange(newValue: newValue)
                            }
                    }
                })

                // Auto Upload Video
                Section(content: {
                    Toggle(NSLocalizedString("_autoupload_videos_", comment: ""), isOn: $model.autoUploadVideo)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .opacity(model.autoUploadStart ? 0.15 : 1)
                        .onChange(of: model.autoUploadVideo) { _, newValue in
                            if !newValue { model.autoUploadImage = true }
                            model.handleAutoUploadVideoChange(newValue: newValue)
                        }

                    if model.autoUploadVideo {
                        Toggle(NSLocalizedString("_wifi_only_", comment: ""), isOn: $model.autoUploadWWAnVideo)
                            .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                            .opacity(model.autoUploadStart ? 0.15 : 1)
                            .onChange(of: model.autoUploadWWAnVideo) { _, newValue in
                                model.handleAutoUploadWWAnVideoChange(newValue: newValue)
                            }
                    }
                })

                // Auto Upload create subfolder
                Section(content: {
                    Toggle(NSLocalizedString("_autoupload_create_subfolder_", comment: ""), isOn: $model.autoUploadCreateSubfolder)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .opacity(model.autoUploadStart ? 0.15 : 1)
                        .onChange(of: model.autoUploadCreateSubfolder) { _, newValue in
                            model.handleAutoUploadCreateSubfolderChange(newValue: newValue)
                        }

                    if model.autoUploadCreateSubfolder {
                        Picker(NSLocalizedString("_autoupload_subfolder_granularity_", comment: ""), selection: $model.autoUploadSubfolderGranularity) {
                            Text(NSLocalizedString("_daily_", comment: "")).tag(Granularity.daily)
                            Text(NSLocalizedString("_monthly_", comment: "")).tag(Granularity.monthly)
                            Text(NSLocalizedString("_yearly_", comment: "")).tag(Granularity.yearly)
                        }
                        .opacity(model.autoUploadStart ? 0.15 : 1)
                        .onChange(of: model.autoUploadSubfolderGranularity) { _, newValue in
                            model.handleAutoUploadSubfolderGranularityChange(newValue: newValue)
                        }
                    }
                }, footer: {
                    Text(NSLocalizedString("_autoupload_create_subfolder_footer_", comment: ""))
                })

                // Location
                Section(content: {
                    Toggle(NSLocalizedString("_enable_background_location_title_", comment: ""), isOn: $model.permissionGranted)
                        .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        .opacity(model.autoUploadStart ? 0.15 : 1)
                        .onChange(of: model.permissionGranted) { _, newValue in
                            model.handleLocationChange(newValue: newValue)
                        }
                }, footer: {
                    Text(NSLocalizedString("_enable_background_location_footer_", comment: ""))
                })
            }
            .disabled(model.autoUploadStart)
        }
        .safeAreaInset(edge: .bottom) {
            autoUploadStartButton
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    var autoUploadStartButton: some View {
        Section(content: {
            let toggle = Toggle(isOn: model.autoUploadSinceDate != nil || model.autoUploadStart ? $model.autoUploadStart : $showUploadAllPhotosWarning) {
                Text(model.autoUploadStart ? "_stop_autoupload_" : "_start_autoupload_")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .tint(Color(NCBrandColor.shared.getElement(account: model.session.account)))
            .onChange(of: model.autoUploadStart) { _, newValue in
                albumModel.populateSelectedAlbums()
                model.handleAutoUploadChange(newValue: newValue, assetCollections: albumModel.selectedAlbums)
            }
            .font(.headline)

            if #available(iOS 26.0, *) {
                toggle
                    .toggleStyle(.button)
                    .buttonStyle(.glass)
            } else {
                toggle
                    .toggleStyle(AutoUploadProminentButtonStyle(model: model))
            }
        })
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

// Custom prominent brand button style used for Toggle-as-Button
private struct AutoUploadProminentButtonStyle: ToggleStyle {
    let model: NCAutoUploadModel
    private var onBackground: Color { Color(NCBrandColor.shared.getElement(account: model.session.account)) }
    private let offBackground = Color(UIColor.systemGray5)
    private let onForeground = Color.white
    private let offForeground = Color.primary
    private let cornerRadius: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .foregroundColor(configuration.isOn ? onForeground : offForeground)
                .padding(.vertical, 10)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill((configuration.isOn ? onBackground : offBackground))
        )
        .animation(.easeOut(duration: 0.15), value: configuration.isOn)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 3)
    }
}

struct ConfirmAutoUploadSheet: View {
    @ObservedObject var model: NCAutoUploadModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(NSLocalizedString("_auto_upload_all_photos_warning_title_", comment: ""))
                .font(.headline)
                .multilineTextAlignment(.center)

            // Message
            Text(NSLocalizedString("_auto_upload_all_photos_warning_message_", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 20)

            if model.existsAutoUpload() {
                Button {
                    model.autoUploadStart = true
                    isPresented = false
                } label: {
                    Text(NSLocalizedString("_confirm_continue_", comment: ""))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.deleteAutoUploadTransfer()
                    model.autoUploadStart = true
                    isPresented = false
                } label: {
                    Text(NSLocalizedString("_confirm_resetting_", comment: ""))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                }
                .buttonStyle(.bordered)

                Spacer().frame(height: 20)

                Button(role: .cancel) {
                    model.autoUploadStart = false
                    isPresented = false
                } label: {
                    Text(NSLocalizedString("_cancel_", comment: ""))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            } else {
                Button {
                    model.autoUploadStart = true
                    isPresented = false
                } label: {
                    Text(NSLocalizedString("_confirm_", comment: ""))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Spacer().frame(height: 20)

                Button(role: .cancel) {
                    model.autoUploadStart = false
                    isPresented = false
                } label: {
                    Text(NSLocalizedString("_cancel_", comment: ""))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    NCAutoUploadView(model: NCAutoUploadModel(controller: nil), albumModel: AlbumModel(controller: nil))
}
