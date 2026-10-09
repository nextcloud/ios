// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A glass sidebar shared by the compact overlay and the native split column.
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
    let openFavorites: () -> Void
    let openShares: () -> Void
    let openGroupfolders: () -> Void
    let openTransfers: () -> Void
    let openActivity: () -> Void
    let openOffline: () -> Void
    let openTrash: () -> Void
    let openApp: (String, String?) -> Void
    var hasVisibleSidebarButton: () -> Bool = { false }
    var navigationBarCenterY: () -> CGFloat? = { nil }
    var currentSelection: () -> String? = { nil }
    var isDocked = false
    @State private var selectedDestination: String?
    @State private var headerHeight: CGFloat = 0
    @State private var navigationCenterY: CGFloat?
    @State private var showsCloseButton = true
    @State private var updatedAccount: String?
    @State private var capabilitiesRevision = UUID()
    @State private var quotaDescription = ""
    @State private var quotaProgress: Double = 0
    @State private var quotaHasLimit = false
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
            // Keep a strip of the underlying screen visible on compact displays.
            let width = isDocked ? geometry.size.width : max(0, min(300, geometry.size.width - 56))
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
                            sidebarItem("_favorites_", systemImage: "star", isSelected: selectedDestination == "sidebarFavorites", action: openFavorites)
                                .accessibilityIdentifier("sidebarFavorites")
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
                            sidebarItem("_activity_", systemImage: "bolt", isSelected: selectedDestination == "sidebarActivity", action: openActivity)
                                .accessibilityIdentifier("sidebarActivity")
                            sidebarItem("_offline_files_", systemImage: "arrow.down.circle.dotted", isSelected: selectedDestination == "sidebarOffline", action: openOffline)
                                .accessibilityIdentifier("sidebarOffline")
                            sidebarItem("_trash_view_", systemImage: "trash", isSelected: selectedDestination == "sidebarTrash", action: openTrash)
                                .accessibilityIdentifier("sidebarTrash")
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
                .frame(width: width)
                .frame(maxHeight: .infinity)
                .background {
                    sidebarBackground
                        .ignoresSafeArea(.container, edges: .vertical)
                }
                .offset(x: isDocked || isVisible ? 0 : -width)
                .accessibilityAddTraits(isDocked ? [] : .isModal)
                .accessibilityAction(.escape) { close(then: onClose) }
            }
            .task {
                // Wait 50 ms so SwiftUI can render the panel in its initial offscreen position.
                // Starting the animation during insertion can skip that first frame and make
                // the sidebar appear immediately instead of sliding in. This delay only
                // applies to opening; closing already starts from a rendered position.
                if !reduceMotion && !isDocked {
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
            if !isDocked {
                Color.black.opacity(isVisible ? 0.25 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { close(then: onClose) }
                    .accessibilityHidden(true)
            }
        }
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
        .task(id: "\(activeAccount)-\(capabilitiesRevision)") {
            // Account changes and server updates cancel the previous read automatically.
            let capabilities = await NCManageDatabase.shared.getCapabilities(account: activeAccount)
            let tableAccount = await NCManageDatabase.shared.getTableAccountAsync(account: activeAccount)
            guard !Task.isCancelled else { return }
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
        if !isDocked && navigationCenterY < 0 {
            return 16
        }
        return max(0, navigationCenterY - headerHeight / 2)
    }

    private func updateHeaderLayout() {
        selectedDestination = currentSelection()
        showsCloseButton = !hasVisibleSidebarButton()
        navigationCenterY = navigationBarCenterY()
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
            if !isDocked && (showsCloseButton || voiceOverEnabled) {
                headerButton("_close_", systemImage: "sidebar.left", action: onClose)
            }
        }
        .buttonBorderShape(.circle)
        .controlSize(.regular)
    }

    /// A fixed icon column keeps every destination's title aligned.
    private func sidebarItem(_ title: LocalizedStringKey, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        sidebarItem(title, icon: Image(systemName: systemImage).font(.system(size: 20, weight: .regular)), isSelected: isSelected, action: action)
    }

    private func sidebarApp(_ title: LocalizedStringKey, image: String, action: @escaping () -> Void) -> some View {
        sidebarItem(title, icon: Image(image).resizable().scaledToFit().frame(width: 20, height: 20), action: action)
    }

    private func sidebarItem<Icon: View>(_ title: LocalizedStringKey, icon: Icon, isSelected: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            close(then: action)
        } label: {
            HStack(spacing: 12) {
                icon.frame(width: 28, height: 28)
                Text(title)
                    .font(.callout)
                    .fontWeight(isSelected ? .semibold : .regular)
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
        if isDocked {
            action()
            return
        }
        guard !isClosing else { return }
        isClosing = true
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2), completionCriteria: .removed) {
            isVisible = false
        } completion: {
            action()
        }
    }
}
