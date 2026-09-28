// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCLogFilesView: View {
    @ObservedObject var model: NCSettingsAdvancedModel

    var body: some View {
        Group {
            if model.logFiles.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString("_no_log_files_", comment: ""),
                    systemImage: "doc.text.magnifyingglass"
                )
            } else {
                List(model.logFiles, id: \.self) { logFile in
                    HStack(spacing: 12) {
                        Button {
                            model.viewLogFile(at: logFile)
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
                }
                .refreshable {
                    model.loadLogFiles()
                }
            }
        }
        .navigationTitle(NSLocalizedString("_view_log_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.loadLogFiles()
        }
    }
}
