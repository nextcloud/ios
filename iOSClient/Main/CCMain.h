//
//  CCMain.h
//  Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
//  Copyright (c) 2014 Marino Faggiana. All rights reserved.
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
#import <MobileCoreServices/MobileCoreServices.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>

#import "NSString+TruncateToWidth.h"
#import "CCLogin.h"
#import "CCGraphics.h"
#import "CCSection.h"
#import "CCUtility.h"
#import "CCHud.h"
#import "CCPeekPop.h"
#import <MGSwipeTableCell/MGSwipeTableCell.h>

@class tableMetadata;
@class NCViewRichWorkspace;

@interface CCMain : UITableViewController <UIActionSheetDelegate, UIGestureRecognizerDelegate, UIViewControllerPreviewingDelegate, UISplitViewControllerDelegate, UIPopoverControllerDelegate, UIDocumentPickerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, UIScrollViewDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate>

@property (nonatomic, strong) NCViewRichWorkspace *viewRichWorkspace;

@property (nonatomic, strong) tableMetadata *metadata;
@property (nonatomic, strong) tableMetadata *metadataForPushDetail;
@property (nonatomic, strong) NSString *selectorForPushDetail;

@property (nonatomic, strong) UIButton *sortButton;

@property (nonatomic, strong) NSString *serverUrl;
@property (nonatomic, strong) NSString *titleMain;
@property (nonatomic, strong) NSString *richWorkspaceText;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UITapGestureRecognizer *singleFingerTap;
@property (nonatomic, strong) NSString *blinkFileNamePath;
@property (nonatomic, readonly, strong) UIImage *cellFavouriteImage;
@property (nonatomic, readonly, strong) UIImage *cellTrashImage;

@property BOOL isSelectedMode;

- (void)shouldPerformSegue:(tableMetadata *)metadata selector:(NSString *)selector;
- (void)performSegueDirectoryWithMetadata:(tableMetadata *)metadata blinkFileNamePath:(NSString *)blinkFileNamePath;

- (void)saveToPhotoAlbum:(tableMetadata *)metadata;

- (void)copyFileToPasteboard:(tableMetadata *)metadata;

- (void)setUINavigationBarDefault;

- (void)readFolder:(NSString *)serverUrl;
- (void)readFileReloadFolder;
- (void)setTableViewHeader;

//expose methods for swift
- (void)didSelectAll;
- (void)deleteMetadatas;
- (void)saveSelectedFiles;
- (void)moveOpenWindow:(NSArray *)indexPaths;

- (void)actionDelete:(NSIndexPath *)indexPath;

@end

