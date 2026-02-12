// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import WidgetKit

struct DashboardWidgetView: View {
    var entry: DashboardDataEntry
    var body: some View {
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
                    Image(uiImage: entry.titleImage)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)

                    Text(entry.title)
                        .font(.system(size: 15))
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
                                Link(destination: element.link) {
                                    HStack {
                                        let subTitleColor = Color(white: 0.5)
                                        if entry.isPlaceholder {
                                            Circle()
                                                .fill(Color(.systemGray4))
                                                .frame(width: 35, height: 35)
                                        } else if let color = element.imageColor {
                                            Image(uiImage: element.icon)
                                                .renderingMode(.template)
                                                .resizable()
                                                .frame(width: 35, height: 35)
                                                .foregroundColor(Color(color))
                                        } else if element.imageSystem {
                                            Image(uiImage: element.icon)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 35, height: 35)
                                                .scaleEffect(0.8)
                                        } else {
                                            if entry.dashboard?.itemIconsRound ?? false || element.circle {
                                                Image(uiImage: element.icon)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 35, height: 35)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(uiImage: element.icon)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 35, height: 35)
                                                    .clipped()
                                                    .cornerRadius(5)
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 2) {

                                            Text(element.title)
                                                .font(.system(size: 12))
                                                .fontWeight(.regular)

                                            Text(element.subTitle)
                                                .font(.system(size: CGFloat(10)))
                                                .foregroundColor(subTitleColor)
                                        }
                                        Spacer()
                                    }
                                    .padding(.leading, 10)
                                    .frame(height: 50)
                                }
                                if element != entry.datas.last {
                                    Divider()
                                        .padding(.leading, 54)
                                }
                            }
                        }
                    }
                    .padding(.top, 35)
                    .redacted(reason: entry.isPlaceholder ? .placeholder : [])
                }

                if let buttons = entry.buttons, !buttons.isEmpty, !entry.isPlaceholder {
                    HStack(spacing: 10) {
                        let brandColor = Color(NCBrandColor.shared.getElement(account: entry.account))
                        let brandTextColor = Color(NCBrandColor.shared.getText(account: entry.account))

                        ForEach(buttons, id: \.index) { element in
                            Link(destination: URL(string: element.link)!, label: {

                                Text(element.text)
                                    .font(.system(size: 15))
                                    .padding(7)
                                    .background(brandColor)
                                    .foregroundColor(brandTextColor)
                                    .border(brandColor, width: 1)
                                    .cornerRadius(.infinity)
                            })
                        }
                    }
                    .frame(width: geo.size.width - 10, height: geo.size.height - 25, alignment: .bottomTrailing)
                }

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
                .padding(.horizontal, 15.0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

struct DashboardWidget_Previews: PreviewProvider {
    static var previews: some View {
        let datas = Array(dashboardDatasTest[0...4])
        let title = "Dashboard"
        let titleImage = UIImage(systemName: "circle.fill")!
        let entry = DashboardDataEntry(date: Date(), datas: datas, dashboard: nil, buttons: nil, isPlaceholder: false, isEmpty: false, titleImage: titleImage, title: title, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " widget", account: "")
        DashboardWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
