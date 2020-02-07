//
//  CCFavorites.h
//  Nextcloud
//
//  Created by Marino Faggiana on 16/01/17.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>

#import "CCDetail.h"
#import "AHKActionSheet.h"
#import "CCCellMain.h"
#import "CCCellMainTransfer.h"
#import "CCUtility.h"
#import "CCMain.h"
#import "CCGraphics.h"

@class tableMetadata;

@interface CCFavorites : UIViewController <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, MGSwipeTableCellDelegate, UIViewControllerPreviewingDelegate>

@property (nonatomic, weak) IBOutlet UITableView *tableView;

@property (nonatomic, strong) tableMetadata *metadata;
@property (nonatomic, strong) tableMetadata *metadataForPushDetail;
@property (nonatomic, strong) NSString *selectorForPushDetail;
@property (nonatomic, strong) NSString *serverUrl;
@property (nonatomic, strong) NSString *titleViewControl;

@property (nonatomic, weak) CCDetail *detailViewController;

- (void)shouldPerformSegue:(tableMetadata *)metadata selector:(NSString *)selector;
- (void)reloadDatasource:(NSString *)ocId action:(NSInteger)action;
- (void)listingFavorites;

- (void)actionDelete:(NSIndexPath *)indexPath;
- (void)settingFavorite:(tableMetadata *)metadata favorite:(BOOL)favorite;

@end
