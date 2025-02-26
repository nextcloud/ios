// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Henrik Storch
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// A table view cell for logical switches in the detaills of a share configuration.
///
class NCShareToggleCell: UITableViewCell {
    typealias CustomToggleIcon = (onIconName: String?, offIconName: String?)
    init(isOn: Bool, customIcons: CustomToggleIcon? = nil) {
        super.init(style: .default, reuseIdentifier: "toggleCell")
        self.accessibilityValue = isOn ? NSLocalizedString("_on_", comment: "") : NSLocalizedString("_off_", comment: "")

        guard let customIcons = customIcons,
              let iconName = isOn ? customIcons.onIconName : customIcons.offIconName else {
            self.accessoryType = isOn ? .checkmark : .none
            return
        }
        let image = NCUtility().loadImage(named: iconName, colors: [NCBrandColor.shared.customer], size: self.frame.height - 26)
        self.accessoryView = UIImageView(image: image)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
