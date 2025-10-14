// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct TransferRowView: View {
    @ObservedObject var model: TransfersViewModel
    @State private var isPressing = false

    let item: MetadataItem

    let onCancel: () async -> Void
    let onForceStart: () async -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "doc.circle")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.fileName ?? "—")
                        .font(.headline)
                        .lineLimit(2)

                    Text(model.readablePath(for: item))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    let status = model.status(for: item)
                    if !status.status.isEmpty {
                        Text(status.status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let wwan = model.wwanWaitInfoIfNeeded(for: item), !wwan.isEmpty {
                        Text(wwan)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if !status.info.isEmpty {
                        Text(status.info)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: Double(model.progress(for: item)))
                        .progressViewStyle(.linear)
                }

                Spacer(minLength: 8)

                if inProgress || inWaiting {
                    Button {
                        Task {
                            if inProgress {
                                await onCancel()
                            } else if inWaiting {
                                await onForceStart()
                            }
                        }
                    } label: {
                        Image(systemName: actionIconName)
                    }
                    .buttonStyle(.plain)
                    .tint(.primary)
                    .accessibilityLabel(actionAccessibilityLabel)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.3)
                    .onChanged { _ in
                        isPressing = true
                    }
                    .onEnded { _ in
                        isPressing = false
                    }
            )

            Divider()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isPressing ? Color.gray.opacity(0.08) : Color.clear)
    }

    // MARK: - Helpers

    private var inProgress: Bool {
        if let status = item.status {
            return NCGlobal.shared.metadatasStatusInProgress.contains(status)
        }
        return false
    }

    private var inWaiting: Bool {
        if let status = item.status {
            return NCGlobal.shared.metadatasStatusInWaiting.contains(status)
        }
        return false
    }

    private var actionIconName: String {
        if inProgress {
            return "stop.circle"
        } else if inWaiting {
            return "play.circle"
        } else {
            return "ellipsis.circle"
        }
    }

    private var actionAccessibilityLabel: String {
        if inProgress {
            return "_cancel_"
        }
        if inWaiting {
            return "_force_start_"
        }
        return "_more_"
    }
}

// MARK: - Empty State

struct EmptyTransfersView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)

            Text(NSLocalizedString("_no_transfer_", comment: ""))
                .font(.headline)

            Text(NSLocalizedString("_no_transfer_sub_", comment: ""))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Summary Header

struct TransfersSummaryHeader: View {
    let inProgressCount: Int
    let inWaitingCount: Int

    var body: some View {
        HStack(spacing: 8) {
            summaryPill(title: "In Progress", value: inProgressCount)
            summaryPill(title: "Waiting", value: inWaitingCount)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func summaryPill(title: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Main View

struct TransfersView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: TransfersViewModel
    private let isPreviewMode: Bool
    private let onClose: (() -> Void)?

    init(session: NCSession.Session, onClose: (() -> Void)? = nil) {
        _model = StateObject(wrappedValue: TransfersViewModel(session: session))
        self.isPreviewMode = false
        self.onClose = onClose
    }

    // preview
    #if DEBUG
    init(previewItems: [MetadataItem], onClose: (() -> Void)? = nil) {
        let model = TransfersViewModel(session: NCSession.Session(account: "", urlBase: "", user: "", userId: ""))
        model.items = previewItems
        _model = StateObject(wrappedValue: model)
        self.isPreviewMode = true
        self.onClose = onClose
    }
    #endif

    private var inProgressCount: Int {
        model.items.compactMap(\.status)
            .filter { NCGlobal.shared.metadatasStatusInProgress.contains($0) }
            .count
    }
    private var inWaitingCount: Int {
        model.items.compactMap(\.status)
            .filter { NCGlobal.shared.metadatasStatusInWaiting.contains($0) }
            .count
    }

    var body: some View {
        NavigationView {
            contentView
                .navigationTitle(model.title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NSLocalizedString("_close_", comment: "")) {
                            if let onClose {
                                onClose()
                            }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(NSLocalizedString("_cancel_all_task_", comment: "")) {
                            model.cancelAll()
                        }
                    }
                }
                .task {
                    if !isPreviewMode {
                        model.startObserving()
                        await model.reload()
                    }
                }
                .onDisappear {
                    model.stopObserving()
                }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var contentView: some View {
        if model.isLoading {
            loadingView
        } else if model.items.isEmpty {
            EmptyTransfersView()
        } else {
            listView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().progressViewStyle(.circular)
            Text(NSLocalizedString("_loading_", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        List {
            Section(header: TransfersSummaryHeader(
                inProgressCount: inProgressCount,
                inWaitingCount: inWaitingCount
            )) {
                ForEach(model.items, id: \.id) { item in
                    TransferRowView(model: model,
                                    item: item,
                                    onCancel: {
                                        await model.cancel(item: item)
                                    },
                                    onForceStart: {
                                        await model.startTask(item: item)
                                    })

                    // Swipe
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if let status = item.status,
                           NCGlobal.shared.metadatasStatusInProgress.contains(status) {
                            Button(role: .destructive) {
                                Task {
                                    await model.cancel(item: item)
                                }
                            } label: {
                                Label(NSLocalizedString("_cancel_", comment: ""), systemImage: "stop.circle")
                            }
                        }
                        if let status = item.status,
                           NCGlobal.shared.metadatasStatusInWaiting.contains(status) {
                            Button {
                                Task {
                                    await model.startTask(item: item)
                                }
                            } label: {
                                Label(NSLocalizedString("_force_start_", comment: ""), systemImage: "play.circle")
                            }
                            .tint(.green)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .conditionalRefreshable(enabled: !isPreviewMode) {
            await model.reload()
        }
    }
}

// MARK: - View helpers

private extension View {
    @ViewBuilder
    func conditionalRefreshable(enabled: Bool, action: @escaping () async -> Void) -> some View {
        if enabled {
            self.refreshable {
                await action()
            }
        } else {
            self
        }
    }
}

// MARK: - UIKit Presenter

enum TransfersPresenter {
    static func present(from presenter: UIViewController, session: NCSession.Session) {
        let rootView = TransfersView(session: session, onClose: { [weak presenter] in
            presenter?.dismiss(animated: true)
        })
        let hosting = UIHostingController(rootView: rootView)
        hosting.modalPresentationStyle = .pageSheet

        presenter.present(hosting, animated: true)
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
struct TransfersView_Previews: PreviewProvider {
    static var previews: some View {
        let demo: [MetadataItem] = [
            MetadataItem(completed: false, date: Date(), etag: "E1",
                         fileName: "photo_001.jpg", ocId: "oc1", ocIdTransfer: "tr1",
                         progress: 0.15, serverUrl: "https://demo/files/marino/Photos",
                         session: nil, size: 1_234_567,
                         status: NCGlobal.shared.metadataStatusUploading, taskIdentifier: 101),
            MetadataItem(completed: false, date: Date(), etag: "E2",
                         fileName: "video_002.mov", ocId: "oc2", ocIdTransfer: "tr2",
                         progress: 0.55, serverUrl: "https://demo/files/marino/Videos",
                         session: nil, size: 52_345_678,
                         status: NCGlobal.shared.metadataStatusDownloading, taskIdentifier: 102),
            MetadataItem(completed: false, date: Date(), etag: "E3",
                         fileName: "doc.pdf", ocId: "oc3", ocIdTransfer: "tr3",
                         progress: 0.0, serverUrl: "https://demo/files/marino/Documents",
                         session: NCNetworking.shared.sessionUploadBackgroundWWan, size: 345_678,
                         status: NCGlobal.shared.metadataStatusWaitUpload, taskIdentifier: 103)
        ]

        return TransfersView(previewItems: demo)
            .previewDisplayName("Transfers – Preview Items")
    }
}
#endif
