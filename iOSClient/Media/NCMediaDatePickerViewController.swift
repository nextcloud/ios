// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

@MainActor
final class NCMediaDatePickerViewController: UIHostingController<NCMediaDatePickerView> {
    private let model: NCMediaDatePickerModel

    var onDateSelected: ((NCYearMonth) -> Void)? {
        get {
            model.onDateSelected
        }
        set {
            model.onDateSelected = newValue
        }
    }

    init(
        availableYearMonths: [NCYearMonth],
        selectedYearMonth: NCYearMonth?
    ) {
        let model = NCMediaDatePickerModel(
            availableYearMonths: availableYearMonths,
            selectedYearMonth: selectedYearMonth
        )

        self.model = model

        super.init(
            rootView: NCMediaDatePickerView(model: model)
        )

        view.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Model

@MainActor
final class NCMediaDatePickerModel: ObservableObject {
    let availableYearMonths: [NCYearMonth]

    @Published var selectedYearMonth: NCYearMonth?

    var onDateSelected: ((NCYearMonth) -> Void)?

    init(
        availableYearMonths: [NCYearMonth],
        selectedYearMonth: NCYearMonth?
    ) {
        self.availableYearMonths = availableYearMonths

        if let selectedYearMonth,
           availableYearMonths.contains(selectedYearMonth) {
            self.selectedYearMonth = selectedYearMonth
        } else {
            self.selectedYearMonth = availableYearMonths.first
        }
    }

    func title(for yearMonth: NCYearMonth) -> String {
        var components = DateComponents()
        components.year = yearMonth.year
        components.month = yearMonth.month
        components.day = 1

        guard let date = Calendar.current.date(from: components) else {
            return "\(yearMonth.month) \(yearMonth.year)"
        }

        return date.formatted(
            .dateTime
                .month(.wide)
                .year()
        )
    }
}

// MARK: - View

struct NCMediaDatePickerView: View {
    @ObservedObject var model: NCMediaDatePickerModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(NSLocalizedString("_select_date_", comment: ""))
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)

                HStack {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .modifier(NCMediaCloseButtonStyle())
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(
                        Text(NSLocalizedString("_close_", comment: ""))
                    )
                }
            }
            .frame(height: 52)
            .padding(.horizontal, 16)

            Picker("", selection: $model.selectedYearMonth) {
                ForEach(model.availableYearMonths, id: \.self) { yearMonth in
                    Text(model.title(for: yearMonth))
                        .tag(Optional(yearMonth))
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .clipped()
            .onChange(of: model.selectedYearMonth) { _, selectedYearMonth in
                guard let selectedYearMonth else {
                    return
                }

                model.onDateSelected?(selectedYearMonth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NCMediaCloseButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content
                .buttonStyle(.plain)
        }
    }
}

#if DEBUG
#Preview("Media Date Picker") {
    NCMediaDatePickerView(
        model: NCMediaDatePickerModel(
            availableYearMonths: [
                NCYearMonth(year: 2026, month: 7),
                NCYearMonth(year: 2026, month: 6),
                NCYearMonth(year: 2026, month: 5),
                NCYearMonth(year: 2026, month: 4),
                NCYearMonth(year: 2026, month: 3),
                NCYearMonth(year: 2026, month: 2),
                NCYearMonth(year: 2026, month: 1),
                NCYearMonth(year: 2025, month: 12),
                NCYearMonth(year: 2025, month: 11)
            ],
            selectedYearMonth: NCYearMonth(year: 2026, month: 7)
        )
    )
    .frame(height: 340)
}
#endif
