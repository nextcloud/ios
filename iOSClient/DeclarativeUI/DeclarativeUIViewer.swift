// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DeclarativeUIViewer: View {
    @Environment(\.openURL) private var openURL

    struct Row: Identifiable {
        let id = UUID()
        let element: String
        let title: String?
        let urlString: String
    }

    // Configurable inputs
    let rows: [Row]
    let baseURL: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(row.element)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        if let title = row.title {
                            Text(title).font(.headline)
                        }

                        let finalUrl = baseURL + row.urlString

                        Text(finalUrl)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        HStack(spacing: 12) {
                            Button {
                                openURL(URL(string: finalUrl)!)
                            } label: {
                                Label("Open", systemImage: "safari")
                            }

                            Button {
                                UIPasteboard.general.string = row.urlString
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }

    //    private func resolvedURL(for row: Row) -> URL? {
    //        // If the string is already an absolute URL with a scheme, use it.
    //        if let absolute = URL(string: row.urlString), absolute.scheme != nil {
    //            return absolute
    //        }
    //        // Otherwise, resolve relative to the provided base URL if available.
    //        if let baseURL {
    //            return URL(string: row.urlString, relativeTo: baseURL)?.absoluteURL
    //        }
    //        return nil
    //    }
}

#Preview {
    DeclarativeUIViewer(rows: [.init(element: "URL", title: "Test", urlString: "/test")], baseURL: "test.com")
}
