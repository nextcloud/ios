// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

@Observable class NCStatusMessageModel {
    enum ClearAfter: String, CaseIterable, Identifiable {
        case dontClear = "_dont_clear_"
        case thirtyMinutes = "_30_minutes_"
        case fifteenMinutes = "_15_minutes_"
        case oneHour = "_an_hour_"
        case fourHours = "_4_hours_"
        case today = "_day_"
        case thisWeek = "_this_week_"

        var id: String { rawValue }
    }

    var predefinedStatuses: [NKUserStatus] = []

    var emojiText: String = ""
    var statusText: String = ""
    var clearAfterString = "_dont_clear_"

    func chooseStatusPreset(preset: NKUserStatus, clearAtText: String) {
        emojiText = preset.icon ?? ""
        statusText = preset.message ?? ""
        clearAfterString = clearAtText
    }

    func getStatus(account: String) {
        Task {
            let result = await NextcloudKit.shared.getUserStatusAsync(account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account, name: "getUserStatus")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }

            if result.error == .success {
                emojiText = result.icon ?? "😀"
                statusText = result.message ?? ""
                clearAfterString = getPredefinedClearStatusString(clearAt: result.clearAt, clearAtTime: "", clearAtType: "")
            }
        }
    }

    func clearStatus(account: String) {
        Task {
            let result = await NextcloudKit.shared.clearMessageAsync(account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account, name: "clearMessage")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }

            if result.error != .success {
                NCContentPresenter().showError(error: result.error)
            }
        }
    }

    func getPredefinedStatusTexts(account: String) {
        Task {
            let result = await NextcloudKit.shared.getUserStatusPredefinedStatusesAsync(account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account, name: "getUserStatusPredefinedStatuses")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }

            if result.error == .success {
                predefinedStatuses = isXcodeRunningForPreviews ? createStatusesForPreview() : result.userStatuses ?? []
            } else {
                NCContentPresenter().showError(error: result.error)
            }
        }
    }

    func submitStatus(account: String) {
        Task {
            let result = await NextcloudKit.shared.setCustomMessageUserDefinedAsync(statusIcon: emojiText, message: statusText, clearAt: getClearAt(clearAfterString), account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account, name: "setCustomMessageUserDefined")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }

            if result.error != .success {
                NCContentPresenter().showError(error: result.error)
            }
        }
    }

    func setAccountUserStatus(account: String) {
        Task {
            let result = await NextcloudKit.shared.getUserStatusAsync(account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                name: "getUserStatus")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }

            if result.error == .success {
                await NCManageDatabase.shared.setAccountUserStatusAsync(userStatusClearAt: result.clearAt,
                                                                        userStatusIcon: result.icon,
                                                                        userStatusMessage: result.message,
                                                                        userStatusMessageId: result.messageId,
                                                                        userStatusMessageIsPredefined: result.messageIsPredefined,
                                                                        userStatusStatus: result.status,
                                                                        userStatusStatusIsUserDefined: result.statusIsUserDefined,
                                                                        account: result.account)
            } else {
                NCContentPresenter().showError(error: result.error)
            }
        }
    }

    func getPredefinedClearStatusString(clearAt: Date?, clearAtTime: String?, clearAtType: String?) -> String {
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
            case "900":
                return NSLocalizedString("_15_minutes_", comment: "")
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

    private func getClearAt(_ clearAtString: String) -> Double {
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
        case NSLocalizedString("_15_minutes_", comment: ""):
            let date = now.addingTimeInterval(900)
            return date.timeIntervalSince1970
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

    private func createStatusesForPreview() -> [NKUserStatus] {
        let meeting = NKUserStatus()
        meeting.clearAt = nil
        meeting.clearAtTime = "3600"
        meeting.clearAtType = "period"
        meeting.icon = "📅"
        meeting.id = "meeting"
        meeting.message = "In a meeting"
        meeting.predefined = true
        meeting.status = "busy"
        meeting.userId = "preview_user"

        let commuting = NKUserStatus()
        commuting.clearAt = nil
        commuting.clearAtTime = "1800"
        commuting.clearAtType = "period"
        commuting.icon = "🚌"
        commuting.id = "commuting"
        commuting.message = "Commuting"
        commuting.predefined = true
        commuting.status = "away"
        commuting.userId = "preview_user"

        return [meeting, commuting]
    }
}
