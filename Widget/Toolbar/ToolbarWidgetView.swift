//
//  ToolbarWidgetView.swift
//  Widget
//
//  Created by Marino Faggiana on 25/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import SwiftUI
import WidgetKit

struct ToolbarWidgetView: View {
    
    var entry: ToolbarDataEntry
    
    var body: some View {
        
        GeometryReader { geo in
            
            ZStack(alignment: .topLeading) {
                
                HStack(spacing: 0) {

                    Link(destination: URL(string: "nextcloud://open-action?action=upload-asset")!, label: {
                        Image("buttonAddImage")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: 50)
                    })

                    Link(destination: URL(string: "nextcloud://open-action?action=add-scan-document")!, label: {
                        Image("buttonAddScan")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: 50)
                    })

                    Link(destination: URL(string: "nextcloud://open-action?action=create-text-document")!, label: {
                        Image("note.text")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: 50)
                    })

                    Link(destination: URL(string: "nextcloud://open-action?action=create-voice-memo")!, label: {
                        Image("microphone")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brandText))
                            .padding(10)
                            .background(entry.isPlaceholder ? Color(white: 0.8) : Color(NCBrandColor.shared.brand))
                            .clipShape(Circle())
                            .scaledToFit()
                            .frame(width: geo.size.width / 4, height: 50)
                    })
                }
                .frame(width: geo.size.width, height: geo.size.height - 35, alignment: .bottomTrailing)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])

                HStack {

                    Image(systemName: entry.footerImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundColor(entry.isPlaceholder ? Color(white: 0.2) : Color(NCBrandColor.shared.brand))
                    
                    Text(entry.footerText)
                        .font(.caption2)
                        .padding(.trailing, 13.0)
                }
                .frame(maxWidth: geo.size.width - 5, maxHeight: geo.size.height - 2, alignment: .bottomTrailing)
            }
        }
    }
}

struct ToolbarWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = ToolbarDataEntry(date: Date(), isPlaceholder: false, footerImage: "checkmark.icloud", footerText: NCBrandOptions.shared.brand + " toolbar")
        NextcloudWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
