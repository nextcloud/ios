//
//  MediaCell.swift
//  Nextcloud
//
//  Created by Milen on 19.01.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

class MediaCell: UICollectionViewCell {
    static let identifier = "MediaCell"

    // Add subviews and set up the cell
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        // Configure label...
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(titleLabel)
        contentView.backgroundColor = .systemBlue
        titleLabel.frame = contentView.bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: tableMetadata) {
        titleLabel.text = item.name
    }
}
