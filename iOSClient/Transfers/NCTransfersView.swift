// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// MARK: - Main View

struct TransfersView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: TransfersViewModel

    private let onClose: (() -> Void)?

    init(session: NCSession.Session? = nil, previewMetadatas: [tableMetadata]? = nil, onClose: (() -> Void)? = nil) {
        if let previewMetadatas {
            let previewSession = NCSession.Session(account: "", urlBase: "", user: "", userId: "")
            let model = TransfersViewModel(session: previewSession)
            model.metadatas = previewMetadatas
            _model = StateObject(wrappedValue: model)
        } else if let session {
            _model = StateObject(wrappedValue: TransfersViewModel(session: session))
        } else {
            fatalError("TransfersView must be initialized with either a session or previewItems.")
        }

        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(NSLocalizedString("_transfers_", comment: ""))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("_close_") {
                            if let onClose {
                                onClose()
                            }
                        }
                    }
                }
        }
        .onDisappear {
            model.detach()
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var contentView: some View {
        if model.showFlushMessage || (
            model.inWaitingCount == 0 &&
            model.inProgressCount == 0 &&
            model.inErrorCount == 0
        ) {
            EmptyTransfersView(model: model)
        } else {
            List {
                Section(header: TransfersSummaryHeader(
                    selectedFilter: model.selectedFilter,
                    inWaitingCount: model.inWaitingCount,
                    inProgressCount: model.inProgressCount,
                    inErrorCount: model.inErrorCount,
                    onSelect: { filter in
                        Task {
                            await model.selectFilter(filter)
                        }
                    }
                ).font(.headline)) {
                    if model.metadatas.isEmpty {
                        ContentUnavailableView(
                            NSLocalizedString("_no_transfer_", comment: ""),
                            systemImage: "tray",
                            description: Text(NSLocalizedString("_no_transfer_sub_", comment: ""))
                        )
                        .listRowSeparator(.hidden)
                    }
                    ForEach(model.metadatas, id: \.ocId) { item in
                        TransferRowView(model: model, item: item) {
                            await model.cancel(item: item)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }

                    if !model.metadatas.isEmpty {
                        TransferPaginationControls(
                            currentPage: model.currentPage,
                            hasNextPage: model.hasNextPage,
                            onPrevious: {
                                Task {
                                    await model.loadPreviousPage()
                                }
                            },
                            onNext: {
                                Task {
                                    await model.loadNextPage()
                                }
                            }
                        )
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
    let selectedFilter: TransfersFilter
    let inWaitingCount: Int
    let inProgressCount: Int
    let inErrorCount: Int
    let onSelect: (TransfersFilter) -> Void

    var body: some View {
        HStack(spacing: 8) {
            summaryButton(
                title: "_in_progress_",
                value: inProgressCount,
                filter: .progress
            )

            summaryButton(
                title: "_in_waiting_",
                value: inWaitingCount,
                filter: .waiting
            )

            summaryButton(
                title: "_in_error_",
                value: inErrorCount,
                filter: .error
            )

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func summaryButton(
        title: String,
        value: Int,
        filter: TransfersFilter
    ) -> some View {
        Button {
            onSelect(filter)
        } label: {
            HStack(spacing: 6) {
                Text(NSLocalizedString(title, comment: ""))
                    .font(.caption)

                Text("\(value)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(selectedFilter == filter ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                selectedFilter == filter ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pagination

struct TransferPaginationControls: View {
    let currentPage: Int
    let hasNextPage: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onPrevious()
            } label: {
                Label("_previous_", systemImage: "chevron.left")
            }
            .disabled(currentPage == 0)

            Spacer()

            Text("\(currentPage + 1)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onNext()
            } label: {
                Label("_next_", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(!hasNextPage)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }
}

// MARK: - Empty State

struct EmptyTransfersView: View {
    @ObservedObject var model: TransfersViewModel
    @State private var flash = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: flash ? "checkmark.circle" : "arrow.left.arrow.right.circle")
                    .font(.icon(48))
                    .foregroundStyle(flash ? .green : .secondary)
                    .symbolEffect(.bounce, value: flash)
            }

            if flash {
                Text("_update_in_progress_")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            } else {
                Text("_no_transfer_")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("_no_transfer_sub_")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: model.showFlushMessage) {
            if model.showFlushMessage {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    flash = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.25)) {
                    flash = false
                }
            }
        }
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
                    .font(.icon(30))

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.fileName).font(.headline)

                    if !status.status.isEmpty {
                        Text(status.status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }

                    if let wwan = model.wwanWaitInfoIfNeeded(for: item), !wwan.isEmpty {
                        Text(wwan)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    } else if !status.info.isEmpty {
                        Text(status.info)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    Task {
                        await onCancel()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(
                                Color.gray.opacity(0.2),
                                lineWidth: 2
                            )
                            .frame(width: 36, height: 36)

                        Circle()
                            .trim(from: 0, to: CGFloat(model.progress(for: item)))
                            .stroke(
                                Color(Color(NCBrandColor.shared.customer)),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 36, height: 36)
                            .animation(.easeInOut(duration: 0.25), value: model.progress(for: item))
                        Image(systemName: "stop.fill")
                            .font(.icon(14, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
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
        let metadatas: [tableMetadata] = [
            tableMetadata(ocId: "1", fileName: "filename 1", status: NCGlobal.shared.metadataStatusWaitCreateFolder),
            tableMetadata(ocId: "2", fileName: "filename 2", size: 7230000, status: NCGlobal.shared.metadataStatusUploading),
            tableMetadata(ocId: "3", fileName: "filename 3", size: 5230000, status: NCGlobal.shared.metadataStatusDownloading),
            tableMetadata(ocId: "4", fileName: "filename 4", size: 7230000, status: NCGlobal.shared.metadataStatusUploadError, sessionError: "Disk full Disk full Disk full Disk full Disk full Disk full Disk full Disk full", errorCode: 1)]
        return TransfersView(previewMetadatas: metadatas)
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
