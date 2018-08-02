//
//  CCPhotos.m
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

#import "CCPhotos.h"
#import "AppDelegate.h"
#import "CCManageAutoUpload.h"
#import "TOScrollBar.h"
#import "NCBridgeSwift.h"

@interface CCPhotos ()
{
    AppDelegate *appDelegate;

    NSMutableArray *selectedMetadatas;
    CCSectionDataSourceMetadata *sectionDataSource;
    NSString *saveDirectoryID, *saveServerUrl;
    
    BOOL isSearchMode;
    BOOL isEditMode;
    
    TOScrollBar *scrollBar;
    NSMutableDictionary *saveEtagForStartDirectory;
    
    // Fix Crash Thumbnail + collectionView ReloadData ?
    NSInteger counterThumbnail;
    BOOL collectionViewReloadData;
}
@end

@implementation CCPhotos

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
        
        appDelegate.activePhotos = self;
    }
    
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    }
    
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    saveEtagForStartDirectory = [NSMutableDictionary new];
    selectedMetadatas = [NSMutableArray new];
    self.addMetadatasFromUpload = [NSMutableArray new];
    
    // empty Data Source
    self.collectionView.emptyDataSetDelegate = self;
    self.collectionView.emptyDataSetSource = self;

    // scroll bar
    scrollBar = [TOScrollBar new];
    [self.collectionView to_addScrollBar:scrollBar];
    
    // Fix Crash Thumbnail + collectionView ReloadData ?
    counterThumbnail = 0;
    collectionViewReloadData = NO;
    
    scrollBar.handleTintColor = [NCBrandColor sharedInstance].brand;
    scrollBar.handleWidth = 20;
    scrollBar.handleMinimiumHeight = 20;
    scrollBar.trackWidth = 0;
    scrollBar.edgeInset = 12;
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];
    [appDelegate aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Plus Button
    [appDelegate plusButtonVisibile:true];

    [self reloadDatasource];
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    
    self.collectionView.contentInset = self.view.safeAreaInsets;
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [appDelegate changeTheming:self];
    
    scrollBar.handleTintColor = [NCBrandColor sharedInstance].brand;
    
    [self.collectionView reloadData];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Before rotation
    
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        if (self.view.frame.size.width == ([[UIScreen mainScreen] bounds].size.width*([[UIScreen mainScreen] bounds].size.width<[[UIScreen mainScreen] bounds].size.height))+([[UIScreen mainScreen] bounds].size.height*([[UIScreen mainScreen] bounds].size.width>[[UIScreen mainScreen] bounds].size.height))) {
            
            // Portrait
            
        } else {
            
            // Landscape
        }
        
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Gestione Grafica Window =====
#pragma --------------------------------------------------------------------------------------------

- (void)setUINavigationBarDefault
{
    [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];
 
    // curront folder search
    NSString *directory = [[NCManageDatabase sharedInstance] getAccountStartDirectoryPhotosTab:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl]];
    NSString *home = [CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl];
    NSString *folder = @"";
    if (home.length > 0) {
        folder = [directory stringByReplacingOccurrencesOfString:home withString:@""];
    }
    
    // Title
    self.navigationItem.titleView = nil;
    if (folder.length == 0) {
        self.navigationItem.title = NSLocalizedString(@"_photo_camera_", nil);
    } else {
        self.navigationItem.title = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"_photo_camera_", nil), [folder substringFromIndex:1]];
    }
    
    if (isSearchMode) {
        [CCGraphics addImageToTitle:self.navigationItem.title colorTitle:[NCBrandColor sharedInstance].brandText imageTitle:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"load"] multiplier:2 color:[NCBrandColor sharedInstance].brandText] navigationItem:self.navigationItem];
    }
    
    // Button Item
    UIImage *icon;
    icon = [UIImage imageNamed:@"select"];
    UIBarButtonItem *buttonSelect = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(editingModeYES)];
    icon = [UIImage imageNamed:@"folderPhotos"];
    UIBarButtonItem *buttonStartDirectoryPhotosTab = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(selectStartDirectoryPhotosTab)];

    if ([sectionDataSource.allRecordsDataSource count] > 0) {
        self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonSelect, nil];
    } else {
        self.navigationItem.rightBarButtonItems = nil;
    }
    self.navigationItem.leftBarButtonItems = [[NSArray alloc] initWithObjects:buttonStartDirectoryPhotosTab, nil];
}

- (void)setUINavigationBarSelected
{
    UIImage *icon;
    
    icon = [UIImage imageNamed:@"delete"];
    UIBarButtonItem *buttonDelete = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(deleteSelectedFiles)];
    
    icon = [UIImage imageNamed:@"openFile"];
    UIBarButtonItem *buttonOpenWith = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(openSelectedFiles)];
    
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIBarButtonItemStylePlain target:self action:@selector(editingModeNO)];
    
    self.navigationItem.leftBarButtonItem = leftButton;
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonDelete, buttonOpenWith, nil];
    
    // Title
    self.navigationItem.title = [NSString stringWithFormat:@"%@ : %lu / %lu", NSLocalizedString(@"_selected_", nil), (unsigned long)[selectedMetadatas count], (unsigned long)[sectionDataSource.allRecordsDataSource count]];
}

- (void)cellSelect:(BOOL)select indexPath:(NSIndexPath *)indexPath metadata:(tableMetadata *)metadata
{
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
    UIVisualEffectView *effect = [cell viewWithTag:200];
    UIImageView *checked = [cell viewWithTag:300];
    
    if (select) {
        effect.hidden = NO;
        effect.alpha = 0.4;
        checked.hidden = NO;
        [selectedMetadatas addObject:metadata];
        
    } else {
        effect.hidden = YES;
        checked.hidden = YES;
        [selectedMetadatas removeObject:metadata];
    }
    
    // Title
    self.navigationItem.title = [NSString stringWithFormat:@"%@ : %lu / %lu", NSLocalizedString(@"_selected_", nil), (unsigned long)[selectedMetadatas count], (unsigned long)[sectionDataSource.allRecordsDataSource count]];
}

- (void)scrollToTop
{
    [self.collectionView setContentOffset:CGPointMake(0, - self.collectionView.contentInset.top) animated:NO];
}

- (void)getGeoLocationForSection:(NSInteger)section
{
    NSString *addLocation = @"";
    
    NSArray *fileIDsForKey = [sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:section]];
    
    for (NSString *fileID in fileIDsForKey) {
    
        tableLocalFile *localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
    
        if ([localFile.exifLatitude floatValue] > 0 || [localFile.exifLongitude floatValue] > 0) {
        
            NSString *location = [[NCManageDatabase sharedInstance] getLocationFromGeoLatitude:localFile.exifLatitude longitude:localFile.exifLongitude];
            
            addLocation = [NSString stringWithFormat:@"%@, %@", addLocation, location];
        
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource Methods ====
#pragma --------------------------------------------------------------------------------------------

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [NCBrandColor sharedInstance].backgroundView;
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"photosNoRecord"] multiplier:2 color:[NCBrandColor sharedInstance].graySoft];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text;
    
    if (isSearchMode) {
        text = [NSString stringWithFormat:@"\n%@", NSLocalizedString(@"_search_in_progress_", nil)];
    } else {
        text = [NSString stringWithFormat:@"\n%@", NSLocalizedString(@"_tutorial_photo_view_", nil)];
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:[UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== openSelectedFiles =====
#pragma--------------------------------------------------------------------------------------------

- (void)openSelectedFiles
{
    NSMutableArray *dataToShare = [[NSMutableArray alloc] init];
    
    for (tableMetadata *metadata in selectedMetadatas) {
    
        NSString *fileNamePath = [CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileName:metadata.fileNameView];
                
        if ([CCUtility fileProviderStorageExists:metadata.fileID fileName:metadata.fileNameView]) {
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image]) {
                
                NSData *data = [NSData dataWithData:UIImageJPEGRepresentation([UIImage imageWithContentsOfFile:fileNamePath], 0.9)];
                [dataToShare addObject:data];
            }
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video]) {
                
                [dataToShare addObject:[NSURL fileURLWithPath:fileNamePath]];
            }
        }
    }
    
    if ([dataToShare count] > 0) {
        
        UIActivityViewController* activityViewController = [[UIActivityViewController alloc] initWithActivityItems:dataToShare applicationActivities:nil];
        
        // iPad
        activityViewController.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.lastObject;
        
        self.navigationItem.leftBarButtonItem.enabled = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
        
        [self presentViewController:activityViewController animated:YES completion:^{
            
            [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
                
                self.navigationItem.leftBarButtonItem.enabled = YES;
                self.navigationItem.rightBarButtonItem.enabled = YES;
                
                [self editingModeNO];

                if (completed) {
                    [self.collectionView reloadData];
                }
            }];
        }];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Download =====
#pragma--------------------------------------------------------------------------------------------

- (void)triggerProgressTask:(NSNotification *)notification
{
    //NSDictionary *dict = notification.userInfo;
    //float progress = [[dict valueForKey:@"progress"] floatValue];
}

- (void)downloadFileSuccessFailure:(NSString *)fileName fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector errorMessage:(NSString *)errorMessage errorCode:(NSInteger)errorCode
{
    if (errorCode == 0) {
        
        NSIndexPath *indexPath;
        BOOL existsIcon = NO;
        
        if (fileID) {
            existsIcon = [[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:fileID fileNameView:fileName]];
            indexPath = [sectionDataSource.fileIDIndexPath objectForKey:fileID];
        }
        
        if ([self indexPathIsValid:indexPath] && existsIcon) {
            
            UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
            
            if (cell) {
                UIImageView *imageView = (UIImageView *)[cell viewWithTag:100];
                UIVisualEffectView *effect = [cell viewWithTag:200];
                UIImageView *checked = [cell viewWithTag:300];
                
                imageView.image = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconFileID:fileID fileNameView:fileName]];
                effect.hidden = YES;
                checked.hidden = YES;
            }
        }
        
    } else {
        
        [appDelegate messageNotification:@"_download_selected_files_" description:@"_error_download_photobrowser_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delete =====
#pragma--------------------------------------------------------------------------------------------

- (void)deleteFile:(NSArray *)metadatas e2ee:(BOOL)e2ee
{
    [[NCMainCommon sharedInstance ] deleteFileWithMetadatas:metadatas e2ee:false serverUrl:@"" folderFileID:@"" completion:^(NSInteger errorCode, NSString *message) {
        [self reloadDatasource];
    }];
    
    [self editingModeNO];
}

- (void)deleteSelectedFiles
{
    if ([selectedMetadatas count] == 0)
        return;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil)
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
                                                           [self deleteFile:selectedMetadatas e2ee:false];
                                                       }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil)
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                       }]];
    
    alertController.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:NULL];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download Thumbnail ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnail:(tableMetadata *)metadata indexPath:(NSIndexPath *)indexPath
{
    if (![saveDirectoryID isEqualToString:metadata.directoryID]) {
        saveDirectoryID = metadata.directoryID;
        saveServerUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
        if (!saveServerUrl)
            return;
    }
    
    counterThumbnail++;
    
    OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:nil metadataNet:nil withUser:appDelegate.activeUser withUserID:appDelegate.activeUserID withPassword:appDelegate.activePassword withUrl:appDelegate.activeUrl];
    [ocNetworking downloadThumbnailWithDimOfThumbnail:@"m" fileID:metadata.fileID fileNamePath:[CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:saveServerUrl activeUrl:appDelegate.activeUrl] fileNameView:metadata.fileNameView completion:^(NSString *message, NSInteger errorCode) {
        counterThumbnail--;
        if (errorCode == 0 && [[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]] && [self indexPathIsValid:indexPath]) {
            [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        }
        
        // Fix Crash Thumbnail + collectionView ReloadData ?
        if (counterThumbnail == 0 && collectionViewReloadData == YES) {
            [self.collectionView reloadData];
            collectionViewReloadData = NO;
        }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Change Start directory ====
#pragma --------------------------------------------------------------------------------------------

- (void)moveServerUrlTo:(NSString *)serverUrlTo title:(NSString *)title
{
    NSString *oldStartDirectoryPhotosTab = [[NCManageDatabase sharedInstance] getAccountStartDirectoryPhotosTab:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl]];
    
    if (![serverUrlTo isEqualToString:oldStartDirectoryPhotosTab]) {
        
        // Save Start Directory
        [[NCManageDatabase sharedInstance] setAccountStartDirectoryPhotosTab:serverUrlTo];
        
        // search PhotoVideo with new start directory
        [self searchPhotoVideo];
    }
}

- (void)selectStartDirectoryPhotosTab
{
    UINavigationController* navigationController = [[UIStoryboard storyboardWithName:@"CCMove" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMove"];
    
    CCMove *viewController = (CCMove *)navigationController.topViewController;
    
    viewController.delegate = self;
    viewController.move.title = NSLocalizedString(@"_select_dir_photos_tab_", nil);
    viewController.tintColor = [NCBrandColor sharedInstance].brandText;
    viewController.barTintColor = [NCBrandColor sharedInstance].brand;
    viewController.tintColorTitle = [NCBrandColor sharedInstance].brandText;
    viewController.networkingOperationQueue = appDelegate.netQueue;
    viewController.hideCreateFolder = YES;
    // E2EE
    viewController.includeDirectoryE2EEncryption = NO;
    
    [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Search Photo/Video ====
#pragma --------------------------------------------------------------------------------------------

- (void)searchSuccessFailure:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas message:(NSString *)message errorCode:(NSInteger)errorCode
{
    isSearchMode = NO;
    
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount] || errorCode != 0) {
        
        [self reloadDatasource];
        
    } else {
    
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            // Clear all Hardcoded new foto/video from CCNetworking
            [self.addMetadatasFromUpload removeAllObjects];
            
            [[NCManageDatabase sharedInstance] createTablePhotos:metadatas];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self reloadDatasource];
            });
            
            // Update date
            [[NCManageDatabase sharedInstance] setAccountDateSearchContentTypeImageVideo:[NSDate date]];
            // Save etag
            [saveEtagForStartDirectory setObject:metadataNet.etag forKey:metadataNet.serverUrl];
        });
    }
}

- (void)searchPhotoVideo
{
    // test
    if (appDelegate.activeAccount.length == 0 || isSearchMode)
        return;
    
    // WAITING FOR d:creationdate
    //
    // tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];
    // account.dateSearchContentTypeImageVideo
    
    NSString *startDirectory = [[NCManageDatabase sharedInstance] getAccountStartDirectoryPhotosTab:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl]];
    OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:self metadataNet:nil withUser:appDelegate.activeUser withUserID:appDelegate.activeUserID withPassword:appDelegate.activePassword withUrl:appDelegate.activeUrl];
    
    [ocNetworking readFile:nil serverUrl:startDirectory account:appDelegate.activeAccount success:^(tableMetadata *metadata) {
        
        if (![metadata.etag isEqualToString:[saveEtagForStartDirectory objectForKey:startDirectory]] || sectionDataSource.allRecordsDataSource.count == 0) {
            
            isSearchMode = YES;
            [self editingModeNO];
            
            [[CCActions sharedInstance] search:startDirectory fileName:@"" etag:metadata.etag depth:@"infinity" date:[NSDate distantPast] contenType:@[@"image/%", @"video/%"] selector:selectorSearchContentType delegate:self];
            
        } else {
            [self reloadDatasource];
        }
        
    } failure:^(NSString *message, NSInteger errorCode) {
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadDatasource
{
    // test
    if (appDelegate.activeAccount.length == 0) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSArray *metadatas = [[NCManageDatabase sharedInstance] getTablePhotosWithAddMetadatasFromUpload:self.addMetadatasFromUpload];
        sectionDataSource = [CCSectionMetadata creataDataSourseSectionMetadata:metadatas listProgressMetadata:nil groupByField:@"date" filterFileID:appDelegate.filterFileID activeAccount:appDelegate.activeAccount];
        
        dispatch_async(dispatch_get_main_queue(), ^{
               
            if (isEditMode)
                [self setUINavigationBarSelected];
            else
                [self setUINavigationBarDefault];
            
            // Fix Crash Thumbnail + collectionView ReloadData ?
            collectionViewReloadData = YES;
            if (counterThumbnail == 0) {
                [self.collectionView reloadData];
                collectionViewReloadData = NO;
            }
        });
    });
}

- (void)editingModeYES
{
    [self.collectionView setAllowsMultipleSelection:true];
    isEditMode = true;
    [selectedMetadatas removeAllObjects];
    [self setUINavigationBarSelected];

    [self.collectionView reloadData];
}

- (void)editingModeNO
{
    [self.collectionView setAllowsMultipleSelection:false];
    isEditMode = false;
    [selectedMetadatas removeAllObjects];
    [self setUINavigationBarDefault];
    
    [self.collectionView reloadData];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Collection ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)indexPathIsValid:(NSIndexPath *)indexPath
{
    return indexPath.section < [self numberOfSectionsInCollectionView:self.collectionView] && indexPath.row < [self collectionView:self.collectionView numberOfItemsInSection:indexPath.section];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{    
    return [[sectionDataSource.sectionArrayRow allKeys] count];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [[sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:section]] count];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UIInterfaceOrientation orientationOnLunch = [[UIApplication sharedApplication] statusBarOrientation];
    
    if (orientationOnLunch == UIInterfaceOrientationPortrait)
        return CGSizeMake(collectionView.frame.size.width / 5.1f, collectionView.frame.size.width / 5.1f);
    else
        return CGSizeMake(collectionView.frame.size.width / 7.1f, collectionView.frame.size.width / 7.1f);
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    if ([sectionDataSource.sections count] - 1 == section)
        return CGSizeMake(collectionView.frame.size.width, 50);
    
    return CGSizeZero;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (kind == UICollectionElementKindSectionHeader) {
        
        UICollectionReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:indexPath];
        
        //headerView.backgroundColor = COLOR_GROUPBY_BAR_NO_BLUR;
        
        [self getGeoLocationForSection:indexPath.section];
        
        UILabel *titleLabel = (UILabel *)[headerView viewWithTag:100];
        titleLabel.textColor = [UIColor blackColor];
        if (sectionDataSource.sections.count > indexPath.section)
            titleLabel.text = [CCUtility getTitleSectionDate:[sectionDataSource.sections objectAtIndex:indexPath.section]];

        return headerView;
    }
    
    if (kind == UICollectionElementKindSectionFooter) {
        
        UICollectionReusableView *footerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"footer" forIndexPath:indexPath];
        
        UILabel *titleLabel = (UILabel *)[footerView viewWithTag:100];
        titleLabel.textColor = [UIColor grayColor];
        titleLabel.text = [NSString stringWithFormat:@"%lu %@, %lu %@", (long)sectionDataSource.image, NSLocalizedString(@"photo", nil), (long)sectionDataSource.video, NSLocalizedString(@"_video_", nil)];
        
        return footerView;
    }
    
    return nil;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    UIImageView *imageView = (UIImageView *)[cell viewWithTag:100];
    UIVisualEffectView *effect = [cell viewWithTag:200];

    UIImageView *checked = [cell viewWithTag:300];
    checked.image = [UIImage imageNamed:@"checked"];

    NSArray *metadatasForKey = [sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:indexPath.section]];
    
    if ([metadatasForKey count] > indexPath.row) {
        
        NSString *fileID = [metadatasForKey objectAtIndex:indexPath.row];
        tableMetadata *metadata = [sectionDataSource.allRecordsDataSource objectForKey:fileID];
    
        // Image
        if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]]) {
        
            // insert Image
            imageView.image = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]];
        
        } else {
        
            imageView.image = [UIImage imageNamed:@"file_photo"];

            if (metadata.thumbnailExists) {
                [self downloadThumbnail:metadata indexPath:indexPath];
            }
        }
    
        // Cheched
        if (cell.selected) {
            checked.hidden = NO;
            effect.hidden = NO;
            effect.alpha = 0.4;
        } else {
            checked.hidden = YES;
            effect.hidden = YES;
        }
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *metadatasForKey = [sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:indexPath.section]];
    
    if ([metadatasForKey count] > indexPath.row) {
        
        NSString *fileID = [metadatasForKey objectAtIndex:indexPath.row];
        self.metadata = [sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
        if (isEditMode) {
        
            [self cellSelect:YES indexPath:indexPath metadata:self.metadata];
        
        } else {
        
            if ([self shouldPerformSegue])
                [self performSegueWithIdentifier:@"segueDetail" sender:self];
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // test
    if (isEditMode == NO)
        return;
   
    NSArray *metadatasForKey = [sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:indexPath.section]];
    
    if ([metadatasForKey count] > indexPath.row) {
        
        NSString *fileID = [metadatasForKey objectAtIndex:indexPath.row];
        self.metadata = [sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
        [self cellSelect:NO indexPath:indexPath metadata:self.metadata];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Navigation ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)shouldPerformSegue
{
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
        return NO;
    
    // Not in first plain ? exit
    if (self.view.window == NO)
        return NO;
    
    // Collapsed but in first plain in detail exit
    if (self.splitViewController.isCollapsed)
        if (self.detailViewController.isViewLoaded && self.detailViewController.view.window)
            return NO;
    
    // check if metadata is invalidated
    if ([[NCManageDatabase sharedInstance] isTableInvalidated:self.metadata]) {
        return NO;
    }
    
    // ok perform segue
    return YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    id controller = segue.destinationViewController;
    
    if ([controller isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = controller;
        self.detailViewController = (CCDetail *)navigationController.topViewController;
    } else {
        self.detailViewController = segue.destinationViewController;
    }
    
    NSMutableArray *photoDataSource = [NSMutableArray new];
    
    for (NSString *fileID in sectionDataSource.allFileID) {
        tableMetadata *metadata = [sectionDataSource.allRecordsDataSource objectForKey:fileID];
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
            [photoDataSource addObject:metadata];
    }
    
    self.detailViewController.photoDataSource = photoDataSource;
    self.detailViewController.metadataDetail = self.metadata;
    self.detailViewController.dateFilterQuery = self.metadata.date;
    
    [self.detailViewController setTitle:self.metadata.fileName];
}

@end
