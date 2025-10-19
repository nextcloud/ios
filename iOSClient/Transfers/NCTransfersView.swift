// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// MARK: - Main View

struct TransfersView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: TransfersViewModel

    private let onClose: (() -> Void)?

    init(session: NCSession.Session? = nil,
         previewItems: [tableMetadata]? = nil,
         onClose: (() -> Void)? = nil) {
        if let previewItems {
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
                }
                .task {
                   await model.pollTransfers()

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
                    ForEach(model.items, id: \.ocId) { item in
                        TransferRowView(model: model, item: item) {
                            await model.cancel(item: item)
                        }
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

    let item: tableMetadata
    let onCancel: () async -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                let status = model.status(for: item)

                Image(systemName: status.symbol)
                    .font(.system(size: 30))

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.fileName)
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

                    if item.status == NCGlobal.shared.metadataStatusDownloading || item.status == NCGlobal.shared.metadataStatusUploading {
                        ProgressView(value: Double(model.progress(for: item)))
                            .progressViewStyle(.linear)
                            .scaleEffect(y: 0.5, anchor: .center)
                            .frame(height: 5)
                            .tint(.blue)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    Task {
                        await onCancel()
                    }
                } label: {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 30))
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
        let items: [tableMetadata] = [
            tableMetadata(ocId: "1", fileName: "filename 1", status: NCGlobal.shared.metadataStatusWaitCreateFolder),
            tableMetadata(ocId: "2", fileName: "filename 2", size: 7230000, status: NCGlobal.shared.metadataStatusUploading),
            tableMetadata(ocId: "3", fileName: "filename 3", size: 5230000, status: NCGlobal.shared.metadataStatusDownloading),
            tableMetadata(ocId: "4", fileName: "filename 4", size: 7230000, status: NCGlobal.shared.metadataStatusUploadError, sessionError: "Disk full", errorCode: 1)]

        return TransfersView(previewItems: items)
            .previewDisplayName("Transfers – Preview Items")
    }
}

extension tableMetadata {
    convenience init(ocId: String, fileName: String, size: Int64 = 0, status: Int, sessionError: String = "", errorCode: Int = 0) {
        self.init()

        self.ocId = ocId
        self.fileName = fileName
        self.size = size
        self.status = status
        self.errorCode = errorCode
        self.sessionError = sessionError
    }
}
