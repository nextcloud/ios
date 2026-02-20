// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import WidgetKit

struct FilesWidgetView: View {
    var entry: FilesDataEntry
    var body: some View {
        let parameterLink = "&user=\(entry.userId)&url=\(entry.url)"
        let linkNoAction: URL = URL(string: NCGlobal.shared.widgetActionNoAction + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionNoAction + parameterLink)! : URL(string: NCGlobal.shared.widgetActionNoAction)!
        let linkActionUploadAsset: URL = URL(string: NCGlobal.shared.widgetActionUploadAsset + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionUploadAsset + parameterLink)! : URL(string: NCGlobal.shared.widgetActionUploadAsset)!
        let linkActionScanDocument: URL = URL(string: NCGlobal.shared.widgetActionScanDocument + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionScanDocument + parameterLink)! : URL(string: NCGlobal.shared.widgetActionScanDocument)!
        let linkActionTextDocument: URL = URL(string: NCGlobal.shared.widgetActionTextDocument + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionTextDocument + parameterLink)! : URL(string: NCGlobal.shared.widgetActionTextDocument)!
        let linkActionVoiceMemo: URL = URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink) != nil ? URL(string: NCGlobal.shared.widgetActionVoiceMemo + parameterLink)! : URL(string: NCGlobal.shared.widgetActionVoiceMemo)!

        GeometryReader { geo in
            if entry.isEmpty {
                VStack(alignment: .center) {
                    Image(systemName: "checkmark")
                        .resizable()
                        .scaledToFit()
                        .font(Font.system(.body).weight(.light))
                        .frame(width: 50, height: 50)
                    Text(NSLocalizedString("_no_items_", comment: ""))
                        .font(.system(size: 25))
                        .padding()
                    Text(NSLocalizedString("_check_back_later_", comment: ""))
                        .font(.system(size: 15))
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }

            ZStack(alignment: .topLeading) {
                HStack {
                    Text(entry.tile)
                        .font(.system(size: 12))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .textCase(.uppercase)
                        .lineLimit(1)
                }
                .frame(width: geo.size.width - 20)
                .padding([.top, .leading, .trailing], 10)

                if !entry.isEmpty {
                    VStack(alignment: .leading) {
                        VStack(spacing: 0) {
                            ForEach(entry.datas, id: \.id) { element in
                                Link(destination: element.url) {
                                    HStack(spacing: 10) {
                                        Group {
                                            if element.useTypeIconFile {
                                                Image(uiImage: element.image)
                                                    .resizable()
                                                    .renderingMode(.template)
                                                    .foregroundColor(Color(NCBrandColor.shared.iconImageColor2))
                                                    .scaledToFit()
                                                    .frame(width: 35, height: 35)
                                            } else {
                                                Image(uiImage: element.image)
                                                    .resizable()
                                                    .frame(width: 35, height: 35)
                                                    .background(Color(.secondarySystemBackground))
                                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(element.title)
                                                .font(.system(size: 12))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                            Text(element.subTitle)
                                                .font(.system(size: 10))
                                                .foregroundColor(Color(NCBrandColor.shared.iconImageColor2))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 10)
                                    .frame(height: 44)
                                }
                                if element != entry.datas.last {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                    }
                    .padding(.top, 30)
                    .redacted(reason: entry.isPlaceholder ? .placeholder : [])
                }

                HStack(spacing: 10) {
                    let buttonSize: CGFloat = 40

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionUploadAsset) {
                        Image(systemName: "photo.badge.plus")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getText(account: entry.account)))
                            .frame(width: 18, height: 18)
                            .padding(11)
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))
                            .clipShape(Circle())
                            .frame(width: buttonSize, height: buttonSize)
                    }
                    .frame(maxWidth: .infinity)

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionScanDocument) {
                        Image(systemName: "doc.text.viewfinder")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getText(account: entry.account)))
                            .frame(width: 18, height: 18)
                            .padding(11)
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))
                            .clipShape(Circle())
                            .frame(width: buttonSize, height: buttonSize)
                    }
                    .frame(maxWidth: .infinity)

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionTextDocument) {
                        Image("note.text")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getText(account: entry.account)))
                            .frame(width: 18, height: 18)
                            .padding(11)
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))
                            .clipShape(Circle())
                            .frame(width: buttonSize, height: buttonSize)
                    }
                    .frame(maxWidth: .infinity)

                    Link(destination: entry.isPlaceholder ? linkNoAction : linkActionVoiceMemo) {
                        Image("microphone")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getText(account: entry.account)))
                            .frame(width: 18, height: 18)
                            .padding(11)
                            .background(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))
                            .clipShape(Circle())
                            .frame(width: buttonSize, height: buttonSize)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: geo.size.height - 25, alignment: .bottom)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])

                HStack {
                    Image(systemName: entry.footerImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .font(Font.system(.body).weight(.light))
                        .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))

                    Text(entry.footerText)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(entry.isPlaceholder ? Color(.systemGray4) : Color(NCBrandColor.shared.getElement(account: entry.account)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

struct FilesWidget_Previews: PreviewProvider {
    static var previews: some View {
        let datas = Array(filesDatasTest[0...4])
        let entry = FilesDataEntry(date: Date(), datas: datas, isPlaceholder: false, isEmpty: false, userId: "", url: "", account: "", tile: "Good afternoon, Marino Faggiana", footerImage: "checkmark.icloud", footerText: "Nextcloud files")
        FilesWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
