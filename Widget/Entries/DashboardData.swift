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
