// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

@MainActor
final class NCMediaDatePickerViewController: UIViewController {
    var onDateSelected: ((NCYearMonth) -> Void)?

    private let availableYearMonths: [NCYearMonth]
    private let selectedYearMonth: NCYearMonth?

    private let pickerView = UIPickerView()

    init(
        availableYearMonths: [NCYearMonth],
        selectedYearMonth: NCYearMonth?
    ) {
        self.availableYearMonths = availableYearMonths
        self.selectedYearMonth = selectedYearMonth

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        pickerView.dataSource = self
        pickerView.delegate = self
        pickerView.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(
            NSLocalizedString("_cancel_", comment: ""),
            for: .normal
        )
        cancelButton.addTarget(
            self,
            action: #selector(cancelButtonTouchUpInside),
            for: .touchUpInside
        )

        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle(
            NSLocalizedString("_go_to_", comment: ""),
            for: .normal
        )
        confirmButton.titleLabel?.font = .systemFont(
            ofSize: 17,
            weight: .semibold
        )
        confirmButton.addTarget(
            self,
            action: #selector(confirmButtonTouchUpInside),
            for: .touchUpInside
        )

        let buttonsStackView = UIStackView(
            arrangedSubviews: [
                cancelButton,
                UIView(),
                confirmButton
            ]
        )
        buttonsStackView.axis = .horizontal
        buttonsStackView.alignment = .center
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(pickerView)
        view.addSubview(buttonsStackView)

        NSLayoutConstraint.activate([
            buttonsStackView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            buttonsStackView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 20
            ),
            buttonsStackView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -20
            ),
            buttonsStackView.heightAnchor.constraint(equalToConstant: 44),

            pickerView.topAnchor.constraint(
                equalTo: buttonsStackView.bottomAnchor,
                constant: 8
            ),
            pickerView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            pickerView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            pickerView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor
            )
        ])

        selectCurrentYearMonth()
    }

    private func selectCurrentYearMonth() {
        guard let selectedYearMonth,
              let row = availableYearMonths.firstIndex(
                of: selectedYearMonth
              ) else {
            return
        }

        pickerView.selectRow(
            row,
            inComponent: 0,
            animated: false
        )
    }

    @objc
    private func cancelButtonTouchUpInside() {
        dismiss(animated: true)
    }

    @objc
    private func confirmButtonTouchUpInside() {
        let row = pickerView.selectedRow(inComponent: 0)

        guard availableYearMonths.indices.contains(row) else {
            return
        }

        let selectedYearMonth = availableYearMonths[row]

        dismiss(animated: true) { [weak self] in
            self?.onDateSelected?(selectedYearMonth)
        }
    }
}

extension NCMediaDatePickerViewController: UIPickerViewDataSource {
    nonisolated func numberOfComponents(
        in pickerView: UIPickerView
    ) -> Int {
        1
    }

    nonisolated func pickerView(
        _ pickerView: UIPickerView,
        numberOfRowsInComponent component: Int
    ) -> Int {
        MainActor.assumeIsolated {
            availableYearMonths.count
        }
    }
}

extension NCMediaDatePickerViewController: UIPickerViewDelegate {
    nonisolated func pickerView(
        _ pickerView: UIPickerView,
        titleForRow row: Int,
        forComponent component: Int
    ) -> String? {
        MainActor.assumeIsolated {
            guard availableYearMonths.indices.contains(row) else {
                return nil
            }

            let yearMonth = availableYearMonths[row]

            var components = DateComponents()
            components.year = yearMonth.year
            components.month = yearMonth.month
            components.day = 1

            guard let date = Calendar.current.date(
                from: components
            ) else {
                return nil
            }

            return date.formatted(
                .dateTime
                    .month(.wide)
                    .year()
            )
        }
    }

    nonisolated func pickerView(
        _ pickerView: UIPickerView,
        rowHeightForComponent component: Int
    ) -> CGFloat {
        44
    }
}
