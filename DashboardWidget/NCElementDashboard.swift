//
//  NCElementDashboard.swift
//  DashboardWidgetExtension
//
//  Created by Marino Faggiana on 20/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import SwiftUI
import WidgetKit

struct NCElementDashboard: View {
    var dataElement: NCDataDashboard
    var body: some View {
        HStack {
            Image(dataElement.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            VStack(alignment: .leading) {
                Text(dataElement.title)
                    .font(.headline)
                Text(dataElement.subTitle)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
            Spacer()
        }.padding()
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.sRGB, red: 150 / 255, green: 150/255, blue: 150/255, opacity: 0.4), lineWidth: 1)
        )
        .shadow(radius: 1)
    }
}

struct NCElementDashboard_Previews: PreviewProvider {
    static var previews: some View {

//        ForEach(NCDataDashboardList, id: \.id) { dataDashboard in
//            NCElementDashboard(dataElement: NCDataDashboardList[0])
//                .previewContext(WidgetPreviewContext(family: .systemLarge))
//        }


        NCElementDashboard(dataElement: NCDataDashboardList[0])
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
