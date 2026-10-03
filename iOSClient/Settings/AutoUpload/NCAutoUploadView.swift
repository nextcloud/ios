// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Aditya Tyagi
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

/// A view that allows the user to configure the auto upload settings for Nextcloud.
@MainActor
struct NCAutoUploadView: View {
    @State private var reachedAnchor = false
    @StateObject var model: NCAutoUploadModel
    @StateObject var albumModel: AlbumModel
    @State private var showUploadFolder = false
    @State private var showSelectAlbums = false
    @State private var showFocusedAutoUploadIntro = false
    @State private var showFocusedAutoUploadProgress = false
    @State private var openFocusedAutoUploadFinish = false
    @State private var startAutoUpload = false
    @State private var isCheckingOtherAutoUploadAccount = true
    @State private var otherAutoUploadAccountName: String?
    @Environment(NCAutoUploadCounter.self) private var autoUploadCounter

    private var isAutoUploadUnavailable: Bool {
        isCheckingOtherAutoUploadAccount || otherAutoUploadAccountName != nil
    }

    private var areSettingsDisabled: Bool {
        model.autoUploadStart || model.isChangingAutoUpload || isAutoUploadUnavailable
    }

    var body: some View {
        ZStack {
            if model.photosPermissionsGranted {
                autoUploadOnView
            } else {
                noPermissionsView
            }
        }
        .hideTopScrollEdgeEffect()
        .navigationBarTitle(NSLocalizedString("_auto_upload_folder_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(NSLocalizedString("_auto_upload_folder_", comment: ""))
                        .font(.headline)

                    if model.autoUploadStart && autoUploadCounter.isLoaded {
                        Text(autoUploadCounter.itemsLeftSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            model.onViewAppear()
            refreshOtherAutoUploadAccount()
            updateAutoUploadCounterSubscription()
        }
        .onDisappear {
            stopAutoUploadCounterSubscription()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            model.onViewAppear()
            refreshOtherAutoUploadAccount()
        }
        .alert(model.error, isPresented: $model.showErrorAlert) {
            Button(NSLocalizedString("_ok_", comment: ""), role: .cancel) {}
        }
        .sheet(isPresented: $showUploadFolder) {
            SelectView(
                serverUrl: $model.serverUrl,
                includeDirectoryE2EEncryption: false,
                session: model.session,
                controller: model.controller
            )
            .onDisappear {
                model.setAutoUploadDirectory(serverUrl: model.serverUrl)
            }
        }
        .sheet(isPresented: $showSelectAlbums) {
            SelectAlbumView(model: albumModel)
        }
        .sheet(isPresented: $showFocusedAutoUploadIntro, onDismiss: {
            guard openFocusedAutoUploadFinish else {
                return
            }

            openFocusedAutoUploadFinish = false

            guard autoUploadCounter.hasItemsToUpload else {
                return
            }

            showFocusedAutoUploadProgress = true
        }) {
            NCFocusedAutoUploadIntroView {
                openFocusedAutoUploadFinish = true
                showFocusedAutoUploadIntro = false
            }
            .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showFocusedAutoUploadProgress) {
            NCFocusedAutoUploadProgressView(
                isPresented: $showFocusedAutoUploadProgress,
                account: model.session.account,
                urlBase: model.session.urlBase,
                userId: model.session.userId
            )
            .environment(autoUploadCounter)
        }
        .onChange(of: autoUploadCounter.sinceDate) { _, date in
            guard model.autoUploadStart, autoUploadCounter.isLoaded else { return }
            model.autoUploadSinceDate = date
        }
        .onChange(of: model.autoUploadStart) { _, newValue in
            if !newValue {
                showFocusedAutoUploadIntro = false
                showFocusedAutoUploadProgress = false
                openFocusedAutoUploadFinish = false
            }

            updateAutoUploadCounterSubscription()
        }
    }

    @ViewBuilder
    var autoUploadOnView: some View {
        Form {
            if let otherAutoUploadAccountName {
                Section {
                    Label(
                        NSLocalizedString("_autoupload_active_other_account_title_", comment: ""),
                        systemImage: "lock.fill"
                    )
                } footer: {
                    Text(
                        String(
                            format: NSLocalizedString("_autoupload_active_other_account_message_", comment: ""),
                            otherAutoUploadAccountName
                        )
                    )
                }
            }

            if !model.usesPhotoKitAutoUpload, model.autoUploadStart && autoUploadCounter.hasItemsToUpload {
                Section(content: {
                    Button {
                        showFocusedAutoUploadIntro = true
                    } label: {
                        HStack {
                            Image(systemName: "moon")
                                .font(.icon())
                                .frame(width: 26)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))

                            Text(NSLocalizedString("_focused_auto_upload_", comment: ""))
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }, footer: {
                    Text(NSLocalizedString("_focused_auto_upload_settings_footer_", comment: ""))
                        .font(.footnote)
                })
            }

            Group {
                Section(content: {
                    Button {
                        showUploadFolder.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .font(.icon())
                                .frame(width: 26)
                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor))

                            Text(NSLocalizedString("_destination_", comment: ""))
                                .font(.body)
                                .tint(.primary)

                            Text(model.returnPath())
                                .font(.body)
                                .tint(.primary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                })

                Section(content: {
                    NavigationLink(destination: SelectAlbumView(model: albumModel)) {
                        Button {
                            showSelectAlbums.toggle()
                        } label: {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.icon())
                                    .frame(width: 26)
                                    .foregroundColor(Color(NCBrandColor.shared.iconImageColor))

                                Text(NSLocalizedString("_upload_from_", comment: ""))
                                    .font(.body)
                                    .tint(.primary)

                                Text(
                                    NSLocalizedString(
                                        model.createAlbumTitle(
                                            autoUploadAlbumIds: albumModel.autoUploadAlbumIds
                                        ),
                                        comment: ""
                                    )
                                )
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .tint(.primary)
                            }
                        }
                    }

                    if model.autoUploadStart {
                        autoUploadProgressDate
                    } else {
                        autoUploadTimespanOptions
                    }

                    Toggle(NSLocalizedString("_autoupload_ignore_history_", comment: ""), isOn: Binding(
                        get: { model.autoUploadForceReupload },
                        set: { model.handleAutoUploadForceReupload($0) }
                    ))
                    Text(NSLocalizedString("_autoupload_ignore_history_description_", comment: ""))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }, footer: {
                    Text(autoUploadTimespanDescription)
                        .font(.footnote)
                })

                Section(content: {
                    Toggle(
                        NSLocalizedString("_autoupload_photos_", comment: ""),
                        isOn: $model.autoUploadImage
                    )
                    .font(.body)
                    .tint(
                        Color(
                            NCBrandColor.shared.getElement(
                                account: model.session.account
                            )
                        )
                    )
                    .onChange(of: model.autoUploadImage) { _, newValue in
                        if !newValue {
                            model.autoUploadVideo = true
                        }

                        model.handleAutoUploadImageChange(newValue: newValue)
                    }

                    if model.autoUploadImage {
                        Toggle(
                            NSLocalizedString("_wifi_only_", comment: ""),
                            isOn: $model.autoUploadWWAnPhoto
                        )
                        .font(.body)
                        .tint(
                            Color(
                                NCBrandColor.shared.getElement(
                                    account: model.session.account
                                )
                            )
                        )
                        .onChange(of: model.autoUploadWWAnPhoto) { _, newValue in
                            model.handleAutoUploadWWAnPhotoChange(
                                newValue: newValue
                            )
                        }
                    }
                })

                Section(content: {
                    Toggle(
                        NSLocalizedString("_autoupload_videos_", comment: ""),
                        isOn: $model.autoUploadVideo
                    )
                    .font(.body)
                    .tint(
                        Color(
                            NCBrandColor.shared.getElement(
                                account: model.session.account
                            )
                        )
                    )
                    .onChange(of: model.autoUploadVideo) { _, newValue in
                        if !newValue {
                            model.autoUploadImage = true
                        }

                        model.handleAutoUploadVideoChange(newValue: newValue)
                    }

                    if model.autoUploadVideo {
                        Toggle(
                            NSLocalizedString("_wifi_only_", comment: ""),
                            isOn: $model.autoUploadWWAnVideo
                        )
                        .font(.body)
                        .tint(
                            Color(
                                NCBrandColor.shared.getElement(
                                    account: model.session.account
                                )
                            )
                        )
                        .onChange(of: model.autoUploadWWAnVideo) { _, newValue in
                            model.handleAutoUploadWWAnVideoChange(
                                newValue: newValue
                            )
                        }
                    }
                })

                Section(content: {
                    Toggle(
                        NSLocalizedString(
                            "_autoupload_create_subfolder_",
                            comment: ""
                        ),
                        isOn: $model.autoUploadCreateSubfolder
                    )
                    .font(.body)
                    .tint(
                        Color(
                            NCBrandColor.shared.getElement(
                                account: model.session.account
                            )
                        )
                    )
                    .onChange(of: model.autoUploadCreateSubfolder) { _, newValue in
                        model.handleAutoUploadCreateSubfolderChange(
                            newValue: newValue
                        )
                    }

                    if model.autoUploadCreateSubfolder {
                        Picker(
                            NSLocalizedString(
                                "_autoupload_subfolder_granularity_",
                                comment: ""
                            ),
                            selection: $model.autoUploadSubfolderGranularity
                        ) {
                            Text(NSLocalizedString("_daily_", comment: ""))
                                .tag(Granularity.daily)
                                .font(.body)

                            Text(NSLocalizedString("_monthly_", comment: ""))
                                .tag(Granularity.monthly)
                                .font(.body)

                            Text(NSLocalizedString("_yearly_", comment: ""))
                                .tag(Granularity.yearly)
                                .font(.body)
                        }
                        .onChange(
                            of: model.autoUploadSubfolderGranularity
                        ) { _, newValue in
                            model.handleAutoUploadSubfolderGranularityChange(
                                newValue: newValue
                            )
                        }
                    }
                }, footer: {
                    Text(
                        NSLocalizedString(
                            "_autoupload_create_subfolder_footer_",
                            comment: ""
                        )
                    )
                    .font(.footnote)
                })

                if !model.usesPhotoKitAutoUpload {
                    Section(content: {
                        Toggle(
                            NSLocalizedString(
                                "_enable_background_location_title_",
                                comment: ""
                            ),
                            isOn: $model.locationAutoUploadPermissionGranted
                        )
                        .font(.body)
                        .tint(
                            Color(
                                NCBrandColor.shared.getElement(
                                    account: model.session.account
                                )
                            )
                        )
                        .onChange(
                            of: model.locationAutoUploadPermissionGranted
                        ) { _, newValue in
                            model.handleLocationChange(newValue: newValue)
                        }
                    }, footer: {
                        Text(
                            NSLocalizedString(
                                "_enable_background_location_footer_",
                                comment: ""
                            )
                        )
                        .font(.footnote)
                    })
                }
            }
            .disabled(areSettingsDisabled)
            .opacity(areSettingsDisabled ? 0.5 : 1)

            if #available(iOS 27, *),
               NCPreferences.canConfigureBackgroundUploadExtension,
               let capabilities = NCNetworking.shared.capabilities[model.session.account],
               NCBrandOptions.shared.isServerVersion(capabilities, greaterOrEqualTo: .v35) {
                Section(content: {
                    Toggle(isOn: $model.backgroundUploadExtensionEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.icon())
                                .foregroundStyle(.orange)
                                .frame(width: 26)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(NSLocalizedString("_background_upload_extension_", comment: ""))
                                    .font(.body)

                                Text("TEST")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .font(.body)
                    .tint(.orange)
                    .onChange(of: model.backgroundUploadExtensionEnabled) { _, newValue in
                        model.handleBackgroundUploadExtensionChange(newValue: newValue)
                    }
                    .disabled(areSettingsDisabled)
                    .opacity(areSettingsDisabled ? 0.5 : 1)
                }, header: {
                    Text(NSLocalizedString("_experimental_", comment: ""))
                        .font(.headline)
                }, footer: {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("_background_upload_extension_footer_", comment: ""))
                            .font(.footnote)

                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                NSLocalizedString("_background_upload_extension_apache_title_", comment: ""),
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.footnote.bold())

                            Text(NSLocalizedString("_background_upload_extension_apache_warning_", comment: ""))
                                .font(.footnote)

                            Text(verbatim: "RewriteEngine On\nRewriteCond %{REQUEST_METHOD} =OPTIONS\nRewriteCond %{HTTP:X-NC-PhotoKit-Upload} =1\nRewriteRule ^ - [R=501,L]")
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                        .foregroundStyle(.red)
                        .padding(12)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.6), lineWidth: 1)
                        }
                    }
                })
            }
        }
        .safeAreaInset(edge: .bottom) {
            autoUploadStartButton
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
                .disabled(model.isChangingAutoUpload || isAutoUploadUnavailable)
                .opacity(isAutoUploadUnavailable ? 0.5 : 1)
        }
    }

    private var autoUploadProgressDate: some View {
        LabeledContent {
            if let date = model.autoUploadSinceDate {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .multilineTextAlignment(.trailing)
            } else {
                Text("_autoupload_waiting_for_uploads_")
            }
        } label: {
            Text("_autoupload_completed_until_")
        }
        .font(.body)
        .foregroundStyle(.primary)
        .accessibilityIdentifier("AutoUploadProgressDate")
    }

    @ViewBuilder
    private var autoUploadTimespanOptions: some View {
        ForEach(AutoUploadTimespan.allCases) { timespan in
            Button {
                model.handleAutoUploadTimespan(timespan)
            } label: {
                HStack {
                    Text(NSLocalizedString(timespan == .allPhotos ? "_autoupload_whole_library_" : "_autoupload_from_date_", comment: ""))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if model.autoUploadTimespan == timespan {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.body)
            .accessibilityIdentifier("AutoUploadTimespan-" + timespan.rawValue)
            .accessibilityAddTraits(model.autoUploadTimespan == timespan ? .isSelected : [])
        }

        if model.autoUploadSinceDate != nil {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("_autoupload_start_date_")
                        .font(.body)

                    DatePicker(
                        "_autoupload_start_date_",
                        selection: Binding(
                            get: { model.autoUploadSinceDate ?? Date.now },
                            set: { model.handleAutoUploadSinceDate($0) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .font(.body)
                    .accessibilityIdentifier("AutoUploadStartDate")
                }

                HStack {
                    Spacer()
                    Button {
                        model.handleAutoUploadSinceDate(Date.now)
                    } label: {
                        Label("_autoupload_set_to_now_", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("AutoUploadSetToNow")
                }
            }
        }
    }

    private var autoUploadTimespanDescription: String {
        if model.autoUploadForceReupload {
            return NSLocalizedString("_autoupload_force_reupload_footer_", comment: "")
        }
        let destination = model.returnPath()
        if model.autoUploadSinceDate != nil {
            return String(format: NSLocalizedString("_autoupload_date_range_footer_", comment: ""), destination)
        }
        return String(format: NSLocalizedString("_autoupload_whole_library_description_", comment: ""), destination)
    }

    @ViewBuilder
    var autoUploadStartButton: some View {
        Section {
            let toggle = Toggle(isOn: $model.autoUploadStart) {
                Text(
                    model.autoUploadStart
                        ? "_stop_autoupload_"
                        : "_start_autoupload_"
                )
                .font(.body)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .cappedFont(.body, maxDynamicType: .accessibility2)
            .tint(
                Color(
                    NCBrandColor.shared.getElement(
                        account: model.session.account
                    )
                )
            )
            .onChange(of: model.autoUploadStart) { _, newValue in
                handleAutoUploadStartChange(newValue)
            }
            .font(.headline)

            if #available(iOS 26.0, *) {
                toggle
                    .font(.body)
                    .toggleStyle(.button)
                    .buttonStyle(.glass)
            } else {
                toggle
                    .font(.body)
                    .toggleStyle(
                        AutoUploadProminentButtonStyle(model: model)
                    )
            }
        }
    }

    private func handleAutoUploadStartChange(_ newValue: Bool) {
        albumModel.populateSelectedAlbums()

        if newValue {
            let assetCollections = albumModel.selectedAlbums

            Task {
                if let account = await model.getOtherAutoUploadAccount() {
                    otherAutoUploadAccountName = account.alias.isEmpty
                        ? account.account
                        : account.alias

                    model.autoUploadStart = false
                } else {
                    model.handleAutoUploadChange(
                        newValue: true,
                        assetCollections: assetCollections
                    )
                }
            }

            return
        }

        model.handleAutoUploadChange(
            newValue: newValue,
            assetCollections: albumModel.selectedAlbums
        )
    }

    private func updateAutoUploadCounterSubscription() {
        autoUploadCounter.start(
            account: model.session.account,
            urlBase: model.session.urlBase,
            userId: model.session.userId,
            autoUploadStart: model.autoUploadStart
        )
    }

    private func refreshOtherAutoUploadAccount() {
        isCheckingOtherAutoUploadAccount = true

        Task {
            let account = await model.getOtherAutoUploadAccount()

            otherAutoUploadAccountName = account.map {
                $0.alias.isEmpty ? $0.account : $0.alias
            }
            isCheckingOtherAutoUploadAccount = false
        }
    }

    private func stopAutoUploadCounterSubscription() {
        autoUploadCounter.stop()
    }
}

@ViewBuilder
var noPermissionsView: some View {
    VStack {
        Text("_access_photo_not_enabled_")
            .padding()
            .font(.body)

        Text("_access_photo_not_enabled_msg_")
            .font(.body)
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemGroupedBackground))
}

/// A prominent brand style used for toggle buttons.
private struct AutoUploadProminentButtonStyle: ToggleStyle {
    let model: NCAutoUploadModel

    private var onBackground: Color {
        Color(
            NCBrandColor.shared.getElement(
                account: model.session.account
            )
        )
    }

    private let offBackground = Color(UIColor.systemGray5)
    private let onForeground = Color.white
    private let offForeground = Color.primary
    private let cornerRadius: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .foregroundColor(
                    configuration.isOn
                        ? onForeground
                        : offForeground
                )
                .padding(.vertical, 10)
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
            .fill(
                configuration.isOn
                    ? onBackground
                    : offBackground
            )
        )
        .animation(
            .easeOut(duration: 0.15),
            value: configuration.isOn
        )
        .shadow(
            color: .black.opacity(0.2),
            radius: 10,
            x: 0,
            y: 3
        )
    }
}

#Preview {
    NCAutoUploadView(
        model: NCAutoUploadModel(controller: nil),
        albumModel: AlbumModel(controller: nil)
    )
    .environment(NCAutoUploadCounter())
}
