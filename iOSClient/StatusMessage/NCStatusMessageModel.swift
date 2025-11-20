// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

@Observable class NCStatusMessageModel {
    //    struct StatusPreset: Identifiable, Equatable {
    //        let id = UUID()
    //        let emoji: String
    //        let title: String
    //        let clearAfter: ClearAfter
    //    }

    enum ClearAfter: String, CaseIterable, Identifiable {
        case dontClear = "_dont_clear_"
        case thirtyMinutes = "_30_minutes_"
        case oneHour = "_an_hour_"
        case fourHours = "_4_hours_"
        case today = "_day_"
        case thisWeek = "_this_week_"

        var id: String { rawValue }
    }

    //    @ObservationIgnored let statusPresets: [StatusPreset] = [
    //        .init(emoji: "📅", title: "In a meeting", clearAfter: .oneHour),
    //        .init(emoji: "🚌", title: "Commuting", clearAfter: .thirtyMinutes),
    //        .init(emoji: "⏳", title: "Be right back", clearAfter: .thirtyMinutes),
    //        .init(emoji: "🏡", title: "Working remotely", clearAfter: .thisWeek),
    //        .init(emoji: "🤒", title: "Out sick", clearAfter: .today),
    //        .init(emoji: "🌴", title: "Vacationing", clearAfter: .dontClear)
    //    ]

    var statusPresets: [NKUserStatus] = []

    var emojiText: String = "😀"
    var statusText: String = ""
    var clearAfter: ClearAfter = .dontClear

    func chooseStatusPreset(preset: NKUserStatus, clearAtText: String) {
        emojiText = preset.icon ?? ""
        statusText = preset.message ?? ""
        clearAfter = stringToClearAfter(clearAtText)
    }

    func clearStatus() {
        emojiText = "😀"
        statusText = ""
        clearAfter = .dontClear
    }

    func getPredefinedStatusTexts(account: String) {
        Task {
            let statuses = await NextcloudKit.shared.getUserStatusPredefinedStatusesAsync(account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account, name: "getUserStatusPredefinedStatuses")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            statusPresets = statuses.userStatuses ?? []
        }
    }

    func submitStatus() {
        //        NextcloudKit.shared.setCustomMessagePredefinedAsync(messageId: emojiText, clearAt: <#T##Double#>, account: <#T##String#>)
        //        NextcloudKit.shared.setCustomMessageUserDefined(statusIcon: statusMessageEmojiTextField.text, message: message, clearAt: clearAtTimestamp, account: account) { task in
        //            Task {
        //                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.account,
        //                                                                                            name: "setCustomMessageUserDefined")
        //                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
        //            }
        //        } completion: { _, _, error in
        //            if error != .success {
        //                NCContentPresenter().showError(error: error)
        //            }
        //
        //            self.dismiss(animated: true)
    }

    func getPredefinedClearStatusText(clearAt: Date?, clearAtTime: String?, clearAtType: String?) -> String {
        // Date
        if let clearAt {
            let from = Date()
            let to = clearAt
            let day = Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
            let hour = Calendar.current.dateComponents([.hour], from: from, to: to).hour ?? 0
            let minute = Calendar.current.dateComponents([.minute], from: from, to: to).minute ?? 0

            if day > 0 {
                if day == 1 { return NSLocalizedString("_day_", comment: "") }
                return "\(day) " + NSLocalizedString("_days_", comment: "")
            }

            if hour > 0 {
                if hour == 1 { return NSLocalizedString("_an_hour_", comment: "") }
                if hour == 4 { return NSLocalizedString("_4_hour_", comment: "") }
                return "\(hour) " + NSLocalizedString("_hours_", comment: "")
            }

            if minute > 0 {
                if minute >= 25 && minute <= 30 { return NSLocalizedString("_30_minutes_", comment: "") }
                if minute > 30 { return NSLocalizedString("_an_hour_", comment: "") }
                return "\(minute) " + NSLocalizedString("_minutes_", comment: "")
            }
        }
        // Period
        if let clearAtTime, clearAtType == "period" {
            switch clearAtTime {
            case "3600":
                return NSLocalizedString("_an_hour_", comment: "")
            case "1800":
                return NSLocalizedString("_30_minutes_", comment: "")
            default:
                return NSLocalizedString("_dont_clear_", comment: "")
            }
        }
        // End of
        if let clearAtTime, clearAtType == "end-of" {
            if clearAtTime == "day" {
                return NSLocalizedString("_day_", comment: "")
            }
        }

        return NSLocalizedString("_dont_clear_", comment: "")
    }

    func stringToClearAfter(_ clearAtString: String) -> ClearAfter {
        switch clearAtString {
        case NSLocalizedString("_30_minutes_", comment: ""):
            return .thirtyMinutes
        case NSLocalizedString("_an_hour_", comment: ""):
            return .oneHour
        case NSLocalizedString("_4_hours_", comment: ""):
            return .fourHours
        case NSLocalizedString("_day_", comment: ""):
            return .today
        case NSLocalizedString("_this_week_", comment: ""):
            return .thisWeek
        default:
            return .dontClear
        }
    }

    func getClearAt(_ clearAtString: String) -> Double {
        let now = Date()
        let calendar = Calendar.current
        let gregorian = Calendar(identifier: .gregorian)
        let midnight = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: midnight) else { return 0 }
        guard let startweek = gregorian.date(from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return 0 }
        guard let endweek = gregorian.date(byAdding: .day, value: 6, to: startweek) else { return 0 }

        switch clearAtString {
        case NSLocalizedString("_dont_clear_", comment: ""):
            return 0
        case NSLocalizedString("_30_minutes_", comment: ""):
            let date = now.addingTimeInterval(1800)
            return date.timeIntervalSince1970
        case NSLocalizedString("_1_hour_", comment: ""), NSLocalizedString("_an_hour_", comment: ""):
            let date = now.addingTimeInterval(3600)
            return date.timeIntervalSince1970
        case NSLocalizedString("_4_hours_", comment: ""):
            let date = now.addingTimeInterval(14400)
            return date.timeIntervalSince1970
        case NSLocalizedString("_day_", comment: ""):
            return tomorrow.timeIntervalSince1970
        case NSLocalizedString("_this_week_", comment: ""):
            return endweek.timeIntervalSince1970
        default:
            return 0
        }
    }
}


