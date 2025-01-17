//
//  FileActionsHeader.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 23.08.2024.
//  Copyright © 2024 STRATO AG
//

import UIKit

enum FileActionsHeaderSelectionState {
	case none
	case some(Int)
	case all
}

class FileActionsHeader: UIView {
	@IBOutlet weak var contentView: UIView!
	
	// MARK: - non-editign mode view
	@IBOutlet weak private var vHeaderNonEditingMode: UIView?
	@IBOutlet weak private var btnSort: UIButton?
	@IBOutlet weak private var btnSelect: UIButton?
	@IBOutlet weak private var btnViewMode: UIButton?
	    
    @IBAction func onBtnSelectTap(_ sender: Any) {
		setIsEditingMode(isEditingMode: true)
		onSelectModeChange?(true)
	}
	
	// MARK: - editign mode view
	@IBOutlet weak private var vHeaderEditingMode: UIView?
	@IBOutlet weak private var btnSelectAll: UIButton?
	@IBOutlet weak private var btnCloseSelection: UIButton?
	@IBOutlet weak private var lblSelectionDescription: UILabel?

	private var grayButtonTintColor: UIColor {
        UIColor(resource: .FileActionsHeader.grayButtonTint)
	}
	
	@IBAction func onBtnSelectAllTap(_ sender: Any) {
		onSelectAll?()
	}
	
	@IBAction func onBtnCloseSelectionTap(_ sender: Any) {
		setIsEditingMode(isEditingMode: false)
		onSelectModeChange?(false)
	}
	
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	private func commonInit() {
		Bundle.main.loadNibNamed(String(describing:FileActionsHeader.self),
										 owner: self,
										 options: nil)
		addSubview(contentView)
        contentView.backgroundColor = NCBrandColor.shared.appBackgroundColor
		contentView.frame = bounds
		contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
	}
	
	// MARK: - public
	func enableSorting(enable: Bool) {
		btnSort?.isHidden = !enable
	}
	
	var onSelectModeChange: ((_ isSelectionMode: Bool) -> Void)?
	var onSelectAll: (() -> Void)?
	
	func setSortingMenu(sortingMenuElements: [UIMenuElement], title: String?, image: UIImage?) {
		btnSort?.menu = UIMenu(children: sortingMenuElements)
		btnSort?.showsMenuAsPrimaryAction = true
		btnSort?.setTitle(title, for: .normal)
		btnSort?.setImage(image?.templateRendered(), for: .normal)
		btnSort?.semanticContentAttribute = UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? .forceLeftToRight : .forceRightToLeft
	}
	
	func setViewModeMenu(viewMenuElements: [UIMenuElement], image: UIImage?) {
		btnViewMode?.menu = UIMenu(children: viewMenuElements)
		btnViewMode?.showsMenuAsPrimaryAction = true
		btnViewMode?.setImage(image?.templateRendered(), for: .normal)
	}
    
    func showViewModeButton(_ show: Bool) {
        btnViewMode?.isHidden = !show
    }
	
	func setIsEditingMode(isEditingMode: Bool) {
		vHeaderEditingMode?.isHidden = !isEditingMode
		vHeaderNonEditingMode?.isHidden = isEditingMode
	}
	
	func setSelectionState(selectionState: FileActionsHeaderSelectionState) {
		var textDescription = ""
        var imageResource: ImageResource = .FileSelection.listItemDeselected
        var selectAllImageColor: UIColor = .clear
		
		// MARK: Files Header
		switch selectionState {
		case .none:
			textDescription = NSLocalizedString("_select_selectionLabel_selectAll_", tableName: nil, bundle: Bundle.main, value: "select all", comment: "")
            imageResource = .FileSelection.listItemDeselected
            selectAllImageColor = grayButtonTintColor
		case .some(let count):
			textDescription = selectionDescription(for: count)
            imageResource = .FileSelection.listItemSomeSelected
            selectAllImageColor = NCBrandColor.shared.brandElement
		case .all:
			textDescription = NSLocalizedString("_select_selectionLabel_deselectAll_", tableName: nil, bundle: Bundle.main, value: "deselect all", comment: "")
            imageResource = .FileSelection.listItemSelected
            selectAllImageColor = NCBrandColor.shared.brandElement
		}

		lblSelectionDescription?.text = textDescription
		
		var selectAllImage = UIImage(resource: imageResource)
        var closeImage = UIImage(resource: .FileSelection.selectionModeClose)

        closeImage = closeImage.withTintColor(grayButtonTintColor)
        selectAllImage = selectAllImage.withTintColor(selectAllImageColor)

		btnSelectAll?.setBackgroundImage(selectAllImage, for: .normal)
		btnCloseSelection?.setBackgroundImage(closeImage, for: .normal)

		func selectionDescription(for count: Int) -> String {
			if count == 1 {
				return NSLocalizedString("_select_selectionLabel_oneItemSelected_", tableName: nil, bundle: Bundle.main, value: "one item selected", comment: "")
			}
			return String.localizedStringWithFormat(NSLocalizedString("_select_selectionLabel_manyItemsSelected_", tableName: nil, bundle: Bundle.main, value: "%@ items selected", comment: ""), "\(count)")
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		if let selectionButtonWidth = btnSelect?.bounds.width {
			btnSelect?.layer.cornerRadius = selectionButtonWidth / 2
		}
		btnSelect?.imageView?.contentMode = .scaleToFill
        btnSelect?.setImage(UIImage(resource: .FileSelection.filesSelection), for: .normal)
	}
}

extension UIImage {
	func templateRendered() -> UIImage? {
		self.withRenderingMode(.alwaysTemplate)
	}
}
