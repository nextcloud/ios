// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import WidgetKit

struct ToolbarWidgetView: View {
    var entry: ToolbarDataEntry

    @ViewBuilder
    var body: some View {
        mainContent
            .containerBackground(Color.black, for: .widget)
    }

    private var mainContent: some View {
        let parameterLink = "&user=\(entry.userId)&url=\(entry.url)"
        let safeUrl = { (base: String) in
            URL(string: base + parameterLink) ?? URL(string: base)!
        }
        let linkNoAction = safeUrl(NCGlobal.shared.widgetActionNoAction)
        let linkActionUploadAsset = safeUrl(NCGlobal.shared.widgetActionUploadAsset)
        let linkActionScanDocument = safeUrl(NCGlobal.shared.widgetActionScanDocument)
        let linkActionTextDocument = safeUrl(NCGlobal.shared.widgetActionTextDocument)
        let linkActionVoiceMemo = safeUrl(NCGlobal.shared.widgetActionVoiceMemo)
        let sizeButton: CGFloat = 65

        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionUploadAsset, label: {
                        Image(systemName: "photo.badge.plus")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getText(account: entry.account)))
                            .padding()
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionScanDocument, label: {
                        Image(systemName: "doc.text.viewfinder")
                            .resizable()
                            .renderingMode(.template)
                            .font(Font.system(.body).weight(.light))
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getText(account: entry.account)))
                            .padding()
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionTextDocument, label: {
                        Image("note.text")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getText(account: entry.account)))
                            .padding()
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionVoiceMemo, label: {
                        Image("microphone")
                            .resizable()
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getText(account: entry.account)))
                            .padding()
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: sizeButton)
                    })
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])

                HStack {
                    Image(systemName: entry.footerImage)
                        .resizable()
                        .font(Font.system(.body).weight(.light))
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))

                    Text(entry.footerText)
                        .font(.caption2)
                        .padding(.trailing, 13.0)
                        .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

struct ToolbarWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = ToolbarDataEntry(date: Date(), isPlaceholder: false, userId: "", url: "", account: "", footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " toolbar")
        ToolbarWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
