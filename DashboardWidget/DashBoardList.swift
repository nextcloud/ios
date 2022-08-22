//
//  DashBoardList.swift
//  DashboardWidgetExtension
//
//  Created by Marino Faggiana on 20/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import SwiftUI
import WidgetKit

struct DashBoardList: View {
    var data: [DashboardData]
    var body: some View {
        VStack(alignment: .center) {
            Text("Good morning")
                .font(.title)
                .bold()
            VStack {
                ForEach(data, id: \.id) { element in
                    DashboardElement(element: element)
                }
            }
        }.padding()
    }
}

struct DashboardElement: View {
    var element: DashboardData
    var body: some View {
        Link(destination: element.url) {
            HStack {
                Image(element.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                VStack(alignment: .leading) {
                    Text(element.title)
                        .font(.headline)
                    Text(element.subTitle)
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
                Spacer()
            }
            .padding(10)
        }
    }
}

struct NCElementDashboard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DashBoardList(data: dataDashboardPreview).previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
