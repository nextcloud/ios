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
    var body: some View {
        VStack(alignment: .center) {
            Text("Good morning")
                .font(.title)
                .bold()
            VStack {
                ForEach(NCDataDashboardList, id: \.id) { dataElement in
                    DashboardElement(element: dataElement)
                }
            }
        }.padding()
    }
}

struct DashboardElement: View {
    var element: NCDataDashboard
    var body: some View {
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
        }.padding(10)
        //.overlay(
            //RoundedRectangle(cornerRadius: 8)
             //   .stroke(Color(.sRGB, red: 150 / 255, green: 150 / 255, blue: 150 / 255, opacity: 0.4), lineWidth: 1)
        //)
        .shadow(radius: 1)
    }
}

struct NCElementDashboard_Previews: PreviewProvider {
    static var previews: some View {
        DashBoardList()
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
