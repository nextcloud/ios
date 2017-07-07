//
//  CCFavorites.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 16/01/17.
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

#import "CCFavorites.h"
#import "AppDelegate.h"
#import "CCSynchronize.h"

#import "NCBridgeSwift.h"

@interface CCFavorites () <CCActionsDeleteDelegate, CCActionsSettingFavoriteDelegate>
{
    NSArray *_dataSource;
    BOOL _reloadDataSource;
    
    CCHud *_hudDeterminate;
}
@end

@implementation CCFavorites

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
        
        app.activeFavorites = self;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Custom Cell
    [self.tableView registerNib:[UINib nibWithNibName:@"CCFavoritesCell" bundle:nil] forCellReuseIdentifier:@"Cell"];

    // dataSource
    _dataSource = [NSMutableArray new];
    
    // Metadata
    _metadata = [tableMetadata new];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 1)];
    self.tableView.separatorColor = [NCBrandColor sharedInstance].seperator;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    self.tableView.delegate = self;
    
    // calculate _serverUrl
    if (!_serverUrl)
        _serverUrl = nil;
  
    // Title
    if (_titleViewControl)
        self.title = _titleViewControl;
    else
        self.title = NSLocalizedString(@"_favorites_", nil);
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
    [app aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Plus Button
    [app plusButtonVisibile:true];
    
    [self reloadDatasource];
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [app changeTheming:self];
    
    // Reload Table View
    [self.tableView reloadData];
}

- (void)triggerProgressTask:(NSNotification *)notification
{
    NSDictionary *dict = notification.userInfo;
    float progress = [[dict valueForKey:@"progress"] floatValue];
    
    if (progress == 0)
        [self.navigationController cancelCCProgress];
    else
        [self.navigationController setCCProgressPercentage:progress*100 andTintColor:[NCBrandColor sharedInstance].navigationBarProgress];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIColor whiteColor];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIImage imageNamed:@"favoriteNoFiles"];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = [NSString stringWithFormat:@"%@", NSLocalizedString(@"_favorite_no_files_", nil)];
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:[UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = [NSString stringWithFormat:@"\n%@", NSLocalizedString(@"_tutorial_favorite_view_", nil)];
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0], NSForegroundColorAttributeName: [UIColor lightGrayColor], NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delete <delegate> =====
#pragma--------------------------------------------------------------------------------------------

- (void)deleteFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSLog(@"[LOG] Delete error %@", message);
}

- (void)deleteFileOrFolderSuccess:(CCMetadataNet *)metadataNet
{
    [self reloadDatasource];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Favorite <delegate> =====
#pragma--------------------------------------------------------------------------------------------

- (void)settingFavoriteFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSLog(@"[LOG] Remove Favorite error %@", message);
}

- (void)settingFavoriteSuccess:(CCMetadataNet *)metadataNet
{
    [[NCManageDatabase sharedInstance] setMetadataFavoriteWithFileID:metadataNet.fileID favorite:[metadataNet.options boolValue]];
 
    [self reloadDatasource];
}

- (void)readListingFavorites
{
    // test
    if (app.activeAccount.length == 0)
        return;
    
    // verify is offline procedure is in progress selectorDownloadSynchronize
    if ([[app verifyExistsInQueuesDownloadSelector:selectorDownloadSynchronize] count] > 0)
        return;
    
    [[CCActions sharedInstance] listingFavorites:@"" delegate:self];
}

- (void)addFavoriteFolder:(NSString *)serverUrl
{
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
    NSString *selector;
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionReadFolder;
    metadataNet.directoryID = directoryID;
    
    if ([CCUtility getFavoriteOffline])
        selector = selectorReadFolderWithDownload;
    else
        selector = selectorReadFolder;
    
    metadataNet.selector = selector;
    metadataNet.serverUrl = serverUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:[CCSynchronize sharedSynchronize] metadataNet:metadataNet];
}

- (void)listingFavoritesSuccess:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas
{
    // verify active user
    tableAccount *record = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if (![record.account isEqualToString:metadataNet.account])
        return;
    
    NSString *father = @"";
    NSMutableArray *filesEtag = [NSMutableArray new];
    
    for (tableMetadata *metadata in metadatas) {
        
        // type of file
        NSInteger typeFilename = [CCUtility getTypeFileName:metadata.fileName];
        
        // do not insert cryptated favorite file
        if (typeFilename == k_metadataTypeFilenameCrypto || typeFilename == k_metadataTypeFilenamePlist)
            continue;
        
        // insert for test NOT favorite
        [filesEtag addObject:metadata.fileID];
        
        // Get ServerUrl
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
        serverUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileNameData];
        
        if (![serverUrl containsString:father]) {
            
            if (metadata.directory) {
                
                NSString *selector;
                
                if ([CCUtility getFavoriteOffline])
                    selector = selectorReadFolderWithDownload;
                else
                    selector = selectorReadFolder;
                
                [[CCSynchronize sharedSynchronize] synchronizedFolder:serverUrl selector:selector];
                
            } else {
                
                if ([CCUtility getFavoriteOffline])
                    [[CCSynchronize sharedSynchronize] synchronizedFile:metadata selector:selectorReadFileWithDownload];
                else
                    [[CCSynchronize sharedSynchronize] synchronizedFile:metadata selector:selectorReadFile];
            }
            
            father = serverUrl;
        }
    }
    
    // Verify remove favorite
    NSArray *allRecordFavorite = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND favorite = true", app.activeAccount] sorted:nil ascending:NO];
    
    for (tableMetadata *metadata in allRecordFavorite)
        if (![filesEtag containsObject:metadata.fileID])
            [[NCManageDatabase sharedInstance] setMetadataFavoriteWithFileID:metadata.fileID favorite:NO];
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"clearDateReadDataSource" object:nil];
}

- (void)listingFavoritesFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSLog(@"Read Favorites Failure");
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download Thumbnail <Delegate> ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnailSuccess:(CCMetadataNet *)metadataNet
{
    [self reloadDatasource];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download <Delegate> ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{    
    [app messageNotification:@"_download_file_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
}

- (void)downloadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost
{
    _metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
    
    if ([_metadata.typeFile isEqualToString: k_metadataTypeFile_compress]) {
        
        //[self performSelector:@selector(unZipFile:) withObject:_metadata.fileID];
        [self openWith:_metadata];
        
    } else if ([_metadata.typeFile isEqualToString: k_metadataTypeFile_unknown]) {
        
        [self openWith:_metadata];
        
    } else {
        
        if ([self shouldPerformSegue])
            [self performSegueWithIdentifier:@"segueDetail" sender:self];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== menu =====
#pragma--------------------------------------------------------------------------------------------

- (void)openModel:(tableMetadata *)metadata
{
    UIViewController *viewController;
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    
    if ([metadata.model isEqualToString:@"cartadicredito"])
        viewController = [[CCCartaDiCredito alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid fileID:metadata.fileID isLocal:NO serverUrl:serverUrl];
    
    if ([metadata.model isEqualToString:@"bancomat"])
        viewController = [[CCBancomat alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid fileID:metadata.fileID isLocal:NO serverUrl:serverUrl];
    
    if ([metadata.model isEqualToString:@"contocorrente"])
        viewController = [[CCContoCorrente alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid fileID:metadata.fileID isLocal:NO serverUrl:serverUrl];
    
    if ([metadata.model isEqualToString:@"accountweb"])
        viewController = [[CCAccountWeb alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid fileID:metadata.fileID isLocal:NO serverUrl:serverUrl];
    
    if ([metadata.model isEqualToString:@"patenteguida"])
        viewController = [[CCPatenteGuida alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid fileID:metadata.fileID isLocal:NO serverUrl:serverUrl];
    
    if ([metadata.model isEqualToString:@"cartaidentita"])
        viewController = [[CCCartaIdentita alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid fileID:metadata.fileID isLocal:NO serverUrl:serverUrl];
    
    if ([metadata.model isEqualToString:@"passaporto"])
        viewController = [[CCPassaporto alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid fileID:metadata.fileID isLocal:NO serverUrl:serverUrl];
    
    if ([metadata.model isEqualToString:@"note"]) {
        
        viewController = [[CCNote alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid fileID:metadata.fileID isLocal:NO serverUrl:serverUrl];
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        
        [self presentViewController:navigationController animated:YES completion:nil];
        
    } else {
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        
        [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
        
        [self presentViewController:navigationController animated:YES completion:nil];
    }
}

- (void)openWith:(tableMetadata *)metadata
{
    NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileNamePath]) {
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint] error:nil];
        [[NSFileManager defaultManager] linkItemAtPath:fileNamePath toPath:[NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint] error:nil];
        
        NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint]];
        
        _docController = [UIDocumentInteractionController interactionControllerWithURL:url];
        _docController.delegate = self;
        
        [_docController presentOptionsMenuFromRect:self.view.frame inView:self.view animated:YES];
    }
}

- (void)requestDeleteMetadata:(tableMetadata *)metadata indexPath:(NSIndexPath *)indexPath
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        
        [[CCActions sharedInstance] deleteFileOrFolder:metadata delegate:self];
        [self reloadDatasource];
    }]];
        
        
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];
        
    alertController.popoverPresentationController.sourceView = self.view;
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
        
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
        
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)requestMoreMetadata:(tableMetadata *)metadata indexPath:(NSIndexPath *)indexPath
{
    UIImage *iconHeader;
    
    metadata = [_dataSource objectAtIndex:indexPath.row];
    
    AHKActionSheet *actionSheet = [[AHKActionSheet alloc] initWithView:self.view title:nil];
    
    actionSheet.animationDuration = 0.2;
    
    actionSheet.blurRadius = 0.0f;
    actionSheet.blurTintColor = [UIColor colorWithWhite:0.0f alpha:0.50f];
    
    actionSheet.buttonHeight = 50.0;
    actionSheet.cancelButtonHeight = 50.0f;
    actionSheet.separatorHeight = 5.0f;
    
    actionSheet.automaticallyTintButtonImages = @(NO);
    
    actionSheet.encryptedButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[NCBrandColor sharedInstance].cryptocloud };
    actionSheet.buttonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[UIColor blackColor] };
    actionSheet.cancelButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[NCBrandColor sharedInstance].brand };
    actionSheet.disableButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[UIColor blackColor] };
    
    actionSheet.separatorColor = [NCBrandColor sharedInstance].seperator;
    actionSheet.cancelButtonTitle = NSLocalizedString(@"_cancel_",nil);
    
    // assegnamo l'immagine anteprima se esiste, altrimenti metti quella standars
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]]) {
        
        iconHeader = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
        
    } else {
        
        if (metadata.directory)
            iconHeader = [CCGraphics changeThemingColorImage:[UIImage imageNamed:metadata.iconName] color:[NCBrandColor sharedInstance].brand];
        else
            iconHeader = [UIImage imageNamed:metadata.iconName];
    }
    
    [actionSheet addButtonWithTitle: metadata.fileNamePrint image: iconHeader backgroundColor: [NCBrandColor sharedInstance].tabBar height: 50.0 type: AHKActionSheetButtonTypeDisabled handler: nil
    ];

    // Share
    if (_metadata.cryptated == NO) {
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_share_", nil) image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetShare"] color:[NCBrandColor sharedInstance].brand] backgroundColor:[UIColor whiteColor] height: 50.0 type:AHKActionSheetButtonTypeDefault handler:^(AHKActionSheet *as) {
                                    
                [app.activeMain openWindowShare:metadata];
            }];
    }

    // NO Directory - NO Template
    if (metadata.directory == NO && [metadata.type isEqualToString:k_metadataType_template] == NO) {
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_open_in_", nil) image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetOpenIn"] color:[NCBrandColor sharedInstance].brand] backgroundColor:[UIColor whiteColor] height: 50.0 type:AHKActionSheetButtonTypeDefault handler:^(AHKActionSheet *as) {
                [self.tableView setEditing:NO animated:YES];
                [self openWith:metadata];
            }];
    }
    
    [actionSheet show];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Swipe Tablet -> menu =====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell canSwipe:(MGSwipeDirection)direction
{
    return YES;
}

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell tappedButtonAtIndex:(NSInteger)index direction:(MGSwipeDirection)direction fromExpansion:(BOOL)fromExpansion
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    if (direction == MGSwipeDirectionRightToLeft) {
        
        // Delete
        if (index == 0)
            [self requestDeleteMetadata:[_dataSource objectAtIndex:indexPath.row] indexPath:indexPath];
        
        // More
        if (index == 1)
            [self requestMoreMetadata:[_dataSource objectAtIndex:indexPath.row] indexPath:indexPath];
    }
    
    if (direction == MGSwipeDirectionLeftToRight) {
        
        tableMetadata *metadata = [_dataSource objectAtIndex:indexPath.row];
        [[CCActions sharedInstance] settingFavorite:metadata favorite:NO delegate:self];
    }
    
    return YES;
}


#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (tableMetadata *)setSelfMetadataFromIndexPath:(NSIndexPath *)indexPath
{
    tableMetadata *metadata = [_dataSource objectAtIndex:indexPath.row];
    
    return metadata;
}

- (void)readFolder:(NSString *)serverUrl
{
    [self reloadDatasource];
}

- (void)reloadDatasource
{
    NSMutableArray *metadatas = [NSMutableArray new];
    NSArray *recordsTableMetadata ;
        
    if (!_serverUrl) {
            
        recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND favorite = true", app.activeAccount] sorted:[CCUtility getOrderSettings] ascending:[CCUtility getAscendingSettings]];
            
    } else {
        
        NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl];        
        
        recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@", app.activeAccount, directoryID] sorted:[CCUtility getOrderSettings] ascending:[CCUtility getAscendingSettings]];
    }
        
    CCSectionDataSourceMetadata *sectionDataSource = [CCSectionMetadata creataDataSourseSectionMetadata:recordsTableMetadata listProgressMetadata:nil groupByField:nil replaceDateToExifDate:NO activeAccount:app.activeAccount];
        
    NSArray *fileIDs = [sectionDataSource.sectionArrayRow objectForKey:@"_none_"];
    for (NSString *fileID in fileIDs)
        [metadatas addObject:[sectionDataSource.allRecordsDataSource objectForKey:fileID]];
        
    _dataSource = [NSArray arrayWithArray:metadatas];
    
    [self.tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataSource count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CCFavoritesCell *cell = (CCFavoritesCell *)[tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    tableMetadata *metadata;
    
    // variable base
    cell.delegate = self;
    cell.indexPath = indexPath;
    
    // separator
    cell.separatorInset = UIEdgeInsetsMake(0.f, 60.f, 0.f, 0.f);
    
    // Initialize
    cell.status.image = nil;
    cell.favorite.image = nil;
    cell.local.image = nil;
        
    // change color selection
    UIView *selectionColor = [[UIView alloc] init];
    selectionColor.backgroundColor = [[NCBrandColor sharedInstance] getColorSelectBackgrond];
    cell.selectedBackgroundView = selectionColor;
    
    metadata = [_dataSource objectAtIndex:indexPath.row];
        
    // favorite
    if (_serverUrl == nil)
        cell.favorite.image = [UIImage imageNamed:@"favorite"];
    
    // encrypted color
    if (metadata.cryptated) {
        cell.labelTitle.textColor = [NCBrandColor sharedInstance].cryptocloud;
    } else {
        cell.labelTitle.textColor = [UIColor blackColor];
    }
    
    // filename
    cell.labelTitle.text = metadata.fileNamePrint;
    cell.labelInfoFile.text = @"";
    
    // Shared
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    NSString *shareLink = [app.sharesLink objectForKey:[serverUrl stringByAppendingString:metadata.fileName]];
    NSString *shareUserAndGroup = [app.sharesUserAndGroup objectForKey:[serverUrl stringByAppendingString:metadata.fileName]];

    // Immage
    if (metadata.directory) {
            
        if ([shareLink length] > 0) {
            cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder_public"] color:[NCBrandColor sharedInstance].brand];
        } else if ([shareUserAndGroup length] > 0) {
            cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder_shared_with_me"] color:[NCBrandColor sharedInstance].brand];
        } else {
            cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:metadata.iconName] color:[NCBrandColor sharedInstance].brand];
        }
            
    } else {
            
        if ([shareLink length] > 0) {
            cell.shared.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"shareLink"] color:[NCBrandColor sharedInstance].brand];
        } else if ([shareUserAndGroup length] > 0) {
            cell.shared.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetShare"] color:[NCBrandColor sharedInstance].brand];
        }
        
        cell.file.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
        
        if (cell.file.image == nil) {
            
            cell.file.image = [UIImage imageNamed:metadata.iconName];
            
            if (metadata.thumbnailExists)
                [[CCActions sharedInstance] downloadTumbnail:metadata delegate:self];
        }
    }
    
    // it's encrypted ???
    if (metadata.cryptated && [metadata.type isEqualToString: k_metadataType_template] == NO)
        cell.status.image = [UIImage imageNamed:@"lock"];
    
    // text and length
    if (metadata.directory) {
        
        cell.labelInfoFile.text = [CCUtility dateDiff:metadata.date];
        cell.accessoryType = UITableViewCellAccessoryNone;
        //cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
          
    } else {
        
        NSString *date = [CCUtility dateDiff:metadata.date];
        NSString *length = [CCUtility transformedSize:metadata.size];
        
        if ([metadata.type isEqualToString: k_metadataType_template])
            cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", date];
        
        if ([metadata.type isEqualToString: k_metadataType_file] || [metadata.type isEqualToString: k_metadataType_local]) {
            
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID]];
            
            if (fileExists)
                cell.local.image = [UIImage imageNamed:@"local"];
            else
                cell.local.image = nil;
            
            cell.labelInfoFile.text = [NSString stringWithFormat:@"%@ %@", date, length];
        }
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        
    }
    
    // ======== MGSwipe ========
    
    //configure left buttons : ONLY Root Favorites : Remove file/folder Favorites
    
    if (_serverUrl == nil) {
        cell.leftButtons = @[[MGSwipeButton buttonWithTitle:[NSString stringWithFormat:@" %@ ", NSLocalizedString(@"_unfavorite_", nil)] icon:[UIImage imageNamed:@"swipeUnfavorite"] backgroundColor:[UIColor colorWithRed:242.0/255.0 green:220.0/255.0 blue:132.0/255.0 alpha:1.000]]];
        cell.leftExpansion.buttonIndex = 0;
        cell.leftExpansion.fillOnTrigger = NO;
        
        //centerIconOverText
        MGSwipeButton *favoriteButton = (MGSwipeButton *)[cell.leftButtons objectAtIndex:0];
        [favoriteButton centerIconOverText];
    }
    
    //configure right buttons
    cell.rightButtons = @[[MGSwipeButton buttonWithTitle:[NSString stringWithFormat:@" %@ ", NSLocalizedString(@"_delete_", nil)] icon:[UIImage imageNamed:@"swipeDelete"] backgroundColor:[UIColor redColor]], [MGSwipeButton buttonWithTitle:[NSString stringWithFormat:@" %@ ", NSLocalizedString(@"_more_", nil)] icon:[UIImage imageNamed:@"swipeMore"] backgroundColor:[UIColor lightGrayColor]]];
    cell.rightSwipeSettings.transition = MGSwipeTransitionBorder;
    
    //centerIconOverText
    MGSwipeButton *deleteButton = (MGSwipeButton *)[cell.rightButtons objectAtIndex:0];
    MGSwipeButton *moreButton = (MGSwipeButton *)[cell.rightButtons objectAtIndex:1];
    [deleteButton centerIconOverText];
    [moreButton centerIconOverText];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // deselect row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    _metadata = [self setSelfMetadataFromIndexPath:indexPath];
    
    // if is in download [do not touch]
    if ([_metadata.session length] > 0 && [_metadata.session containsString:@"download"])
        return;
    
    // File
    if (([_metadata.type isEqualToString: k_metadataType_file]) && _metadata.directory == NO) {
        
        // File do not exists
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];

        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, _metadata.fileID]]) {
            
            [self downloadFileSuccess:_metadata.fileID serverUrl:serverUrl selector:selectorLoadFileView selectorPost:nil];
            
        } else {
            
            [[CCNetworking sharedNetworking] downloadFile:_metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorLoadFileView selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:self];
        }
    }
    
    // Model
    if ([self.metadata.type isEqualToString: k_metadataType_template])
        [self openModel:self.metadata];
    
    // Directory
    if (_metadata.directory)
        [self performSegueDirectoryWithControlPasscode];
}

-(void)performSegueDirectoryWithControlPasscode
{
    CCFavorites *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"CCFavorites"];
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    
    vc.serverUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileNameData];
    vc.titleViewControl = _metadata.fileNamePrint;
    
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Navigation ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)shouldPerformSegue
{
    // if i am in background -> exit
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) return NO;
    
    // if i am not window -> exit
    if (self.view.window == NO)
        return NO;
    
    // Collapsed but i am in detail -> exit
    if (self.splitViewController.isCollapsed)
        if (self.detailViewController.isViewLoaded && self.detailViewController.view.window) return NO;
    
    // Video in run -> exit
    if (self.detailViewController.photoBrowser.currentVideoPlayerViewController.isViewLoaded && self.detailViewController.photoBrowser.currentVideoPlayerViewController.view.window) return NO;
    
    return YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    id viewController = segue.destinationViewController;
    
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = viewController;
        _detailViewController = (CCDetail *)nav.topViewController;
    } else {
        _detailViewController = segue.destinationViewController;
    }
    
    NSMutableArray *allRecordsDataSourceImagesVideos = [NSMutableArray new];
    
    for (tableMetadata *metadata in _dataSource) {
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image] || [metadata.typeFile isEqualToString: k_metadataTypeFile_video])
            [allRecordsDataSourceImagesVideos addObject:metadata];
    }
    
    _detailViewController.metadataDetail = _metadata;
    _detailViewController.dateFilterQuery = nil;
    _detailViewController.dataSourceImagesVideos = allRecordsDataSourceImagesVideos;
    
    [_detailViewController setTitle:_metadata.fileNamePrint];
}

@end
