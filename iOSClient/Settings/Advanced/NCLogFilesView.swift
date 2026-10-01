// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCLogFilesView: View {
    @ObservedObject var model: NCSettingsAdvancedModel
    @State private var showLogError = false
    @State private var logErrorMessage = ""

    var body: some View {
        List {
            Section {
                Button {
                    Task { await model.clearLogFile() }
                } label: {
                    Label(NSLocalizedString("_clear_log_", comment: ""), systemImage: "trash")
                }
                .tint(Color(UIColor.label))
                .disabled(model.logFiles.isEmpty)
            }

            Section {
                if model.logFiles.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("_no_log_files_", comment: ""),
                        systemImage: "doc.text.magnifyingglass"
                    )
                } else {
                    ForEach(model.logFiles, id: \.self) { logFile in
                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    do { try await model.viewLogFile(at: logFile) } catch {
                                        logErrorMessage = error.localizedDescription
                                        showLogError = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: logFile.lastPathComponent == "log.txt" ? "doc.text.fill" : "doc.text")
                                        .font(.title3)
                                        .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(logFile.lastPathComponent)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        Text(model.logFileDetails(for: logFile))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            ShareLink(item: logFile) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body)
                                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                            }
                            .accessibilityLabel(NSLocalizedString("_share_", comment: ""))
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    do { try await model.deleteLogFile(at: logFile) } catch {
                                        logErrorMessage = error.localizedDescription
                                        showLogError = true
                                    }
                                }
                            } label: {
                                Label(NSLocalizedString("_delete_", comment: ""), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .disabled(model.isPreparingLogPreview)
        .overlay {
            if model.isPreparingLogPreview { ProgressView() }
        }
        .refreshable {
            await model.loadLogFiles()
        }
        .navigationTitle(NSLocalizedString("_view_log_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .alert(NSLocalizedString("_error_", comment: ""), isPresented: $showLogError) {
            Button(NSLocalizedString("_ok_", comment: ""), role: .cancel) { }
        } message: {
            Text(logErrorMessage)
        }
        .task {
            await model.loadLogFiles()
        }
    }
}
