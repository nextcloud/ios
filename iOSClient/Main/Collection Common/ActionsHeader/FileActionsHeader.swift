//
//  FileActionsHeader.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 23.08.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import UIKit

enum FileActionsHeaderSelectionState {
	case none
	case some(Int)
	case all(Int)
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
		contentView.frame = bounds
		contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
	}
	
	// MARK: - public
	var onSelectModeChange: ((_ isSelectionMode: Bool) -> Void)?
	var onSelectAll: (() -> Void)?
	
	func setSortingMenu(sortingMenuElements: [UIMenuElement], title: String?, image: UIImage?, tintColor: UIColor) {
		btnSort?.menu = UIMenu(children: sortingMenuElements)
		btnSort?.showsMenuAsPrimaryAction = true
		btnSort?.setTitle(title, for: .normal)
		btnSort?.tintColor = tintColor
		btnSort?.setImage(formattedHeaderImage(image: image), for: .normal)
		btnSort?.semanticContentAttribute = UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? .forceLeftToRight : .forceRightToLeft
	}
	
	func setViewMenu(viewMenuElements: [UIMenuElement], image: UIImage?, tintColor: UIColor) {
		btnViewMode?.menu = UIMenu(children: viewMenuElements)
		btnViewMode?.showsMenuAsPrimaryAction = true
		btnViewMode?.tintColor = tintColor
		btnViewMode?.setImage(formattedHeaderImage(image: image), for: .normal)
	}
	
	func setIsEditingMode(isEditingMode: Bool) {
		vHeaderEditingMode?.isHidden = !isEditingMode
		vHeaderNonEditingMode?.isHidden = isEditingMode
	}
	
	func setSelectionState(selectionState: FileActionsHeaderSelectionState) {
		var textDescription = ""
		var imageName = ""
		
		switch selectionState {
		case .none:
			textDescription = "None item selected"
			imageName = "list_item_deselected"
		case .some(let count):
			textDescription = selectionDescription(for: count)
			imageName = "list_item_some_selected"
		case .all(let count):
			textDescription = selectionDescription(for: count)
			imageName = "list_item_selected"
		}

		lblSelectionDescription?.text = textDescription
		btnSelectAll?.setImage(UIImage(named: imageName), for: .normal)
		
		func selectionDescription(for count: Int) -> String {
			"\(count) item\(count > 1 ? "s" : "") selected"
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		if let selectionButtonWidth = btnSelect?.bounds.width {
			btnSelect?.layer.cornerRadius = selectionButtonWidth / 2
		}
	}
	
	// MARK: -
	private func formattedHeaderImage(image: UIImage?) -> UIImage? {
		return image?.withRenderingMode(.alwaysTemplate)
	}
}
