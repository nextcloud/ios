// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Henrik Storch
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// A table view cell for logical switches in the detaills of a share configuration.
///
class NCShareToggleCell: UITableViewCell {
    typealias CustomToggleIcon = (onIconName: ImageResource?, offIconName: ImageResource?)
    init(isOn: Bool, customIcons: CustomToggleIcon? = nil) {
        super.init(style: .default, reuseIdentifier: "toggleCell")
        self.accessibilityValue = isOn ? NSLocalizedString("_on_", comment: "") : NSLocalizedString("_off_", comment: "")
        self.tintColor = NCBrandColor.shared.brandElement
        
        guard let customIcons = customIcons,
              let iconName = isOn ? customIcons.onIconName : customIcons.offIconName else {
            
            self.accessoryType = isOn ? .checkmark : .none
            return
        }
        let checkmark = UIImage(resource: iconName).withTintColor(NCBrandColor.shared.brandElement)
        let imageView = UIImageView(image: checkmark)
        imageView.frame = CGRect(x: 0, y: 0, width: 19, height: 19)
        imageView.contentMode = .scaleAspectFit
        self.accessoryView = imageView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
