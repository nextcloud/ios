// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Keep the actual extension in its own text run, as in UIKit's setBidiSafeFilename.
/// Only presentation changes; file operations always use the original name.
struct NCShareFilenameView: View {
    let name: String

    var body: some View {
        let filename = name as NSString
        let ext = filename.pathExtension
        let base = filename.deletingPathExtension
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if ext.isEmpty || base.isEmpty {
                Text(verbatim: Self.displayName(name))
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text(verbatim: Self.displayName(base))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(verbatim: "." + Self.displayName(ext))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Self.displayName(name)))
    }

    /// Remove explicit direction controls from display text, including dialog titles.
    /// Ordinary Arabic/Hebrew letters retain their natural text direction.
    static func displayName(_ name: String) -> String {
        String(String.UnicodeScalarView(name.unicodeScalars.filter {
            switch $0.value {
            case 0x061C, 0x200E...0x200F, 0x202A...0x202E, 0x2066...0x2069:
                return false
            default:
                return true
            }
        }))
    }
}

#if DEBUG && SHARE_PREVIEWS
#Preview("File names and BIDI overrides") {
    VStack(alignment: .leading, spacing: 16) {
        NCShareFilenameView(name: "Report.pdf")
        NCShareFilenameView(name: "photo\u{202E}gpj.exe")
        NCShareFilenameView(name: "تقرير.pdf")
        NCShareFilenameView(name: ".gitignore")
        NCShareFilenameView(name: "A very long file name with a visible extension.pdf")
    }
    .frame(width: 240)
    .padding()
}
#endif
