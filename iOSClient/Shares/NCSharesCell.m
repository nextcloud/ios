//
//  NCSharesCell.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 05/06/17.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "NCSharesCell.h"

@implementation NCSharesCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code

        
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews {
    
    [super layoutSubviews];
    
    for (NSLayoutConstraint *constraint in self.constraints) {
        constraint.constant = self.frame.size.width - self.contentView.frame.size.width;
    }
}

///-----------------------------------
/// @name scrollViewWillBeginDecelerating
///-----------------------------------

/**
 * Method to initialize the position where we make the swipe in order to detect the direction
 *
 * @param UIScrollView -> scrollView
 */
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    _lastContentOffset = scrollView.contentOffset.x;
}

@end
