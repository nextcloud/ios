//
//  CCFavorites.m
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

#import "CCFavorites.h"
#import "AppDelegate.h"
#import "CCSynchronize.h"

#import "NCBridgeSwift.h"

@interface CCFavorites ()
{
    AppDelegate *appDelegate;
    
    // Automatic Upload Folder
    NSString *autoUploadFileName;
    NSString *autoUploadDirectory;
    
    UIDocumentInteractionController *docController;
    
    // Datasource
    CCSectionDataSourceMetadata *sectionDataSource;
}
@end

@implementation CCFavorites

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        appDelegate.activeFavorites = self;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMain" bundle:nil] forCellReuseIdentifier:@"CellMain"];
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMainTransfer" bundle:nil] forCellReuseIdentifier:@"CellMainTransfer"];
    
    // Metadata
    self.metadata = [tableMetadata new];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 1)];
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    self.tableView.delegate = self;
    
    // Register for 3D Touch Previewing if available
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)] && (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable))
    {
        [self registerForPreviewingWithDelegate:self sourceView:self.view];
    }
    
    // calculate _serverUrl
    if (!_serverUrl)
        _serverUrl = nil;
  
    // Title
    if (_titleViewControl)
        self.title = _titleViewControl;
    else
        self.title = NSLocalizedString(@"_favorites_", nil);
    
    // Notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];

    // changeTheming
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
    [self changeTheming];
    
    // Query data source
    [self queryDatasource];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Active Main
    appDelegate.activeFavorites = self;
    
    [self reloadDatasource:nil action:k_action_NULL];
}

- (void)changeTheming
{
    [appDelegate changeTheming:self tableView:self.tableView collectionView:nil form:false];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return NCBrandColor.sharedInstance.backgroundView;
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favorite"] width:300 height:300 color:NCBrandColor.sharedInstance.yellowFavorite];
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
#pragma mark ===== Favorite =====
#pragma--------------------------------------------------------------------------------------------

- (void)settingFavorite:(tableMetadata *)metadata favorite:(BOOL)favorite
{
    NSString *fileNameServerUrl = [CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:metadata.serverUrl activeUrl:appDelegate.activeUrl];
    
    [[NCCommunication sharedInstance] setFavoriteWithUrlString:appDelegate.activeUrl fileName:fileNameServerUrl favorite:favorite account:appDelegate.activeAccount completionHandler:^(NSString *account, NSInteger errorCode, NSString *errorDecription) {
        
        if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
            [[NCManageDatabase sharedInstance] setMetadataFavoriteWithOcId:metadata.ocId favorite:favorite];
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadata.serverUrl ocId:metadata.ocId action:k_action_MOD];
        } else if (errorCode != 0) {
            [[NCContentPresenter shared] messageNotification:@"_error_" description:errorDecription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
        } else {
            NSLog(@"[LOG] It has been changed user during networking process, error.");
        }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== listingFavorites =====
#pragma--------------------------------------------------------------------------------------------

- (void)listingFavorites
{
    // test
    if (appDelegate.activeAccount.length == 0)
        return;
    
    [[OCNetworking sharedManager] listingFavoritesWithAccount:appDelegate.activeAccount completion:^(NSString *account, NSArray *metadatas, NSString *message, NSInteger errorCode) {
        
        if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
            
            NSString *father = @"";
            NSMutableArray *filesOcId = [NSMutableArray new];
            
            for (tableMetadata *metadata in metadatas) {
                
                // insert for test NOT favorite
                [filesOcId addObject:metadata.ocId];
                
                NSString *serverUrl = metadata.serverUrl;
                NSString *serverUrlSon = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileName];
                
                if (![serverUrlSon containsString:father]) {
                    
                    if (metadata.directory) {
                        
                        if ([CCUtility getFavoriteOffline])
                            [[CCSynchronize sharedSynchronize] readFolder:[CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileName] selector:selectorReadFolderWithDownload account:account];
                        else
                            [[CCSynchronize sharedSynchronize] readFolder:[CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileName] selector:selectorReadFolder account:account];
                        
                    } else {
                        
                        if ([CCUtility getFavoriteOffline])
                            [[CCSynchronize sharedSynchronize] readFile:metadata.ocId fileName:metadata.fileName serverUrl:serverUrl selector:selectorReadFileWithDownload account:account];
                        else
                            [[CCSynchronize sharedSynchronize] readFile:metadata.ocId fileName:metadata.fileName serverUrl:serverUrl selector:selectorReadFile account:account];
                    }
                    
                    father = serverUrlSon;
                }
            }
            
            // Verify remove favorite
            NSArray *allRecordFavorite = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND favorite == true", account] sorted:nil ascending:NO];
            
            for (tableMetadata *metadata in allRecordFavorite)
                if (![filesOcId containsObject:metadata.ocId])
                    [[NCManageDatabase sharedInstance] setMetadataFavoriteWithOcId:metadata.ocId favorite:NO];
            
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"clearDateReadDataSource" object:nil];
            
        } else if (errorCode != 0) {
            [[NCContentPresenter shared] messageNotification:@"_error_" description:message delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
        } else {
            NSLog(@"[LOG] It has been changed user during networking process, error.");
        }
    }];
}

- (void)tapActionComment:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (metadata) {
        [[NCMainCommon sharedInstance] openShareWithViewController:self metadata:metadata indexPage:1];
    }
}

- (void)tapActionShared:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (metadata) {
        [[NCMainCommon sharedInstance] openShareWithViewController:self metadata:metadata indexPage:2];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Progress & Task Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)triggerProgressTask:(NSNotification *)notification
{
    if (sectionDataSource.ocIdIndexPath != nil) {
        [[NCMainCommon sharedInstance] triggerProgressTask:notification sectionDataSourceocIdIndexPath:sectionDataSource.ocIdIndexPath tableView:self.tableView viewController:self serverUrlViewController:self.serverUrl];
    }
}

- (void)cancelTaskButton:(id)sender withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    if ([[NCMainCommon sharedInstance] isValidIndexPath:indexPath view:self.tableView]) {
        
        tableMetadata *metadataSection = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
        
        if (metadataSection) {
            
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadataSection.ocId]];
            if (metadata)
                [[NCMainCommon sharedInstance] cancelTransferMetadata:metadata reloadDatasource:true uploadStatusForcedStart:false];
        }
    }
}

- (void)cancelAllTask:(id)sender
{
    CGPoint location = [sender locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_all_task_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [NCUtility.sharedInstance startActivityIndicatorWithView:self.view bottom:0];
        [[NCMainCommon sharedInstance] cancelAllTransfer];
        [NCUtility.sharedInstance stopActivityIndicator];
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:nil ocId:nil action:k_action_NULL];
    }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { }]];
    
    alertController.popoverPresentationController.sourceView = self.tableView;
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Peek & Pop  =====
#pragma --------------------------------------------------------------------------------------------

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location
{
    CGPoint convertedLocation = [self.view convertPoint:location toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:convertedLocation];
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    CCCellMain *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if (cell) {
        previewingContext.sourceRect = cell.frame;
        CCPeekPop *viewController = [[UIStoryboard storyboardWithName:@"CCPeekPop" bundle:nil] instantiateViewControllerWithIdentifier:@"PeekPopImagePreview"];
        
        viewController.metadata = metadata;
        viewController.imageFile = cell.file.image;
        viewController.showOpenIn = true;
        viewController.showShare = false;
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_document]) {
            viewController.showOpenInternalViewer = true;
        }
        
        return viewController;
    }
    
    return nil;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit
{
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:previewingContext.sourceRect.origin];
    
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== menu action : Favorite, More, Delete [swipe] =====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)canOpenMenuAction:(tableMetadata *)metadata
{
    return YES;
}

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell canSwipe:(MGSwipeDirection)direction
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    return [self canOpenMenuAction:metadata];
}

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell tappedButtonAtIndex:(NSInteger)index direction:(MGSwipeDirection)direction fromExpansion:(BOOL)fromExpansion
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    if (direction == MGSwipeDirectionRightToLeft) {
        
        [self actionDelete:indexPath];
    }
    
    if (direction == MGSwipeDirectionLeftToRight) {
        
        tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
        
        [self settingFavorite:metadata favorite:NO];
    }
    
    return YES;
}

- (void)actionDelete:(NSIndexPath *)indexPath
{
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    tableLocalFile *localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        
        tableDirectory *tableDirectory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND e2eEncrypted == 1 AND serverUrl == %@", appDelegate.activeAccount, metadata.serverUrl]];
        
        [[NCMainCommon sharedInstance ] deleteFileWithMetadatas:[[NSArray alloc] initWithObjects:metadata, nil] e2ee:tableDirectory.e2eEncrypted serverUrl:metadata.serverUrl folderocId:tableDirectory.ocId completion:^(NSInteger errorCode, NSString *message) {
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadata.serverUrl ocId:metadata.ocId action:k_action_DEL];
        }];
    }]];
    
    if (localFile) {
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_remove_local_file_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
            [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId] error:nil];
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadata.serverUrl ocId:metadata.ocId action:k_action_MOD];
        }]];
    }
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];
    
    alertController.popoverPresentationController.sourceView = self.tableView;
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)actionMore:(UITapGestureRecognizer *)gestureRecognizer
{
    CGPoint touch = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touch];
    UIImage *iconHeader;
    
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    AHKActionSheet *actionSheet = [[AHKActionSheet alloc] initWithView:self.tabBarController.view title:nil];
    
    actionSheet.animationDuration = 0.2;
    
    actionSheet.buttonHeight = 50.0;
    actionSheet.cancelButtonHeight = 50.0f;
    actionSheet.separatorHeight = 5.0f;
    
    actionSheet.automaticallyTintButtonImages = @(NO);
    
    actionSheet.encryptedButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:NCBrandColor.sharedInstance.encrypted };
    actionSheet.buttonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:NCBrandColor.sharedInstance.textView };
    actionSheet.cancelButtonTextAttributes = @{ NSFontAttributeName:[UIFont boldSystemFontOfSize:17], NSForegroundColorAttributeName:NCBrandColor.sharedInstance.textView };
    actionSheet.disableButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:NCBrandColor.sharedInstance.textView };
    
    actionSheet.separatorColor = NCBrandColor.sharedInstance.separator;
    actionSheet.cancelButtonTitle = NSLocalizedString(@"_cancel_",nil);
    actionSheet.cancelButtonBackgroudColor = NCBrandColor.sharedInstance.backgroundForm;
    
    // assegnamo l'immagine anteprima se esiste, altrimenti metti quella standars
    if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]]) {
        
        iconHeader = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]];
        
    } else {
        
        if (metadata.directory)
            iconHeader = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] multiplier:2 color:NCBrandColor.sharedInstance.icon];
        else
            iconHeader = [UIImage imageNamed:metadata.iconName];
    }
    
    [actionSheet addButtonWithTitle: metadata.fileNameView image: iconHeader backgroundColor: NCBrandColor.sharedInstance.backgroundForm height: 50.0 type: AHKActionSheetButtonTypeDisabled handler: nil
     ];
    
    // Favorite : ONLY root
    if (_serverUrl == nil) {
        [actionSheet addButtonWithTitle: NSLocalizedString(@"_remove_favorites_", nil)
                                  image: [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favorite"] multiplier:2 color:NCBrandColor.sharedInstance.yellowFavorite]
                        backgroundColor: NCBrandColor.sharedInstance.backgroundForm
                                 height: 50.0
                                   type: AHKActionSheetButtonTypeDefault
                                handler: ^(AHKActionSheet *as) {
                                    [self settingFavorite:metadata favorite:NO];
                                }];
    }
    
    // Share
    [actionSheet addButtonWithTitle:NSLocalizedString(@"_details_", nil) image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"details"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] backgroundColor:NCBrandColor.sharedInstance.backgroundForm height: 50.0 type:AHKActionSheetButtonTypeDefault handler:^(AHKActionSheet *as) {
        
        [[NCMainCommon sharedInstance] openShareWithViewController:self metadata:metadata indexPage:0];
    }];
    
    // NO Directory
    if (metadata.directory == NO && [NCBrandOptions sharedInstance].disable_openin_file == NO) {
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_open_in_", nil) image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"openFile"] multiplier:2 color:NCBrandColor.sharedInstance.icon] backgroundColor:NCBrandColor.sharedInstance.backgroundForm height: 50.0 type:AHKActionSheetButtonTypeDefault handler:^(AHKActionSheet *as) {
            [self.tableView setEditing:NO animated:YES];
            
            [[NCMainCommon sharedInstance] downloadOpenWithMetadata:metadata selector:selectorOpenIn];
        }];
    }
    
    // Delete
    [actionSheet addButtonWithTitle:NSLocalizedString(@"_delete_", nil)
                              image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"trash"] width:50 height:50 color:[UIColor redColor]]
                    backgroundColor:NCBrandColor.sharedInstance.backgroundForm
                             height:50.0
                               type:AHKActionSheetButtonTypeDestructive
                            handler:^(AHKActionSheet *as) {
                                [self actionDelete:indexPath];
                            }];
    
    [actionSheet show];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (tableMetadata *)setSelfMetadataFromIndexPath:(NSIndexPath *)indexPath
{
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    return metadata;
}

- (void)reloadDatasource:(NSString *)ocId action:(NSInteger)action
{
    // test
    if (appDelegate.activeAccount.length == 0 || self.view.window == nil) {
        return;
    }
    
    [self queryDatasource];
}

- (void)queryDatasource
{
    // test
    if (appDelegate.activeAccount.length == 0) {
        return;
    }
    
    NSArray *recordsTableMetadata;
    NSString *sorted = [CCUtility getOrderSettings];
    if ([sorted isEqualToString:@"fileName"]) sorted = @"fileName";
    
    // get auto upload folder
    autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
    autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:appDelegate.activeUrl];
    
    if (!_serverUrl) {
        
        recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND favorite == true", appDelegate.activeAccount] sorted:nil ascending:NO];
        
    } else {
        
        recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, _serverUrl] sorted:nil ascending:NO];
    }
    
    sectionDataSource = [CCSectionMetadata creataDataSourseSectionMetadata:recordsTableMetadata listProgressMetadata:nil groupByField:nil filterocId:appDelegate.filterocId filterTypeFileImage:NO filterTypeFileVideo:NO sorted:sorted ascending:[CCUtility getAscendingSettings] activeAccount:appDelegate.activeAccount];
    
    [self.tableView reloadData];
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[sectionDataSource.sectionArrayRow allKeys] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:section]] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    tableShare *shareCell;
    tableMetadata *metadataFolder;
   
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    if (metadata == nil || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata]) {
        return [CCCellMain new];
    }
    
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, metadata.serverUrl]];
    if (directory != nil) {
        metadataFolder = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", directory.ocId]];
    }
    
    for (tableShare *share in appDelegate.shares) {
        if ([share.serverUrl isEqualToString:metadata.serverUrl] && [share.fileName isEqualToString:metadata.fileName]) {
            shareCell = share;
            break;
        }
    }
    
    UITableViewCell *cell = [[NCMainCommon sharedInstance] cellForRowAtIndexPath:indexPath tableView:tableView metadata:metadata metadataFolder:metadataFolder serverUrl:self.serverUrl autoUploadFileName:autoUploadFileName autoUploadDirectory:autoUploadDirectory tableShare:shareCell];
    
    // NORMAL - > MAIN

    if ([cell isKindOfClass:[CCCellMain class]]) {
        
        // Comment tap
        if (metadata.commentsUnread) {
            UITapGestureRecognizer *tapComment = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionComment:)];
            [tapComment setNumberOfTapsRequired:1];
            ((CCCellMain *)cell).comment.userInteractionEnabled = YES;
            [((CCCellMain *)cell).comment addGestureRecognizer:tapComment];
        }
        
        // Share add Tap
        UITapGestureRecognizer *tapShare = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionShared:)];
        [tapShare setNumberOfTapsRequired:1];
        ((CCCellMain *)cell).viewShared.userInteractionEnabled = YES;
        [((CCCellMain *)cell).viewShared addGestureRecognizer:tapShare];
        
        // More
        if ([self canOpenMenuAction:metadata]) {
            
            UITapGestureRecognizer *tapMore = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionMore:)];
            [tapMore setNumberOfTapsRequired:1];
            ((CCCellMain *)cell).more.userInteractionEnabled = YES;
            [((CCCellMain *)cell).more addGestureRecognizer:tapMore];
        }
        
        // MGSwipeButton
        ((CCCellMain *)cell).delegate = self;
        
        // LEFT : configure ONLY Root Favorites : Remove file/folder Favorites
        if (_serverUrl == nil) {
            
            ((CCCellMain *)cell).leftButtons = @[[MGSwipeButton buttonWithTitle:@"" icon:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favorite"] width:50 height:50 color:[UIColor whiteColor]] backgroundColor:NCBrandColor.sharedInstance.yellowFavorite padding:25]];
            ((CCCellMain *)cell).leftExpansion.buttonIndex = 0;
            ((CCCellMain *)cell).leftExpansion.fillOnTrigger = NO;
            
            //centerIconOverText
            MGSwipeButton *favoriteButton = (MGSwipeButton *)[((CCCellMain *)cell).leftButtons objectAtIndex:0];
            [favoriteButton centerIconOverText];
        }
        
        // RIGHT
        ((CCCellMain *)cell).rightButtons = @[[MGSwipeButton buttonWithTitle:@"" icon:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"trash"] width:50 height:50 color:[UIColor whiteColor]] backgroundColor:[UIColor redColor] padding:25]];
        
        ((CCCellMain *)cell).rightExpansion.buttonIndex = 0;
        ((CCCellMain *)cell).rightExpansion.fillOnTrigger = NO;
        
        //centerIconOverText
        MGSwipeButton *deleteButton = (MGSwipeButton *)[((CCCellMain *)cell).rightButtons objectAtIndex:0];
        [deleteButton centerIconOverText];
        
    }
    
    // TRANSFER
    
    if ([cell isKindOfClass:[CCCellMainTransfer class]]) {
        
        // gesture Transfer
        [((CCCellMainTransfer *)cell).transferButton.stopButton addTarget:self action:@selector(cancelTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];
        
        UILongPressGestureRecognizer *stopLongGesture = [UILongPressGestureRecognizer new];
        [stopLongGesture addTarget:self action:@selector(cancelAllTask:)];
        [((CCCellMainTransfer *)cell).transferButton.stopButton addGestureRecognizer:stopLongGesture];
    }
   
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // deselect row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    self.metadata = [self setSelfMetadataFromIndexPath:indexPath];
    
    // if is in download [do not touch]
    if (self.metadata.status == k_metadataStatusWaitDownload || self.metadata.status == k_metadataStatusInDownload || self.metadata.status == k_metadataStatusDownloading)
        return;
    
    // File
    if (self.metadata.directory == NO) {
        
        // File do not exists
        if ([CCUtility fileProviderStorageExists:self.metadata.ocId fileNameView:self.metadata.fileNameView]) {
            
            [[NCNetworkingMain sharedInstance] downloadFileSuccessFailure:self.metadata.fileName ocId:self.metadata.ocId serverUrl:self.metadata.serverUrl selector:selectorLoadFileView errorMessage:@"" errorCode:0];
                            
        } else {
            
            tableDirectory *tableDirectory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, self.metadata.serverUrl]];
                
            if (tableDirectory.e2eEncrypted && ![CCUtility isEndToEndEnabled:appDelegate.activeAccount]) {
                    
                [[NCContentPresenter shared] messageNotification:@"_info_" description:@"_e2e_goto_settings_for_enable_" delay:k_dismissAfterSecond type:messageTypeInfo errorCode:0];
                    
            } else {
                    
                if (([self.metadata.typeFile isEqualToString: k_metadataTypeFile_video] || [self.metadata.typeFile isEqualToString: k_metadataTypeFile_audio] || [_metadata.typeFile isEqualToString: k_metadataTypeFile_image]) && self.metadata.e2eEncrypted == NO) {
                        
                    [self shouldPerformSegue:self.metadata selector:@""];
                        
                } else {
                        
                    self.metadata.session = k_download_session;
                    self.metadata.sessionError = @"";
                    self.metadata.sessionSelector = selectorLoadFileView;
                    self.metadata.status = k_metadataStatusWaitDownload;
                        
                    // Add Metadata for Download
                    tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:self.metadata];
                    [[CCNetworking sharedNetworking] downloadFile:metadata taskStatus:k_taskStatusResume];
                        
                    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.metadata.serverUrl ocId:self.metadata.ocId action:k_action_MOD];
                }
            }
        }
        
    }
    
    // Directory
    if (self.metadata.directory)
        [self performSegueDirectoryWithControlPasscode];
}

-(void)performSegueDirectoryWithControlPasscode
{
    CCFavorites *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"CCFavorites"];
    
    vc.serverUrl = [CCUtility stringAppendServerUrl:self.metadata.serverUrl addFileName:self.metadata.fileName];
    vc.titleViewControl = self.metadata.fileNameView;
    
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Navigation ====
#pragma --------------------------------------------------------------------------------------------

- (void)shouldPerformSegue:(tableMetadata *)metadata selector:(NSString *)selector
{
    // if i am in background -> exit
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) return;
    
    // if i am not window -> exit
    if (self.view.window == NO)
        return;
    
    // Collapsed but i am in detail -> exit
    if (self.splitViewController.isCollapsed)
        if (self.detailViewController.isViewLoaded && self.detailViewController.view.window) return;
    
    // Metadata for push detail
    self.metadataForPushDetail = metadata;
    self.selectorForPushDetail = selector;
    
    [self performSegueWithIdentifier:@"segueDetail" sender:self];
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
    
    NSMutableArray *photoDataSource = [NSMutableArray new];
    
    for (NSString *ocId in sectionDataSource.allOcId) {
        tableMetadata *metadata = [sectionDataSource.allRecordsDataSource objectForKey:ocId];
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
            [photoDataSource addObject:metadata];
    }
    
    _detailViewController.metadataDetail = self.metadataForPushDetail;
    _detailViewController.selectorDetail = self.selectorForPushDetail;
    _detailViewController.dateFilterQuery = nil;
    _detailViewController.photoDataSource = photoDataSource;
    
    [_detailViewController setTitle:self.metadata.fileNameView];
}

@end
