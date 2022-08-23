//
//  DashboardNetworking.swift
//  Widget
//
//  Created by Marino Faggiana on 22/08/22.
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

import Foundation

let dashboardDatasTest: [DashboardData] = [
    .init(id: 0, image: "nextcloud", title: "title 1", subTitle: "subTitle 1", url: URL(string: "https://nextcloud.com/")!),
    .init(id: 1, image: "nextcloud", title: "title 2", subTitle: "subTitle 2", url: URL(string: "https://nextcloud.com/")!),
    .init(id: 2, image: "nextcloud", title: "title 3", subTitle: "subTitle 3", url: URL(string: "https://nextcloud.com/")!),
    .init(id: 3, image: "nextcloud", title: "title 4", subTitle: "subTitle 4", url: URL(string: "https://nextcloud.com/")!),
    .init(id: 4, image: "nextcloud", title: "title 5", subTitle: "subTitle 5", url: URL(string: "https://nextcloud.com/")!)
]

func readDashboard(completion: @escaping (_ dashboardData: [DashboardData]) -> Void) {

    guard let activeAccount = NCManageDatabase.shared.getActiveAccount() else {
        return completion(dashboardDatasTest)
    }

    completion(dashboardDatasTest)
}
