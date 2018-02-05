//
//  CCMain.h
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 04/09/14.
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
#import <MobileCoreServices/MobileCoreServices.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>

#import "TWMessageBarManager.h"
#import "MGSwipeTableCell.h"
#import "AHKActionSheet.h"
#import "CTAssetSelectionLabel.h"
#import "BKPasscodeViewController.h"
#import "NSString+TruncateToWidth.h"
#import "UIScrollView+EmptyDataSet.h"
#import "CCLogin.h"
#import "CCCellMain.h"
#import "CCCellMainTransfer.h"
#import "CCMove.h"
#import "CCDetail.h"
#import "CTAssetsPickerController.h"
#import "CCShareOC.h"
#import "CCShareInfoCMOC.h"
#import "CCNetworking.h"
#import "CCMove.h"
#import "CCGraphics.h"
#import "CCSection.h"
#import "CCUtility.h"
#import "CCHud.h"
#import "CCMenuAccount.h"
#import "CCPeekPop.h"

@class tableMetadata;

@interface CCMain : UIViewController <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate, UIGestureRecognizerDelegate, UIDocumentInteractionControllerDelegate, UIViewControllerPreviewingDelegate, CCMoveDelegate, CTAssetsPickerControllerDelegate, BKPasscodeViewControllerDelegate, UISplitViewControllerDelegate, UIPopoverControllerDelegate, CCNetworkingDelegate, CCShareOCDelegate, CCPeekPopDelegate, UIDocumentMenuDelegate, UIDocumentPickerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, UIScrollViewDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSString *serverUrl;
@property (nonatomic, strong) NSString *titleMain;
@property (nonatomic, strong) NSString *textBackButton;
@property (nonatomic, weak) CCShareOC *shareOC;
@property (nonatomic, weak) CCDetail *detailViewController;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UIView *reMenuBackgroundView;
@property (nonatomic, strong) UITapGestureRecognizer *singleFingerTap;
@property (nonatomic, strong) UIImage *imageTitle;

- (void)closeAllMenu;
- (void)returnCreate:(NSInteger)type;

- (void)readFolder:(NSString *)serverUrl;
- (void)readFileReloadFolder;

- (void)uploadFileAsset:(NSMutableArray *)assets serverUrl:(NSString *)serverUrl useSubFolder:(BOOL)useSubFolder session:(NSString *)session;

- (void)reloadTaskButton:(tableMetadata *)metadata;
- (void)cancelTaskButton:(tableMetadata *)metadata reloadTable:(BOOL)reloadTable;
- (void)stopTaskButton:(tableMetadata *)metadata;

- (void)reloadDatasource;
- (void)reloadDatasource:(NSString *)serverUrl;

- (void)requestServerCapabilities;
- (void)middlewarePing;

- (void)openWindowShare:(tableMetadata *)metadata;
- (void)clearDateReadDataSource:(NSNotification *)notification;
- (void)cancelSearchBar;

@end

