//
//  NCDataDashboard.swift
//  DashboardWidgetExtension
//
//  Created by Marino Faggiana on 20/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Foundation

struct NCDataDashboard: Identifiable, Codable, Hashable {
    var id: Int
    var image: String
    var title: String
    var subTitle: String
}

let NCDataDashboardList: [NCDataDashboard] = [
    .init(id: 1, image: "nextcloud", title: "The Weeknd", subTitle: "theweeknd-after-hours"),
    .init(id: 2, image: "nextcloud", title: "Lil Uzi", subTitle: "eternalatake-liluzivert"),
    .init(id: 3, image: "nextcloud", title: "Dua Lipa", subTitle: "dualipa-bReAK mY heART"),
    .init(id: 4, image: "nextcloud", title: "Kanye West", subTitle: "kaynewest-jesusisking")
]
