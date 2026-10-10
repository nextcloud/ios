// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A glass overlay sidebar shared by iPad, iPhone and Duo.
@MainActor
struct NCSidebarView: View {
    static let selectionChanged = Notification.Name("NCSidebarSelectionChanged")
    static let closeRequested = Notification.Name("NCSidebarCloseRequested")
    let account: String
    let controllerIdentifier: ObjectIdentifier
    let onClose: () -> Void
    let openSettings: () -> Void
    let openAssistant: () -> Void
    let openNotifications: () -> Void
    let openFiles: () -> Void
    let openPersonalFiles: () -> Void
    let openRecent: () -> Void
    let openShares: () -> Void
    let openGroupfolders: () -> Void
    let openTransfers: () -> Void
    let openOffline: () -> Void
    let openTrash: () -> Void
    let openAutoUpload: () -> Void
    let openScannedImages: () -> Void
    let openExternalSite: (String, String, Int) -> Void
    let openApp: (String, String?) -> Void
    var hasVisibleSidebarButton: () -> Bool = { false }
    var navigationBarCenterY: () -> CGFloat? = { nil }
    var windowSafeAreaLeadingInset: () -> CGFloat = { 0 }
    var currentSelection: () -> String? = { nil }
    @State private var selectedDestination: String?
    @State private var headerHeight: CGFloat = 0
    @State private var navigationCenterY: CGFloat?
    @State private var showsCloseButton = true
    @State private var updatedAccount: String?
    @State private var capabilitiesRevision = UUID()
    @State private var autoUploadCounter = NCAutoUploadCounter()
    @State private var autoUploadEnabled: Bool?
    @State private var quotaDescription = ""
    @State private var quotaProgress: Double = 0
    @State private var quotaHasLimit = false
    @State private var externalSites: [tableExternalSites] = []
    @State private var showsShares = false
    @State private var showsGroupfolders = false
    @State private var showsAssistant = false
    @State private var showsNotifications = false
    @State private var isVisible = false
    @State private var isClosing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private var activeAccount: String {
        updatedAccount ?? account
    }

    var body: some View {
        GeometryReader { geometry in
            // Keep the content clear of the landscape camera area, while glass reaches the edge.
            let leadingInset = contentLeadingInset(geometry: geometry)
            // Preserve the content width and a visible strip of the underlying screen.
            let width = max(0, min(320 + leadingInset, geometry.size.width - 56))
            ZStack(alignment: .leading) {
                VStack {
                    sidebarHeader
                        .onGeometryChange(for: CGFloat.self) { geometry in
                            geometry.size.height
                        } action: { height in
                            headerHeight = height
                            navigationCenterY = navigationBarCenterY()
                        }
                        .padding(.leading, headerLeadingInset(geometry: geometry))
                        .padding(.horizontal)
                        .padding(.top, headerTopInset)
                        .padding(.bottom, 16)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("_home_")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 8)
                            sidebarItem("_all_files_", systemImage: "folder", isSelected: selectedDestination == "sidebarFiles", action: openFiles)
                                .accessibilityIdentifier("sidebarFiles")
                            sidebarItem("_personal_files_", systemImage: "person", isSelected: selectedDestination == "sidebarPersonalFiles", action: openPersonalFiles)
                                .accessibilityIdentifier("sidebarPersonalFiles")
                            sidebarItem("_recent_", systemImage: "clock.arrow.circlepath", isSelected: selectedDestination == "sidebarRecent", action: openRecent)
                                .accessibilityIdentifier("sidebarRecent")
                            if showsShares {
                                sidebarItem("_list_shares_", systemImage: "person.badge.plus", isSelected: selectedDestination == "sidebarShares", action: openShares)
                                    .accessibilityIdentifier("sidebarShares")
                            }
                            if showsGroupfolders {
                                sidebarItem("_group_folders_", systemImage: "folder.badge.person.crop", isSelected: selectedDestination == "sidebarGroupfolders", action: openGroupfolders)
                                    .accessibilityIdentifier("sidebarGroupfolders")
                            }
                            Text("_status_")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 32)
                                .padding(.top, 20)
                                .padding(.bottom, 8)
                            sidebarItem("_transfers_", systemImage: "arrow.left.arrow.right", isSelected: selectedDestination == "sidebarTransfers", action: openTransfers)
                                .accessibilityIdentifier("sidebarTransfers")
                            sidebarItem("_offline_files_", systemImage: "arrow.down.circle.dotted", isSelected: selectedDestination == "sidebarOffline", action: openOffline)
                                .accessibilityIdentifier("sidebarOffline")
                            sidebarItem("_trash_view_", systemImage: "trash", isSelected: selectedDestination == "sidebarTrash", action: openTrash)
                                .accessibilityIdentifier("sidebarTrash")
                            Text("_media_")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 32)
                                .padding(.top, 20)
                                .padding(.bottom, 8)
                            sidebarItem("_auto_upload_folder_", systemImage: "arrow.triangle.2.circlepath", isSelected: false, subtitle: autoUploadSubtitle, action: openAutoUpload)
                                .accessibilityIdentifier("sidebarAutoUpload")
                            sidebarItem("_scanned_images_", systemImage: "doc.text.viewfinder", isSelected: false, action: openScannedImages)
                                .accessibilityIdentifier("sidebarScannedImages")
                            if !externalSites.isEmpty {
                                Text("_external_sites_")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 32)
                                    .padding(.top, 20)
                                    .padding(.bottom, 8)
                                ForEach(externalSites, id: \.idExternalSite) { site in
                                    sidebarItem(LocalizedStringKey(site.name),
                                                systemImage: site.type == "settings" ? "gear" : "network",
                                                isSelected: selectedDestination == "sidebarExternalSite-\(site.idExternalSite)") {
                                        openExternalSite(site.url, site.name, site.idExternalSite)
                                    }
                                    .accessibilityIdentifier("sidebarExternalSite-\(site.idExternalSite)")
                                }
                            }
                            if !NCBrandOptions.shared.disable_show_more_nextcloud_apps_in_settings {
                                Text("_apps_")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 32)
                                    .padding(.top, 20)
                                    .padding(.bottom, 8)
                                sidebarApp("Talk", image: "talk-template") {
                                    openApp(NCGlobal.shared.talkSchemeUrl, NCGlobal.shared.talkAppStoreUrl)
                                }
                                .accessibilityIdentifier("sidebarTalk")
                                sidebarApp("Notes", image: "notes-template") {
                                    openApp(NCGlobal.shared.notesSchemeUrl, NCGlobal.shared.notesAppStoreUrl)
                                }
                                .accessibilityIdentifier("sidebarNotes")
                                sidebarApp("_more_apps_", image: "more-apps-template") {
                                    openApp(NCGlobal.shared.moreAppsUrl, nil)
                                }
                                .accessibilityIdentifier("sidebarMoreApps")
                            }
                        }
                    }
                    quotaFooter
                }
                .padding(.leading, leadingInset)
                .frame(width: width)
                .frame(maxHeight: .infinity)
                .background {
                    sidebarBackground
                        .ignoresSafeArea(.container, edges: .vertical)
                }
                .offset(x: isVisible ? 0 : -width)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) { close(then: onClose) }
            }
            .task {
                // Wait 50 ms so SwiftUI can render the panel in its initial offscreen position.
                // Starting the animation during insertion can skip that first frame and make
                // the sidebar appear immediately instead of sliding in. This delay only
                // applies to opening; closing already starts from a rendered position.
                if !reduceMotion {
                    do {
                        try await Task.sleep(for: .milliseconds(50))
                    } catch {
                        return
                    }
                }
                guard !isClosing, !Task.isCancelled else { return }
                updateHeaderLayout()
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    isVisible = true
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { geometry in
            geometry.frame(in: .global)
        } action: { _ in
            // Reevaluate after insertion and whenever the window or orientation changes.
            updateHeaderLayout()
        }
        .background {
            // Only the backdrop extends beyond the safe area, not the panel's controls.
            Color.black.opacity(isVisible ? 0.25 : 0)
                .ignoresSafeArea()
                .onTapGesture { close(then: onClose) }
                .accessibilityHidden(true)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // Ignore vertical scrolling and short accidental movements.
                    let translation = value.translation
                    guard translation.width < 0,
                          abs(translation.width) > abs(translation.height) * 1.5,
                          translation.width < -60 || value.predictedEndTranslation.width < -100 else { return }
                    close(then: onClose)
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: Self.selectionChanged)
            .receive(on: DispatchQueue.main)) { notification in
            guard let controller = notification.object as? NCMainTabBarController,
                  ObjectIdentifier(controller) == controllerIdentifier else { return }
            selectedDestination = currentSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: Self.closeRequested)
            .receive(on: DispatchQueue.main)) { notification in
            guard let controller = notification.object as? NCMainTabBarController,
                  ObjectIdentifier(controller) == controllerIdentifier else { return }
            close(then: onClose)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name(NCGlobal.shared.notificationCenterChangeUser))
            .receive(on: DispatchQueue.main)) { notification in
            guard let controller = notification.userInfo?["controller"] as? NCMainTabBarController,
                  ObjectIdentifier(controller) == controllerIdentifier,
                  let account = notification.userInfo?["account"] as? String,
                  account == controller.account else { return }

            // Hide the previous account's actions while loading the new cached capabilities.
            updatedAccount = account
            externalSites = []
            autoUploadEnabled = nil
            autoUploadCounter.stop(reset: true)
            quotaDescription = ""
            quotaProgress = 0
            quotaHasLimit = false
            showsAssistant = false
            showsNotifications = false
            showsShares = false
            showsGroupfolders = false
            capabilitiesRevision = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name(NCGlobal.shared.notificationCenterServerDidUpdate))
            .receive(on: DispatchQueue.main)) { notification in
            guard let account = notification.userInfo?["account"] as? String,
                  account == activeAccount else { return }
            capabilitiesRevision = UUID()
        }
        .task(id: activeAccount) {
            let account = activeAccount
            autoUploadEnabled = nil
            autoUploadCounter.stop(reset: true)
            defer { autoUploadCounter.stop() }
            // The docked sidebar stays visible while Auto upload settings can change.
            while !Task.isCancelled {
                let tableAccount = await NCManageDatabase.shared.getTableAccountAsync(account: account)
                guard !Task.isCancelled else { return }
                if let tableAccount, autoUploadEnabled != tableAccount.autoUploadStart {
                    autoUploadCounter.stop(reset: true)
                    autoUploadEnabled = tableAccount.autoUploadStart
                    autoUploadCounter.start(account: account,
                                            urlBase: tableAccount.urlBase,
                                            userId: tableAccount.userId,
                                            autoUploadStart: tableAccount.autoUploadStart)
                }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
        .task(id: "\(activeAccount)-\(capabilitiesRevision)") {
            // Account changes and server updates cancel the previous read automatically.
            let capabilities = await NCManageDatabase.shared.getCapabilities(account: activeAccount)
            let tableAccount = await NCManageDatabase.shared.getTableAccountAsync(account: activeAccount)
            guard !Task.isCancelled else { return }
            if !NCBrandOptions.shared.disable_more_external_site, capabilities?.externalSites == true {
                externalSites = (NCManageDatabase.shared.getAllExternalSites(account: activeAccount) ?? [])
                    .filter { !$0.name.isEmpty && !$0.url.isEmpty }
            } else {
                externalSites = []
            }
            showsShares = capabilities?.fileSharingApiEnabled ?? false
            showsGroupfolders = capabilities?.groupfoldersEnabled ?? false
            showsAssistant = capabilities?.assistantEnabled ?? false
            showsNotifications = !(capabilities?.notification.isEmpty ?? true)
            if let tableAccount {
                updateQuota(tableAccount)
            } else {
                quotaDescription = ""
            }
        }
    }

    private var autoUploadSubtitle: String? {
        guard let autoUploadEnabled else { return nil }
        guard autoUploadEnabled else { return NSLocalizedString("_disabled_", comment: "") }
        if autoUploadCounter.isLoaded,
           autoUploadCounter.count > 0 || autoUploadCounter.failedCount > 0 || autoUploadCounter.isSuspended {
            return autoUploadCounter.itemsLeftSummary
        }
        return NSLocalizedString("_active_", comment: "")
    }

    private func updateQuota(_ tableAccount: tableAccount) {
        let utility = NCUtilityFileSystem()
        let total: String
        switch tableAccount.quotaTotal {
        case -1:
            total = "0"
        case -2:
            total = NSLocalizedString("_quota_space_unknown_", comment: "")
        case -3:
            total = NSLocalizedString("_quota_space_unlimited_", comment: "")
        default:
            total = utility.transformedSize(tableAccount.quotaTotal)
        }
        quotaDescription = String.localizedStringWithFormat(
            NSLocalizedString("_quota_using_", comment: ""),
            utility.transformedSize(tableAccount.quotaUsed),
            total
        )
        quotaHasLimit = tableAccount.quotaTotal > 0
        quotaProgress = min(max(tableAccount.quotaRelative / 100, 0), 1)
    }

    /// A noninteractive footer, separate from the scrollable navigation destinations.
    @ViewBuilder
    private var quotaFooter: some View {
        if !quotaDescription.isEmpty {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary, lineWidth: 1.5)
                    if quotaHasLimit && quotaProgress > 0 {
                        Path { path in
                            let center = CGPoint(x: 14, y: 14)
                            path.move(to: center)
                            path.addArc(center: center, radius: 13,
                                        startAngle: .degrees(-90),
                                        endAngle: .degrees(-90 + 360 * quotaProgress),
                                        clockwise: false)
                            path.closeSubpath()
                        }
                        .fill(quotaProgress >= 0.9 ? Color.red : Color.secondary)
                    }
                }
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
                Text(quotaDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 44)
            .padding(.trailing, 32)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .accessibilityElement(children: .combine)
        }
    }

    private var headerTopInset: CGFloat {
        // Align centers when the navigation bar is beside the panel. When its
        // center is above the overlay, give the separate header normal breathing room.
        guard let navigationCenterY else { return 0 }
        if navigationCenterY < 0 {
            return 16
        }
        return max(0, navigationCenterY - headerHeight / 2)
    }

    private func updateHeaderLayout() {
        selectedDestination = currentSelection()
        showsCloseButton = !hasVisibleSidebarButton()
        navigationCenterY = navigationBarCenterY()
    }

    private func contentLeadingInset(geometry: GeometryProxy) -> CGFloat {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return 0 }
        // Subtract the safe margin SwiftUI already applied to avoid counting it twice.
        return max(0, windowSafeAreaLeadingInset() - geometry.frame(in: .global).minX)
    }

    private func headerLeadingInset(geometry: GeometryProxy) -> CGFloat {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return 0 }
        if #available(iOS 26.0, *) {
            // Keep the custom header clear of system UI occupying the window's leading corner.
            return geometry.containerCornerInsets.topLeading.width
        }
        return 0
    }

    @ViewBuilder
    private var sidebarBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: Rectangle())
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }

    @ViewBuilder
    private var sidebarHeader: some View {
        if #available(iOS 26.0, *) {
            headerButtons.buttonStyle(.glass)
        } else {
            headerButtons.buttonStyle(.bordered)
        }
    }

    private var headerButtons: some View {
        HStack {
            headerButton("_settings_", systemImage: "gearshape", action: openSettings)
                .accessibilityIdentifier("sidebarSettings")

            Spacer()

            if showsAssistant {
                headerButton("_assistant_", systemImage: "sparkles", action: openAssistant)
                    .accessibilityIdentifier("sidebarAssistant")
            }

            if showsNotifications {
                headerButton("_notifications_", systemImage: "bell.fill", action: openNotifications)
                    .accessibilityIdentifier("sidebarNotifications")
            }

            // VoiceOver remains inside the modal overlay, so retain its close action there.
            if showsCloseButton || voiceOverEnabled {
                headerButton("_close_", systemImage: "sidebar.left", action: onClose)
            }
        }
        .buttonBorderShape(.circle)
        .controlSize(.regular)
    }

    /// A fixed icon column keeps every destination's title aligned.
    private func sidebarItem(_ title: LocalizedStringKey, systemImage: String, isSelected: Bool, subtitle: String? = nil, action: @escaping () -> Void) -> some View {
        sidebarItem(title, icon: Image(systemName: systemImage).font(.system(size: 20, weight: .regular)), isSelected: isSelected, subtitle: subtitle, action: action)
    }

    private func sidebarApp(_ title: LocalizedStringKey, image: String, action: @escaping () -> Void) -> some View {
        sidebarItem(title, icon: Image(image).resizable().scaledToFit().frame(width: 20, height: 20), action: action)
    }

    private func sidebarItem<Icon: View>(_ title: LocalizedStringKey, icon: Icon, isSelected: Bool = false, subtitle: String? = nil, action: @escaping () -> Void) -> some View {
        Button {
            close(then: action)
        } label: {
            HStack(spacing: 12) {
                icon.frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout)
                        .fontWeight(isSelected ? .semibold : .regular)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.08))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 28)
        .padding(.trailing, 16)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func headerButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            close(then: action)
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.title2)
                .frame(width: 32, height: 32)
        }
    }

    private func close(then action: @escaping () -> Void) {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2), completionCriteria: .removed) {
            isVisible = false
        } completion: {
            action()
        }
    }
}
