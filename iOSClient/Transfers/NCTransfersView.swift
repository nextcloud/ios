// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// MARK: - Main View

struct TransfersView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: TransfersViewModel
    @State private var showCancelConfirmation = false
    private let onClose: (() -> Void)?

    init(session: NCSession.Session? = nil,
         previewItems: [MetadataItem]? = nil,
         onClose: (() -> Void)? = nil) {
        if let previewItems {
            // Preview initializer path
            let previewSession = NCSession.Session(account: "", urlBase: "", user: "", userId: "")
            let model = TransfersViewModel(session: previewSession)
            model.items = previewItems
            _model = StateObject(wrappedValue: model)
        } else if let session {
            _model = StateObject(wrappedValue: TransfersViewModel(session: session))
        } else {
            fatalError("TransfersView must be initialized with either a session or previewItems.")
        }

        self.onClose = onClose
    }

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
    private var inErrorCount: Int {
        model.items.compactMap(\.errorCode)
            .filter { $0 != 0 }
            .count
    }

    var body: some View {
        NavigationView {
            contentView
                .navigationTitle(NSLocalizedString("_transfers_", comment: ""))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NSLocalizedString("_close_", comment: "")) {
                            if let onClose {
                                onClose()
                            }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Cancel All") {
                            showCancelConfirmation = true
                        }
                        .confirmationDialog("Are you sure you want to cancel all transfers?",
                                            isPresented: $showCancelConfirmation,
                                            titleVisibility: .visible) {
                            Button("Cancel All", role: .destructive) {
                                model.cancelAll()
                            }

                            Button("Dismiss", role: .cancel) { }
                        }
                    }
                }
                .task {
                   await model.reload(withDatabase: true)
                }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var contentView: some View {
        if model.items.isEmpty {
            EmptyTransfersView()
        } else {
            List {
                Section(header: TransfersSummaryHeader(
                    inWaitingCount: inWaitingCount,
                    inProgressCount: inProgressCount,
                    inerrorCount: inErrorCount
                )) {
                    ForEach(model.items, id: \.id) { item in
                        TransferRowView(model: model, item: item, onCancel: {
                            await model.cancel(item: item)
                        },
                        onForceStart: {
                            await model.startTask(item: item)
                        })
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Summary Header

struct TransfersSummaryHeader: View {
    let inWaitingCount: Int
    let inProgressCount: Int
    let inerrorCount: Int

    var body: some View {
        HStack(spacing: 8) {
            summaryPill(title: NSLocalizedString("_in_waiting_", comment: ""), value: inWaitingCount)
            summaryPill(title: NSLocalizedString("_in_progress_", comment: ""), value: inProgressCount)
            summaryPill(title: NSLocalizedString("_in_error_", comment: ""), value: inerrorCount)
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

// MARK: - Row

struct TransferRowView: View {
    @ObservedObject var model: TransfersViewModel

    let item: MetadataItem
    let onCancel: () async -> Void
    let onForceStart: () async -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                let status = model.status(for: item)

                Image(systemName: status.symbol)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.fileName ?? "—")
                        .font(.headline)
                        .lineLimit(2)

                    Text(model.readablePath(for: item))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

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
                        .scaleEffect(y: 0.3, anchor: .center)
                        .frame(height: 2)
                        .tint(.blue)
                }

                Spacer(minLength: 8)

                Button {
                    Task {
                        await onCancel()
                    }
                } label: {
                    Image(systemName: "stop.circle")
                }
                .buttonStyle(.plain)
                .tint(.primary)
                .accessibilityLabel(NSLocalizedString("_cancel_", comment: ""))

            }
            .contentShape(Rectangle())
            Divider()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
    }
}

// MARK: - SwiftUI Preview

struct TransfersView_Previews: PreviewProvider {
    static var previews: some View {
        let items: [MetadataItem] = [
            MetadataItem(completed: false, date: Date(), etag: "E1",
                         fileName: "test-folder", ocId: "oc1", ocIdTransfer: "tr1",
                         progress: 0.15, serverUrl: "https://demo/files/marino/Photos",
                         session: nil, size: 1_234_567,
                         status: NCGlobal.shared.metadataStatusWaitCreateFolder, taskIdentifier: 101),
            MetadataItem(completed: false, date: Date(), etag: "E2",
                         fileName: "video_002.mov", ocId: "oc2", ocIdTransfer: "tr2",
                         progress: 0.55, serverUrl: "https://demo/files/marino/Videos",
                         session: nil, size: 52_345_678,
                         status: NCGlobal.shared.metadataStatusDownloading, taskIdentifier: 102),
            MetadataItem(completed: false, date: Date(), etag: "E3",
                         fileName: "doc.pdf", ocId: "oc3", ocIdTransfer: "tr3",
                         progress: 0.0, serverUrl: "https://demo/files/marino/Documents",
                         session: NCNetworking.shared.sessionUploadBackgroundWWan, size: 345_678,
                         status: NCGlobal.shared.metadataStatusUploading, taskIdentifier: 103)
        ]

        return TransfersView(previewItems: items)
            .previewDisplayName("Transfers – Preview Items")
    }
}
