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

let dashboardDatasTest: [DashboardData] = [
    .init(id: 0, image: "nextcloud", title: "title 1", subTitle: "subTitle 1", url: URL(string: "https://nextcloud.com/")!),
    .init(id: 1, image: "nextcloud", title: "title 2", subTitle: "subTitle 2", url: URL(string: "https://nextcloud.com/")!),
    .init(id: 2, image: "nextcloud", title: "title 3", subTitle: "subTitle 3", url: URL(string: "https://nextcloud.com/")!),
    .init(id: 3, image: "nextcloud", title: "title 4", subTitle: "subTitle 4", url: URL(string: "https://nextcloud.com/")!),
    .init(id: 4, image: "nextcloud", title: "title 5", subTitle: "subTitle 5", url: URL(string: "https://nextcloud.com/")!)
]
