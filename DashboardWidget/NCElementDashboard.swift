//
//  NCElementDashboard.swift
//  DashboardWidgetExtension
//
//  Created by Marino Faggiana on 20/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct NCElementDashboard: View {
    var data: NCDataDashboard

    var body: some View {
        HStack {
            Image(data.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width:40, height: 40)
                .clipShape(Circle())
            VStack(alignment: .leading) {
                Text(data.title)
                    .font(.headline)
                Text(data.subTitle)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
            Spacer()
        }.padding()
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.sRGB, red: 150/255, green: 150/255, blue: 150/255, opacity: 0.4), lineWidth: 1)
        )
        .shadow(radius: 1)
    }
}

struct TopAlbumCard_Previews: PreviewProvider {
    static var previews: some View {
        NCElementDashboard(data: NCDataDashboardList[0])
            .previewLayout(.fixed(width: 380, height: 75))
    }
}
