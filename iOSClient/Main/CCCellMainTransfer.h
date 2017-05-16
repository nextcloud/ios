//
//  CCCellMainTransfer.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 05/05/15.
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

#import <UIKit/UIKit.h>

@interface CCCellMainTransfer : UITableViewCell

@property(nonatomic, weak) IBOutlet UIImageView *fileImageView;
@property(nonatomic, weak) IBOutlet UIImageView *statusImageView;
@property(nonatomic, weak) IBOutlet UIImageView *offlineImageView;
@property(nonatomic, weak) IBOutlet UIImageView *synchronizedImageView;
@property(nonatomic, weak) IBOutlet UIImageView *sharedImageView;

@property(nonatomic, weak) IBOutlet UILabel *labelTitle;
@property(nonatomic, weak) IBOutlet UILabel *labelInfoFile;

@property(nonatomic, weak) IBOutlet UIProgressView *progressView;
@property(nonatomic, weak) IBOutlet UIButton *cancelTaskButton;
@property(nonatomic, weak) IBOutlet UIButton *reloadTaskButton;
@property(nonatomic, weak) IBOutlet UIButton *stopTaskButton;

//Last position of the scroll of the swipe
@property (nonatomic, assign) CGFloat lastContentOffset;

//Index path of the cell swipe gesture ocured
@property (nonatomic, strong) NSIndexPath *indexPath;


@end
