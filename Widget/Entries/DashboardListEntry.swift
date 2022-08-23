//
//  DashboardListEntry.swift
//  DashboardWidgetExtension
//
//  Created by Marino Faggiana on 22/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import WidgetKit

struct DashboardListEntry: TimelineEntry {
    let date: Date
    let dashboardDatas: [DashboardData]
}
