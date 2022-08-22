//
//  DashboardData.swift
//  DashboardWidgetExtension
//
//  Created by Marino Faggiana on 20/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Foundation

struct DashboardData: Identifiable, Codable, Hashable {
    var id: Int
    var image: String
    var title: String
    var subTitle: String
    var url: URL
}

let dataDashboardPreview: [DashboardData] = [
    .init(id: 1, image: "nextcloud", title: "The Weeknd", subTitle: "theweeknd-after-hours", url: URL(string: "https://nextcloud.com/1")!),
    .init(id: 2, image: "nextcloud", title: "Lil Uzi", subTitle: "eternalatake-liluzivert", url: URL(string: "https://nextcloud.com/2")!),
    .init(id: 3, image: "nextcloud", title: "Dua Lipa", subTitle: "dualipa-bReAK mY heART", url: URL(string: "https://nextcloud.com/3")!),
    .init(id: 4, image: "nextcloud", title: "Kanye West", subTitle: "kaynewest-jesusisking", url: URL(string: "https://nextcloud.com/4")!),
    .init(id: 5, image: "nextcloud", title: "Kanye West", subTitle: "kaynewest-jesusisking", url: URL(string: "https://nextcloud.com/5")!)
]
