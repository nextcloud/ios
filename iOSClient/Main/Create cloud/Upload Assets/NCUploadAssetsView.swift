//
//  NCUploadAssetsView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit

struct NCUploadAssetsView: View {
    @ObservedObject var model: NCUploadAssetsModel

    @State private var showSelect = false
    @State private var showUploadConflict = false
    @State private var showQuickLook = false
    @State private var showRenameAlert = false
    @State private var renameError = ""
    @State private var renameFileName: String = ""
    @State private var renameIndex: Int = 0
    @State private var index: Int = 0

    var metadata: tableMetadata?
    let gridItems: [GridItem] = [GridItem()]
    let fileNamePath = NSTemporaryDirectory() + "Photo.jpg"
    let utilityFileSystem = NCUtilityFileSystem()

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                List {
                    Section(footer: Text(NSLocalizedString("_modify_image_desc_", comment: ""))) {
                        ScrollView(.horizontal) {
                            LazyHGrid(rows: gridItems, alignment: .center, spacing: 10) {
                                ForEach(0..<model.previewStore.count, id: \.self) { index in
                                    let item = model.previewStore[index]
                                    Menu {
                                        Button(action: {
                                            renameFileName = model.previewStore[index].fileName
                                            renameIndex = index
                                            showRenameAlert = true
                                        }) {
                                            Label(NSLocalizedString("_rename_", comment: ""), systemImage: "pencil")
                                        }
                                        if item.asset.type == .photo || item.asset.type == .livePhoto {
                                            Button(action: {
                                                if model.presentedQuickLook(index: index, fileNamePath: fileNamePath) {
                                                    self.index = index
                                                    showQuickLook = true
                                                }
                                            }) {
                                                Label(NSLocalizedString("_modify_", comment: ""), systemImage: "pencil.tip.crop.circle")
                                            }
                                        }
                                        if item.data != nil {
                                            Button(action: {
                                                if let image = model.previewStore[index].asset.fullResolutionImage?.resizeImage(size: CGSize(width: 300, height: 300), isAspectRation: true) {
                                                    model.previewStore[index].image = image
                                                    model.previewStore[index].data = nil
                                                    model.previewStore[index].assetType = model.previewStore[index].asset.type
                                                }
                                            }) {
                                                Label(NSLocalizedString("_undo_modify_", comment: ""), systemImage: "arrow.uturn.backward.circle")
                                            }
                                        }
                                        if item.data == nil && item.asset.type == .livePhoto && item.assetType == .livePhoto {
                                            Button(action: {
                                                model.previewStore[index].assetType = .photo
                                            }) {
                                                Label(NSLocalizedString("_disable_livephoto_", comment: ""), systemImage: "livephoto.slash")
                                            }
                                        } else if item.data == nil && item.asset.type == .livePhoto && item.assetType == .photo {
                                            Button(action: {
                                                model.previewStore[index].assetType = .livePhoto
                                            }) {
                                                Label(NSLocalizedString("_enable_livephoto_", comment: ""), systemImage: "livephoto")
                                            }
                                        }
                                        Button(role: .destructive, action: {
                                            model.deleteAsset(index: index)
                                        }) {
                                            Label(NSLocalizedString("_remove_", comment: ""), systemImage: "trash")
                                        }
                                    } label: {
                                        ImageAsset(model: model, index: index)
                                            .alert(NSLocalizedString("_rename_", comment: ""), isPresented: $showRenameAlert) {
                                                TextField("", text: $renameFileName)
                                                    .autocapitalization(.none)
                                                    .autocorrectionDisabled()

                                                Button(NSLocalizedString("_rename_", comment: ""), action: {
                                                    if !renameError.isEmpty {
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                            showRenameAlert = true
                                                        }
                                                    } else {
                                                        model.previewStore[renameIndex].fileName = renameFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                                                    }
                                                })

                                                Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel, action: {})
                                            } message: {
                                                Text(renameError)
                                            }
                                    }
                                    .onChange(of: renameFileName) { newValue in
                                        if let error = FileNameValidator.shared.checkFileName(newValue, account: model.controller?.account) {
                                            renameError = error.errorDescription
                                        } else {
                                            renameError = ""
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Toggle(isOn: $model.useAutoUploadFolder, label: {
                            Text(NSLocalizedString("_use_folder_auto_upload_", comment: ""))
                                .font(.system(size: 15))
                        })
                        .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.getElement(account: metadata?.account))))

                        if model.useAutoUploadFolder {
                            Toggle(isOn: $model.useAutoUploadSubFolder, label: {
                                Text(NSLocalizedString("_autoupload_create_subfolder_", comment: ""))
                                    .font(.system(size: 15))
                            })
                            .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.getElement(account: metadata?.account))))
                        }

                        if !model.useAutoUploadFolder {
                            HStack {
                                Label {
                                    if utilityFileSystem.getHomeServer(session: model.session) == model.serverUrl {
                                        Text("/")
                                            .font(.system(size: 15))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    } else {
                                        Text(model.getTextServerUrl())
                                            .font(.system(size: 15))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                } icon: {
                                    Image("folder")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(Color(NCBrandColor.shared.getElement(account: metadata?.account)))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showSelect = true
                            }
                        }
                    }

                    Section {
                        Button(NSLocalizedString("_save_", comment: "")) {
                            if model.useAutoUploadFolder, model.useAutoUploadSubFolder {
                                model.showHUD = true
                            }
                            model.uploadInProgress.toggle()
                            model.save { metadatasNOConflict, metadatasUploadInConflict in
                                if metadatasUploadInConflict.isEmpty {
                                    model.dismissCreateFormUploadConflict(metadatas: metadatasNOConflict)
                                } else {
                                    model.metadatasNOConflict = metadatasNOConflict
                                    model.metadatasUploadInConflict = metadatasUploadInConflict
                                    showUploadConflict = true
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(ButtonRounded(disabled: model.uploadInProgress, account: model.session.account))
                        .listRowBackground(Color(UIColor.systemGroupedBackground))
                        .disabled(model.uploadInProgress)
                        .hiddenConditionally(isHidden: model.hiddenSave)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("_upload_photos_videos_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(action: {
                model.dismissView = true
            }) {
                Image(systemName: "xmark")
                    .font(Font.system(.body).weight(.light))
                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
            })
            NCHUDView(showHUD: $model.showHUD, textLabel: NSLocalizedString("_wait_", comment: ""), image: "doc.badge.arrow.up", color: NCBrandColor.shared.getElement(account: model.session.account))
                .offset(y: model.showHUD ? 5 : -200)
                .animation(.easeOut, value: model.showHUD)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showSelect) {
            SelectView(serverUrl: $model.serverUrl, session: model.session)
        }
        .sheet(isPresented: $showUploadConflict) {
            UploadConflictView(delegate: model, serverUrl: model.serverUrl, metadatasUploadInConflict: model.metadatasUploadInConflict, metadatasNOConflict: model.metadatasNOConflict)
        }
        .fullScreenCover(isPresented: $showQuickLook) {
            NCViewerQuickLookView(url: URL(fileURLWithPath: fileNamePath), index: $index, isPresentedQuickLook: $showQuickLook, model: model)
                .ignoresSafeArea()
        }
        .onReceive(model.$dismissView) { newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onDisappear {
            model.dismissView = true
        }
    }

    struct ImageAsset: View {
        @ObservedObject var model: NCUploadAssetsModel
        @State var index: Int

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                if index < model.previewStore.count {
                    let item = model.previewStore[index]
                    Image(uiImage: item.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80, alignment: .center)
                        .cornerRadius(10)
                    if item.assetType == .livePhoto && item.data == nil {
                        Image(systemName: "livephoto")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 5)
                    } else if item.assetType == .video {
                        Image(systemName: "video.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 5)
                    }
                }
            }
        }
    }
}

#Preview {
    NCUploadAssetsView(model: NCUploadAssetsModel(assets: [], serverUrl: "/", controller: nil))
}
