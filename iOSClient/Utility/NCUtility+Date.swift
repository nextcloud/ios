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
    func longDate(_ date: Date) -> String {
        return DateFormatter.localizedString(from: date, dateStyle: .long, timeStyle: .none)
    }

    /// Returns a localized string representing the given date in a user-friendly format.
    /// The function handles the following cases:
    /// - If the date is today: Returns "Today".
    /// - If the date is yesterday: Returns "Yesterday".
    /// - Otherwise, it returns the date in a long format (e.g., "10 February 2025").
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

    /// Represents date as relative time:  (e.g., "1 minute ago", "2 hours ago", "3 days ago", or a formatted date).
    /// The function handles the following cases:
    /// - Less than a minute: Returns "Less than a minute ago".
    /// - Less than an hour: Returns the number of minutes (e.g., "5 minutes ago").
    /// - Less than a day: Returns the number of hours (e.g., "2 hours ago").
    /// - Less than a month: Returns the number of days (e.g., "3 days ago").
    /// - More than a month: Returns the full formatted date (e.g., "Jan 10, 2025").
    func getRelativeDateTitle(_ date: Date?) -> String {
        guard let date else { return "" }
        let today = Date()
        var ti = date.timeIntervalSince(today)
        ti = ti * -1
        if ti < 60 {
            return NSLocalizedString("_less_a_minute_", comment: "")
        } else if ti < 3600 {
            let diff = Int(round(ti / 60))
            if diff == 1 {
                return NSLocalizedString("_a_minute_ago_", comment: "")
            } else {
                return String.localizedStringWithFormat(NSLocalizedString("_minutes_ago_", comment: ""), diff)
            }
        } else if ti < 86400 {
            let diff = Int(round(ti / 60 / 60))
            if diff == 1 {
                return NSLocalizedString("_an_hour_ago_", comment: "")
            } else {
                return String.localizedStringWithFormat(NSLocalizedString("_hours_ago_", comment: ""), diff)
            }
        } else if ti < 86400 * 30 {
            let diff = Int(round(ti / 60 / 60 / 24))
            if diff == 1 {
                return NSLocalizedString("_a_day_ago_", comment: "")
            } else {
                return String.localizedStringWithFormat(NSLocalizedString("_days_ago_", comment: ""), diff)
            }
        } else {
            let formatter = DateFormatter()
            formatter.formatterBehavior = .behavior10_4
            formatter.dateStyle = .medium // Returns formatted date, e.g., "Jan 10, 2025"
            return formatter.string(from: date)
        }
    }
}
