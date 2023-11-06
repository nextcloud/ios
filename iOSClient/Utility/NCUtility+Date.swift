//
//  NCUtility+Date.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/11/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

extension NCUtility {

    func getTitleFromDate(_ date: Date) -> String {

        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            return DateFormatter.localizedString(from: date, dateStyle: .long, timeStyle: .none)
        }
        let compsDateImage = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let compsToday = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let compsYesterday = Calendar.current.dateComponents([.year, .month, .day], from: yesterday)
        let compsDistantPast = Calendar.current.dateComponents([.year, .month, .day], from: Date.distantPast)

        if Calendar.current.date(from: compsDateImage) == Calendar.current.date(from: compsDistantPast) {
            return NSLocalizedString("_no_date_", comment: "")
        } else if Calendar.current.date(from: compsDateImage) == Calendar.current.date(from: compsToday) {
            return NSLocalizedString("_today_", comment: "")
        } else if Calendar.current.date(from: compsDateImage) == Calendar.current.date(from: compsYesterday) {
            return NSLocalizedString("_yesterday_", comment: "")
        } else {
            return DateFormatter.localizedString(from: date, dateStyle: .long, timeStyle: .none)
        }
    }
}
