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
    _metadata = [CCMetadata new];
    
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
#pragma mark ===== UIDocumentInteractionController <delegate> =====
#pragma --------------------------------------------------------------------------------------------

- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller
{
    // evitiamo il rimando della eventuale photo e/o video
    if ([CCCoreData getCameraUploadActiveAccount:app.activeAccount]) {
        
        [CCCoreData setCameraUploadDatePhoto:[NSDate date]];
        [CCCoreData setCameraUploadDateVideo:[NSDate date]];
    }
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
    [CCCoreData setMetadataFavoriteFileID:metadataNet.fileID favorite:[metadataNet.options boolValue] activeAccount:app.activeAccount context:nil];
 
    [self reloadDatasource];
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
    _metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, app.activeAccount] context:nil];
    
    if ([_metadata.typeFile isEqualToString: k_metadataTypeFile_compress]) {
        
        [self performSelector:@selector(unZipFile:) withObject:_metadata.fileID];
        
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

- (void)openModel:(CCMetadata *)metadata
{
    UIViewController *viewController;
    NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:_metadata.directoryID activeAccount:app.activeAccount];
    
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

- (void)openWith:(CCMetadata *)metadata
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

- (void)requestDeleteMetadata:(CCMetadata *)metadata indexPath:(NSIndexPath *)indexPath
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== UnZipFile =====
#pragma --------------------------------------------------------------------------------------------

- (void)unZipFile:(NSString *)fileID
{
    [_hudDeterminate visibleHudTitle:NSLocalizedString(@"_unzip_in_progress_", nil) mode:MBProgressHUDModeDeterminate color:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSString *fileZip = [NSString stringWithFormat:@"%@/%@", app.directoryUser, fileID];
        
        [SSZipArchive unzipFileAtPath:fileZip toDestination:[CCUtility getDirectoryLocal] overwrite:YES password:nil progressHandler:^(NSString *entry, unz_file_info zipInfo, long entryNumber, long total) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                float progress = (float) entryNumber / (float)total;
                [_hudDeterminate progress:progress];
            });
            
        } completionHandler:^(NSString *path, BOOL succeeded, NSError *error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [_hudDeterminate hideHud];
                
                if (succeeded) [app messageNotification:@"_info_" description:@"_file_unpacked_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess errorCode:0];
                else [app messageNotification:@"_error_" description:[NSString stringWithFormat:@"Error %ld", (long)error.code] visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
            });
            
        }];
    });
}

- (void)requestMoreMetadata:(CCMetadata *)metadata indexPath:(NSIndexPath *)indexPath
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

    // ONLY Root Favorites : Remove file/folder Favorites
    if (_serverUrl == nil) {
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_remove_favorites_", nil) image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetOffline"] color:[NCBrandColor sharedInstance].brand] backgroundColor:[UIColor whiteColor] height: 50.0 type:AHKActionSheetButtonTypeDefault handler:^(AHKActionSheet *as) {
                                    
            [self.tableView setEditing:NO animated:YES];
            [[CCActions sharedInstance] settingFavorite:metadata favorite:NO delegate:self];
        }];
    }
    
    // Share
    if (_metadata.cryptated == NO) {
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_share_", nil) image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetShare"] color:[NCBrandColor sharedInstance].brand] backgroundColor:[UIColor whiteColor] height: 50.0 type:AHKActionSheetButtonTypeDefault handler:^(AHKActionSheet *as) {
                // close swipe
                [self setEditing:NO animated:YES];
                                    
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

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (NSString *)tableView:(UITableView *)tableView titleForSwipeAccessoryButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return NSLocalizedString(@"_more_", nil);
}

- (void)tableView:(UITableView *)tableView swipeAccessoryButtonPushedForRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self requestMoreMetadata:[_dataSource objectAtIndex:indexPath.row] indexPath:indexPath];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NSLocalizedString(@"_delete_", nil);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
                
        [self requestDeleteMetadata:[_dataSource objectAtIndex:indexPath.row] indexPath:indexPath];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (CCMetadata *)setSelfMetadataFromIndexPath:(NSIndexPath *)indexPath
{
    CCMetadata *metadata;
    
    NSManagedObject *record = [_dataSource objectAtIndex:indexPath.row];
    metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", [record valueForKey:@"fileID"], app.activeAccount] context:nil];

    return metadata;
}

- (void)readFolderWithForced:(BOOL)forced serverUrl:(NSString *)serverUrl
{
    [self reloadDatasource];
}

- (void)reloadDatasource
{
    NSMutableArray *metadatas = [NSMutableArray new];
    NSArray *recordsTableMetadata ;
        
    if (!_serverUrl) {
            
        recordsTableMetadata = [CCCoreData  getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (favorite == 1)", app.activeAccount] context:nil];
            
    } else {
            
        NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:_serverUrl activeAccount:app.activeAccount];
        recordsTableMetadata = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@)", app.activeAccount, directoryID] fieldOrder:[CCUtility getOrderSettings]  ascending:[CCUtility getAscendingSettings]];
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
    CCMetadata *metadata;
    
    // separator
    cell.separatorInset = UIEdgeInsetsMake(0.f, 60.f, 0.f, 0.f);
    
    // Initialize
    cell.statusImageView.image = nil;
    cell.offlineImageView.image = nil;
        
    // change color selection
    UIView *selectionColor = [[UIView alloc] init];
    selectionColor.backgroundColor = [[NCBrandColor sharedInstance] getColorSelectBackgrond];
    cell.selectedBackgroundView = selectionColor;
    
    metadata = [_dataSource objectAtIndex:indexPath.row];
        
    cell.fileImageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
        
    if (_serverUrl == nil)
        cell.offlineImageView.image = [UIImage imageNamed:@"favorite"];
    
    if (cell.fileImageView.image == nil && metadata.thumbnailExists)
        [[CCActions sharedInstance] downloadTumbnail:metadata delegate:self];
    
    // encrypted color
    if (metadata.cryptated) {
        cell.labelTitle.textColor = [NCBrandColor sharedInstance].cryptocloud;
    } else {
        cell.labelTitle.textColor = [UIColor blackColor];
    }
    
    // File name
    cell.labelTitle.text = metadata.fileNamePrint;
    cell.labelInfoFile.text = @"";
    
    // Immagine del file, se non c'è l'anteprima mettiamo quella standard
    if (cell.fileImageView.image == nil) {
        
        if (metadata.directory) {
            
            cell.fileImageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:metadata.iconName] color:[NCBrandColor sharedInstance].brand];
            
        } else {
            
            cell.fileImageView.image = [UIImage imageNamed:metadata.iconName];
        }
    }
    
    // it's encrypted ???
    if (metadata.cryptated && [metadata.type isEqualToString: k_metadataType_template] == NO)
        cell.statusImageView.image = [UIImage imageNamed:@"lock"];
    
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
                cell.labelInfoFile.text = [NSString stringWithFormat:@"%@ • %@", date, length];
            else
                cell.labelInfoFile.text = [NSString stringWithFormat:@"%@ ◦ %@", date, length];
        }
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        
    }
    
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
        NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:_metadata.directoryID activeAccount:_metadata.account];

        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, _metadata.fileID]]) {
            
            [self downloadFileSuccess:_metadata.fileID serverUrl:serverUrl selector:selectorLoadFileView selectorPost:nil];
            
        } else {
            
            [[CCNetworking sharedNetworking] downloadFile:_metadata serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorLoadFileView selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:self];
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
    
    NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:_metadata.directoryID activeAccount:app.activeAccount];
        
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
    
    for (CCMetadata *metadata in _dataSource) {
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image] || [metadata.typeFile isEqualToString: k_metadataTypeFile_video])
            [allRecordsDataSourceImagesVideos addObject:metadata];
    }
    
    _detailViewController.metadataDetail = _metadata;
    _detailViewController.dateFilterQuery = nil;
    _detailViewController.isCameraUpload = NO;
    _detailViewController.dataSourceImagesVideos = allRecordsDataSourceImagesVideos;
    
    [_detailViewController setTitle:_metadata.fileNamePrint];
}

@end
