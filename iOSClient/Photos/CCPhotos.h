//
//  CCPhotos.h
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 29/07/15.
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
#import <Photos/Photos.h>
#import <ImageIO/ImageIO.h>

#import "UIScrollView+EmptyDataSet.h"
#import "OCErrorMsg.h"
#import "TWMessageBarManager.h"
#import "CCManageLocation.h"
#import "CCDetail.h"
#import "CCUtility.h"
#import "CCSection.h"
#import "CCHud.h"
#import "OCNetworking.h"
#import "CCMove.h"

@class tableMetadata;

@interface CCPhotos: UICollectionViewController <UICollectionViewDataSource, UICollectionViewDelegate, UIActionSheetDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, OCNetworkingDelegate, CCMoveDelegate>

@property (nonatomic, weak) CCDetail *detailViewController;
@property BOOL isSearchMode;

- (void)downloadFileSuccessFailure:(NSString *)fileName fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorMessage:(NSString *)errorMessage errorCode:(NSInteger)errorCode;

- (void)reloadDatasourceFromSearch:(BOOL)fromSearch;
- (void)searchPhotoVideo;

@end
