//
//  CCPhotosCameraUpload.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 29/07/15.
//  Copyright (c) 2014 TWS. All rights reserved.
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

#import "CCPhotosCameraUpload.h"

#import "AppDelegate.h"

@interface CCPhotosCameraUpload ()
{
    CCMetadata *_metadata;

    BOOL _cellEditing;
    NSMutableArray *_queueMetadatas;
    NSMutableArray *_selectedMetadatas;
    NSUInteger _numSelectedMetadatas;
    BOOL _AutomaticCameraUploadInProgress;      // START/STOP new request : initStateCameraUpload
    
    CCSectionDataSource *_sectionDataSource;
    
    CCHud *_hud;
}
@end

@implementation CCPhotosCameraUpload

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initStateCameraUpload:) name:@"initStateCameraUpload" object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupCameraUploadFull) name:@"setupCameraUploadFull" object:nil];
        
        app.activePhotosCameraUpload = self;
    }
    
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _queueMetadatas = [[NSMutableArray alloc] init];
    _selectedMetadatas = [[NSMutableArray alloc] init];
    _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
    
    // empty Data Source
    self.collectionView.emptyDataSetDelegate = self;
    self.collectionView.emptyDataSetSource = self;
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    [self reloadDatasource];
}

// E' arrivato
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.navigationController cancelCCProgress];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // Dispose of any resources that can be recreated.
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ====== Photos ======
#pragma --------------------------------------------------------------------------------------------

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Gestione Grafica Window =====
#pragma --------------------------------------------------------------------------------------------

- (void)setUINavigationBarDefault
{
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    
    // select
    UIImage *icon = [UIImage imageNamed:image_seleziona];
    UIBarButtonItem *buttonSelect = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(collectionSelectYES)];
    
    if ([_sectionDataSource.allRecordsDataSource count] > 0) buttonSelect.enabled = true;
    else buttonSelect.enabled = false;
    
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonSelect, nil];
    self.navigationItem.leftBarButtonItem = nil;
    
    // Title
    self.navigationItem.title = NSLocalizedString(@"_photo_camera_", nil);
}

- (void)setUINavigationBarSeleziona
{
    UIImage *icon;
    
    icon = [UIImage imageNamed:image_deleteSelectedFiles];
    UIBarButtonItem *buttonDelete = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(deleteSelectedFiles)];
    
    icon = [UIImage imageNamed:image_openSelectedFiles];
    UIBarButtonItem *buttonOpenWith = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(openSelectedFiles)];
    
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIBarButtonItemStylePlain target:self action:@selector(reloadCollection)];
    
    self.navigationItem.leftBarButtonItem = leftButton;
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonDelete, buttonOpenWith, nil];
    
    // Title
    self.navigationItem.title = [NSString stringWithFormat:@"%@ : %lu / %lu", NSLocalizedString(@"_selected_", nil), (unsigned long)[_selectedMetadatas count], (unsigned long)[_sectionDataSource.allRecordsDataSource count]];
}

- (void)collectionSelect:(BOOL)edit
{
    [self.collectionView setAllowsMultipleSelection:edit];
    
    _cellEditing = edit;
    
    if (edit)
        [self setUINavigationBarSeleziona];
    else
        [self setUINavigationBarDefault];
}

- (void)collectionSelectYES
{
    [self collectionSelect:YES];
}

- (void)cellSelect:(BOOL)select indexPath:(NSIndexPath *)indexPath metadata:(CCMetadata *)metadata
{
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
    UIVisualEffectView *effect = [cell viewWithTag:200];
    UIImageView *checked = [cell viewWithTag:300];
    
    if (select) {
        effect.hidden = NO;
        effect.alpha = 0.4;
        checked.hidden = NO;
        [_selectedMetadatas addObject:metadata];
        
    } else {
        effect.hidden = YES;
        checked.hidden = YES;
        [_selectedMetadatas removeObject:metadata];
    }
    
    // Title
    self.navigationItem.title = [NSString stringWithFormat:@"%@ : %lu / %lu", NSLocalizedString(@"_selected_", nil), (unsigned long)[_selectedMetadatas count], (unsigned long)[_sectionDataSource.allRecordsDataSource count]];
}

- (void)scrollToTop
{
    [self.collectionView setContentOffset:CGPointMake(0, - self.collectionView.contentInset.top) animated:NO];
}

- (void)getGeoLocationForSection:(NSInteger)section
{
    NSString *addLocation = @"";
    
    NSArray *fileIDsForKey = [_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:section]];
    
    for (NSString *fileID in fileIDsForKey) {
    
        TableLocalFile *localFile = [CCCoreData getLocalFileWithFileID:fileID activeAccount:app.activeAccount];
    
        if ([localFile.exifLatitude floatValue] > 0 || [localFile.exifLongitude floatValue] > 0) {
        
            NSString *location = [CCCoreData getLocationFromGeoLatitude:localFile.exifLatitude longitude:localFile.exifLongitude];
            
            addLocation = [NSString stringWithFormat:@"%@, %@", addLocation, location];
        
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Photo Library Change Observer ====
#pragma --------------------------------------------------------------------------------------------

- (void)photoLibraryDidChange:(PHChange *)changeInfo
{
    /*
     PHFetchResultChangeDetails *collectionChanges = [changeInfo changeDetailsForFetchResult:self.assetsFetchResult];
     
     if (collectionChanges) {
     
     self.assetsFetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum | PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
     
     dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
     [self uploadNewAssets];
     });
     }
     */
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource Methods ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)emptyDataSetShouldDisplay:(UIScrollView *)scrollView
{
    return YES;
}

/*
- (BOOL)emptyDataSetShouldAllowScroll:(UIScrollView *)scrollView
{    
    return YES;
}
*/

- (CGFloat)spaceHeightForEmptyDataSet:(UIScrollView *)scrollView
{
    return 0.0f;
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView
{
    return - self.navigationController.navigationBar.frame.size.height;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIColor whiteColor];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIImage imageNamed:image_brandCameraUpload];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = NSLocalizedString(@"_no_photo_load_", nil);
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:COLOR_BRAND};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0], NSForegroundColorAttributeName: [UIColor lightGrayColor], NSParagraphStyleAttributeName: paragraph};
    
    if ([CCCoreData getCameraUploadActiveAccount:app.activeAccount])
        return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"_tutorial_photo_view_", nil) attributes:attributes];
    else
        return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"_tutorial_camera_upload_view_", nil) attributes:attributes];
}

- (UIImage *)buttonImageForEmptyDataSet:(UIScrollView *)scrollView forState:(UIControlState)state
{
    if ([CCCoreData getCameraUploadActiveAccount:app.activeAccount] == NO) {
    
        NSString *language = [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];
    
        if ([language isEqualToString:@"it"]) return [UIImage imageNamed:image_activeCameraUpload_it];
        else return [UIImage imageNamed:image_activeCameraUpload_en];
            
    } else return nil;
}

- (void)emptyDataSetDidTapButton:(UIScrollView *)scrollView
{    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        
        // If the user has previously granted or denied photo library access permission, it executes the handler block when called; otherwise, it displays an alert and executes the block only after the user has responded to the alert.
        CCManageCameraUpload *viewController = [[CCManageCameraUpload alloc] initWithNibName:nil bundle:nil];
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        
        [navigationController setModalPresentationStyle:UIModalPresentationFullScreen];
        [self presentViewController:navigationController animated:YES completion:nil];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== openSelectedFiles =====
#pragma--------------------------------------------------------------------------------------------

- (void)openSelectedFiles
{
    NSMutableArray *dataToShare = [[NSMutableArray alloc] init];
    
    for (CCMetadata *metadata in _selectedMetadatas) {
    
        NSString *fileNamePath = [NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint];
        
        [[NSFileManager defaultManager] linkItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID] toPath:fileNamePath error:nil];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:fileNamePath]) {
            
            if ([metadata.typeFile isEqualToString:metadataTypeFile_image]) {
                
                NSData *data = [NSData dataWithData:UIImageJPEGRepresentation([UIImage imageWithContentsOfFile:fileNamePath], 0.9)];
                [dataToShare addObject:data];
            }
            
            if ([metadata.typeFile isEqualToString:metadataTypeFile_video]) {
                
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
                
                if (completed) {
                    
                    [dataToShare enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        
                        if ([obj isKindOfClass:[UIImage class]])
                            [CCCoreData setCameraUploadDatePhoto:[NSDate date]];
                        
                        if ([obj isKindOfClass:[NSURL class]])
                            [CCCoreData setCameraUploadDateVideo:[NSDate date]];
                    }];
                    
                    [self performSelector:@selector(reloadCollection) withObject:nil];
                }
            }];
        }];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Download =====
#pragma--------------------------------------------------------------------------------------------

- (void)downloadFileFailure:(NSInteger)errorCode
{
    [app messageNotification:@"_download_selected_files_" description:@"_error_download_photobrowser_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
}

- (void)downloadFileSuccess:(CCMetadata *)metadata
{
    NSIndexPath *indexPath;
    BOOL existsIcon = NO;
    
    if (metadata.fileID) {
        existsIcon = [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
        indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:metadata.fileID];
    }
    
    if (indexPath && existsIcon) {
        
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
        
        if (cell) {
            UIImageView *imageView = (UIImageView *)[cell viewWithTag:100];
            UIVisualEffectView *effect = [cell viewWithTag:200];
            UIImageView *checked = [cell viewWithTag:300];
            
            imageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
            effect.hidden = YES;
            checked.hidden = YES;
            
            [app.icoImagesCache setObject:imageView.image forKey:metadata.fileID];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delete =====
#pragma--------------------------------------------------------------------------------------------

- (void)deleteFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [_hud hideHud];
    
    if (errorCode == 404)
        [self deleteFileOrFolderSuccess:metadataNet];
    
    if (message)
        [app messageNotification:@"_delete_" description:message visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
    
    // if detailViewController
    if (self.detailViewController)
            [self.detailViewController deleteFileFailure:errorCode];
    
    [_queueMetadatas removeAllObjects];
    
    [self reloadDatasource];
}

- (void)deleteFileOrFolderSuccess:(CCMetadataNet *)metadataNet
{
    [_queueMetadatas removeObject:metadataNet.selector];
    
    if ([_queueMetadatas count] == 0) {
        
        [_hud hideHud];

        CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadataNet.fileID, app.activeAccount] context:nil];
    
        if (metadata)
            [CCCoreData deleteFile:metadata serverUrl:metadataNet.serverUrl directoryUser:app.directoryUser typeCloud:app.typeCloud activeAccount:app.activeAccount];
    
        if (self.detailViewController)
            [self.detailViewController deleteFileSuccess:metadata metadataNetVar:metadataNet];
    
        if ([_selectedMetadatas count] > 0) {
            
            [_selectedMetadatas removeObjectAtIndex:0];
            
            if ([_selectedMetadatas count] > 0) {
                
                [self deleteFileOrFolder:[_selectedMetadatas objectAtIndex:0] numFile:[_selectedMetadatas count] ofFile:_numSelectedMetadatas];
                
            } else {
                
                [self reloadDatasource];
            }
            
        } else {
            
            [self reloadDatasource];
        }
    }
}

- (void)deleteFileOrFolder:(CCMetadata *)metadata numFile:(NSInteger)numFile ofFile:(NSInteger)ofFile
{
    if (metadata.cryptated == YES) {
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionDeleteFileDirectory;
        metadataNet.fileID = metadata.fileID;
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:app.activeAccount];
        
        // data crypto
        metadataNet.fileName = metadata.fileNameData;
        metadataNet.selector = selectorDeleteCrypto;
        
        [_queueMetadatas addObject:metadataNet.selector];
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
        // plist
        metadataNet.fileName = metadata.fileName;
        metadataNet.selector = selectorDeletePlist;
        
        [_queueMetadatas addObject:metadataNet.selector];
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
    } else  {
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionDeleteFileDirectory;
        metadataNet.fileID = metadata.fileID;
        metadataNet.fileName = metadata.fileName;
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.selector = selectorDelete;
        metadataNet.serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:app.activeAccount];
        
        [_queueMetadatas addObject:metadataNet.selector];
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
    
    [_hud visibleHudTitle:[NSString stringWithFormat:NSLocalizedString(@"_delete_file_n_", nil), ofFile - numFile + 1, ofFile] mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)deleteSelectedFiles
{
    [_queueMetadatas removeAllObjects];
    
    _numSelectedMetadatas = [_selectedMetadatas count];
    
    if ([_selectedMetadatas count] == 0)
        return;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil)
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
                                                           [self deleteFileOrFolder:[_selectedMetadatas objectAtIndex:0] numFile:[_selectedMetadatas count] ofFile:_numSelectedMetadatas];
                                                       }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil)
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                           [alertController dismissViewControllerAnimated:YES completion:nil];
                                                       }]];
    
    alertController.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:NULL];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Collection ====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadDatasourceForced
{
    [CCSection removeAllObjectsSectionDataSource:_sectionDataSource];
    [self reloadDatasource];
}

- (void)reloadDatasource
{
    // controlli
    if (app.activeAccount == nil || app.activeUrl == nil) return;
    
    
    NSString *serverUrl = [CCCoreData getCameraUploadFolderNamePathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];

    // datasource
    NSArray *recordsTableMetadata = [CCCoreData getRecordsTableMetadataPhotosCameraUpload:serverUrl activeAccount:app.activeAccount];
    
    _sectionDataSource = [CCSection creataDataSourseSectionTableMetadata:recordsTableMetadata listProgressMetadata:nil groupByField:@"date" replaceDateToExifDate:YES activeAccount:app.activeAccount];
        
    //if ([_sectionDataSource.allRecordsDataSource count] == 0)
    //    _dateReadDataSource = nil;
    
    [self reloadCollection];
}

- (void)reloadCollection
{
    [self.collectionView reloadData];
        
    [_selectedMetadatas removeAllObjects];
    [self collectionSelect:NO];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{    
    return [[_sectionDataSource.sectionArrayRow allKeys] count];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:section]] count];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UIInterfaceOrientation orientationOnLunch = [[UIApplication sharedApplication] statusBarOrientation];
    
    if (orientationOnLunch == UIInterfaceOrientationPortrait)
        return CGSizeMake(collectionView.frame.size.width / 5.3f, collectionView.frame.size.width / 5.3f);
    else
        return CGSizeMake(collectionView.frame.size.width / 7.3f, collectionView.frame.size.width / 7.3f);
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    if ([_sectionDataSource.sections count] - 1 == section)
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
        titleLabel.textColor = COLOR_GRAY;
        titleLabel.text = [CCUtility getTitleSectionDate:[_sectionDataSource.sections objectAtIndex:indexPath.section]];

        return headerView;
    }
    
    if (kind == UICollectionElementKindSectionFooter) {
        
        UICollectionReusableView *footerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"footer" forIndexPath:indexPath];
        
        UILabel *titleLabel = (UILabel *)[footerView viewWithTag:100];
        titleLabel.textColor = [UIColor grayColor];
        titleLabel.text = [NSString stringWithFormat:@"%lu %@, %lu %@", (long)_sectionDataSource.image, NSLocalizedString(@"photo", nil), (long)_sectionDataSource.video, NSLocalizedString(@"_video_", nil)];
        
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
    checked.image = [UIImage imageNamed:image_checked];

    NSArray *metadatasForKey = [_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]];
    NSString *fileID = [metadatasForKey objectAtIndex:indexPath.row];
    CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
    
    // Image
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]]) {
        
        imageView.image = [app.icoImagesCache objectForKey:metadata.fileID];
        
        if (imageView.image == nil) {
            
                // insert Image
                UIImage *image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
                imageView.image = image;
                [app.icoImagesCache setObject:image forKey:metadata.fileID];
        }
        
    } else {
        
        imageView.image = [UIImage imageNamed:image_photosDownload];
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
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *metadatasForKey = [_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]];
    NSString *fileID = [metadatasForKey objectAtIndex:indexPath.row];
    _metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
    
    //UICollectionViewCell *cell =[collectionView cellForItemAtIndexPath:indexPath];
    
    if (_cellEditing) {
        
        if ([CCCoreData getLocalFileWithFileID:fileID activeAccount:app.activeAccount])
            [self cellSelect:YES indexPath:indexPath metadata:_metadata];
        else
            [app messageNotification:@"_info_" description:@"_select_only_localfile_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeInfo];
        
    } else {
        
        if ([self shouldPerformSegue])
            [self performSegueWithIdentifier:@"segueDetail" sender:self];
    }    
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (_cellEditing == NO)
        return;
 
    //UICollectionViewCell *cell =[collectionView cellForItemAtIndexPath:indexPath];
    
    NSArray *metadatasForKey = [_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]];
    NSString *fileID = [metadatasForKey objectAtIndex:indexPath.row];
    _metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
    
    [self cellSelect:NO indexPath:indexPath metadata:_metadata];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Navigation ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)shouldPerformSegue
{
    // Test
    
    // Background ? exit
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
        return NO;
    
    // Not in first plain ? exit
    if (self.view.window == NO)
        return NO;
    
    // Collapsed but in first plain in detail exit
    if (self.splitViewController.isCollapsed)
        if (self.detailViewController.isViewLoaded && self.detailViewController.view.window)
            return NO;
    
    // Video running exit
    if (self.detailViewController.photoBrowser.currentVideoPlayerViewController.isViewLoaded && self.detailViewController.photoBrowser.currentVideoPlayerViewController.view.window)
        return NO;
    
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
    
    NSMutableArray *allRecordsDataSourceImagesVideos = [[NSMutableArray alloc] init];
    for (NSString *fileID in _sectionDataSource.allFileID) {
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        if ([metadata.typeFile isEqualToString:metadataTypeFile_image] || [metadata.typeFile isEqualToString:metadataTypeFile_video])
            [allRecordsDataSourceImagesVideos addObject:metadata];
    }
    
    self.detailViewController.delegate = self;
    self.detailViewController.dataSourceImagesVideos = allRecordsDataSourceImagesVideos;
    self.detailViewController.metadataDetail = _metadata;
    self.detailViewController.dateFilterQuery = _metadata.date;
    self.detailViewController.isCameraUpload = YES;
    self.detailViewController.sourceDirectory = sorceDirectoryAccount;
    
    [self.detailViewController setTitle:_metadata.fileNamePrint];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ====== --- Camera Upload --- ======
#pragma --------------------------------------------------------------------------------------------

#pragma --------------------------------------------------------------------------------------------
#pragma mark === initStateCameraUpload ===
#pragma --------------------------------------------------------------------------------------------

- (void)initStateCameraUpload:(NSNotification *)notification
{
    int afterDelay = 0;
    
    if (notification.object)
        afterDelay = [[notification.object objectForKey:@"afterDelay"] intValue];
    
    [self performSelector:@selector(initStateCameraUpload) withObject:nil afterDelay:afterDelay];
}

- (void)initStateCameraUpload
{
    if (_AutomaticCameraUploadInProgress)
        return;
    
    if([CCCoreData getCameraUploadActiveAccount:app.activeAccount]) {
        
        [self setupCameraUpload];
        
        if([CCCoreData getCameraUploadBackgroundActiveAccount:app.activeAccount])
            [self checkIfLocationIsEnabled];
        
    } else {
        
        [CCCoreData setCameraUpload:NO activeAccount:app.activeAccount];
                
        [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:self];
        
        [[CCManageLocation sharedSingleton] stopSignificantChangeUpdates];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Camera Upload & Full ===
#pragma --------------------------------------------------------------------------------------------

- (void)setupCameraUpload
{
    if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
        
        self.assetsFetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum | PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
        
        [PHPhotoLibrary.sharedPhotoLibrary registerChangeObserver:self];
        
        [self uploadNewAssets];
        
    } else {
    
        [CCCoreData setCameraUpload:NO activeAccount:app.activeAccount];
                
        [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:self];
        
        [[CCManageLocation sharedSingleton] stopSignificantChangeUpdates];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil)
                                                        message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (void)setupCameraUploadFull
{
    if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
        
        self.assetsFetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum | PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
        
        [PHPhotoLibrary.sharedPhotoLibrary registerChangeObserver:self];
        
        [self uploadFullAssets];
        
    } else {
        
        [CCCoreData setCameraUpload:NO activeAccount:app.activeAccount];
        
        [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:self];
        
        [[CCManageLocation sharedSingleton] stopSignificantChangeUpdates];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil)
                                                        message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                              otherButtonTitles:nil];
        [alert show];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Location ===
#pragma --------------------------------------------------------------------------------------------

- (BOOL)checkIfLocationIsEnabled
{
    [CCManageLocation sharedSingleton].delegate = self;
    
    if ([CLLocationManager locationServicesEnabled]) {
        
        NSLog(@"[LOG] checkIfLocationIsEnabled : authorizationStatus: %d", [CLLocationManager authorizationStatus]);
        
        if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways) {
            
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined ) {
                
                NSLog(@"[LOG] checkIfLocationIsEnabled : Location services not determined");
                [[CCManageLocation sharedSingleton] startSignificantChangeUpdates];
                
            } else {
                
                if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
                    
                    [CCCoreData setCameraUploadBackground:NO activeAccount:app.activeAccount];
                    
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_location_not_enabled_", nil)
                                                                    message:NSLocalizedString(@"_location_not_enabled_msg_", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                                          otherButtonTitles:nil];
                    [alert show];
                    
                } else {
                    
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil)
                                                                    message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                                          otherButtonTitles:nil];
                    [alert show];
                }
            }
            
        } else {
            
            if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
                
                [CCCoreData setCameraUploadBackground:YES activeAccount:app.activeAccount];
                [[CCManageLocation sharedSingleton] startSignificantChangeUpdates];
                
            } else {
                
                [CCCoreData setCameraUploadBackground:NO activeAccount:app.activeAccount];
                [[CCManageLocation sharedSingleton] stopSignificantChangeUpdates];
                
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil)
                                                                 message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil)
                                                                delegate:nil
                                                       cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                                       otherButtonTitles:nil];
                [alert show];
            }
        }
        
    } else {
        
        [CCCoreData setCameraUploadBackground:NO activeAccount:app.activeAccount];
        [[CCManageLocation sharedSingleton] stopSignificantChangeUpdates];
        
        if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_location_not_enabled_", nil)
                                                            message:NSLocalizedString(@"_location_not_enabled_msg_", nil)
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                                  otherButtonTitles:nil];
            [alert show];
            
        } else {
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_access_photo_location_not_enabled_", nil)
                                                            message:NSLocalizedString(@"_access_photo_location_not_enabled_msg_", nil)
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }
    
    return [CCCoreData getCameraUploadBackgroundActiveAccount:app.activeAccount];
}


- (void)statusAuthorizationLocationChanged
{
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined){
        
        if (![CCManageLocation sharedSingleton].firstChangeAuthorizationDone) {
            
            ALAssetsLibrary *assetLibrary = [CCUtility defaultAssetsLibrary];
            
            [assetLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
                                        usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                            
                                        } failureBlock:^(NSError *error) {
                                            
                                        }];
        }
        
        if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
            
            if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
                
                if ([CCManageLocation sharedSingleton].firstChangeAuthorizationDone) {
                    
                    [CCCoreData setCameraUploadBackground:NO activeAccount:app.activeAccount];
                    [[CCManageLocation sharedSingleton] stopSignificantChangeUpdates];
                }
                
            } else {
                
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil)
                                                                 message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil)
                                                                delegate:nil
                                                       cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                                       otherButtonTitles:nil];
                [alert show];
            }
            
        } else if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined){
            
            if ([CCCoreData getCameraUploadBackgroundActiveAccount:app.activeAccount]) {
                
                [CCCoreData setCameraUploadBackground:NO activeAccount:app.activeAccount];
                [[CCManageLocation sharedSingleton] stopSignificantChangeUpdates];
                
                if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_location_not_enabled_", nil)
                                                                    message:NSLocalizedString(@"_location_not_enabled_msg_", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                                          otherButtonTitles:nil];
                    [alert show];
                    
                } else {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_access_photo_location_not_enabled_", nil)
                                                                    message:NSLocalizedString(@"_access_photo_location_not_enabled_msg_", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                                          otherButtonTitles:nil];
                    [alert show];
                }
            }
        }
        
        if (![CCManageLocation sharedSingleton].firstChangeAuthorizationDone) {
            
            [CCManageLocation sharedSingleton].firstChangeAuthorizationDone = YES;
        }
    }
}

- (void)changedLocation
{
    //Verifica
    [[CCNetworking sharedNetworking] automaticDownloadInError];
    [[CCNetworking sharedNetworking] automaticUploadInError];
    
    // solo in background
    if([CCCoreData getCameraUploadActiveAccount:app.activeAccount] && [CCCoreData getCameraUploadBackgroundActiveAccount:app.activeAccount ] && [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        
        if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
            
            //check location
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
                
                NSLog(@"[LOG] Changed Location call uploadNewAssets");

                [self uploadNewAssets];
            }
            
        } else {
            
            [CCCoreData setCameraUpload:NO activeAccount:app.activeAccount];
            
            [CCCoreData setCameraUploadBackground:NO activeAccount:app.activeAccount];
            
            [[CCManageLocation sharedSingleton] stopSignificantChangeUpdates];
            [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:self];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Upload Assets : NEW & FULL ====
#pragma --------------------------------------------------------------------------------------------

- (void)uploadNewAssets
{
    [self uploadAssetsNewAndFull:NO];
}

- (void)uploadFullAssets
{
    [self uploadAssetsNewAndFull:YES];
}

- (void)uploadAssetsNewAndFull:(BOOL)assetsFull
{
    CCManageAsset *manageAsset = [[CCManageAsset alloc] init];
    NSMutableArray *newItemsToUpload;
    
    // Check Asset : NEW or FULL
    if (assetsFull) {
        
        newItemsToUpload = [manageAsset getCameraRollNewItemsWithDatePhoto:[NSDate distantPast] dateVideo:[NSDate distantPast]];
        
    } else {
        
        NSDate *databaseDateVideo = [CCCoreData getCameraUploadDateVideoActiveAccount:app.activeAccount];
        NSDate *databaseDatePhoto = [CCCoreData getCameraUploadDatePhotoActiveAccount:app.activeAccount];
        
        newItemsToUpload = [manageAsset getCameraRollNewItemsWithDatePhoto:databaseDatePhoto dateVideo:databaseDateVideo];
    }
    
    // News Assets ? if no verify if blocked Table Automatic Upload -> Autostart
    if ([newItemsToUpload count] == 0)
        return;
    
    // STOP new request : initStateCameraUpload
    _AutomaticCameraUploadInProgress = YES;
    
    NSString *folderPhotos = [CCCoreData getCameraUploadFolderNamePathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
    
    // verify/create folder Camera Upload, if error exit
    if(![self createFolder:folderPhotos]) {
        
        // Full Upload ?
        if (assetsFull)
            [app messageNotification:@"_error_" description:NSLocalizedStringFromTable(@"_not_possible_create_folder_", @"Error", nil) visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeInfo];
        
        // START new request : initStateCameraUpload
        _AutomaticCameraUploadInProgress = NO;
        
        return;
    }

    // Disable idle timer
    [[UIApplication sharedApplication] setIdleTimerDisabled: YES];
        
    if (!_hud) _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
    
    if (assetsFull)
        [_hud visibleHudTitle:NSLocalizedString(@"_create_full_upload_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
    else
        [_hud visibleHudTitle:nil mode:MBProgressHUDModeIndeterminate color:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
        if (assetsFull)
            [self performSelectorOnMainThread:@selector(uploadFullAssetsToNetwork:) withObject:newItemsToUpload waitUntilDone:NO];
        else
            [self performSelectorOnMainThread:@selector(uploadNewAssetsToNetwork:) withObject:newItemsToUpload waitUntilDone:NO];
    });
}

- (void)uploadNewAssetsToNetwork:(NSMutableArray *)newItemsToUpload
{
    [self uploadAssetsToNetwork:newItemsToUpload assetsFull:NO];
}

- (void)uploadFullAssetsToNetwork:(NSMutableArray *)newItemsToUpload
{
    [self uploadAssetsToNetwork:newItemsToUpload assetsFull:YES];
}

- (void)uploadAssetsToNetwork:(NSMutableArray *)newItemsToUpload assetsFull:(BOOL)assetsFull
{
    NSMutableArray *newItemsPHAssetToUpload = [[NSMutableArray alloc] init];
    
    NSString *folderPhotos = [CCCoreData getCameraUploadFolderNamePathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
    BOOL createSubfolders = [CCCoreData getCameraUploadCreateSubfolderActiveAccount:app.activeAccount];
    
    // Conversion from ALAsset -to-> PHAsset
    for (ALAsset *asset in newItemsToUpload) {
        
        NSURL *url = [asset valueForProperty:@"ALAssetPropertyAssetURL"];
        PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil];
        PHAsset *asset = [fetchResult firstObject];
        [newItemsPHAssetToUpload addObject:asset];
    }
        
    // Use subfolders
    if (createSubfolders) {
        
        for (NSString *dateSubFolder in [CCUtility createNameSubFolder:newItemsPHAssetToUpload]) {
            
            if (![self createFolder:[NSString stringWithFormat:@"%@/%@", folderPhotos, dateSubFolder]]) {
                
                [self endLoadingAssets];
                
                if (assetsFull)
                    [app messageNotification:@"_error_" description:@"_error_createsubfolders_upload_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeInfo];
                
                return;
            }
        }
    }
    
    for (PHAsset *asset in newItemsPHAssetToUpload) {
        
        NSString *serverUrl;
        NSDate *assetDate = asset.creationDate;
        PHAssetMediaType assetMediaType = asset.mediaType;
        NSString *session;
        NSString *fileName = [CCUtility createFileNameFromAsset:asset key:nil];
        
        // Select type of session
        
        if (assetMediaType == PHAssetMediaTypeImage && [CCCoreData getCameraUploadWWanPhotoActiveAccount:app.activeAccount] == NO) session = upload_session;
        if (assetMediaType == PHAssetMediaTypeVideo && [CCCoreData getCameraUploadWWanVideoActiveAccount:app.activeAccount] == NO) session = upload_session;
        if (assetMediaType == PHAssetMediaTypeImage && [CCCoreData getCameraUploadWWanPhotoActiveAccount:app.activeAccount]) session = upload_session_wwan;
        if (assetMediaType == PHAssetMediaTypeVideo && [CCCoreData getCameraUploadWWanVideoActiveAccount:app.activeAccount]) session = upload_session_wwan;

        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        
        [formatter setDateFormat:@"yyyy"];
        NSString *yearString = [formatter stringFromDate:assetDate];
        
        [formatter setDateFormat:@"MM"];
        NSString *monthString = [formatter stringFromDate:assetDate];

        if (createSubfolders)
            serverUrl = [NSString stringWithFormat:@"%@/%@/%@", folderPhotos, yearString, monthString];
        else
            serverUrl = folderPhotos;
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
            
        metadataNet.action = actionUploadAsset;
        metadataNet.assetLocalItentifier = asset.localIdentifier;
        if (assetsFull) {
            metadataNet.selector = selectorUploadAutomaticAll;
            metadataNet.selectorPost = selectorUploadRemovePhoto;
            metadataNet.priority = NSOperationQueuePriorityLow;
        } else {
            metadataNet.selector = selectorUploadAutomatic;
            metadataNet.selectorPost = nil;
            metadataNet.priority = NSOperationQueuePriorityHigh;
        }
        metadataNet.fileName = fileName;
        metadataNet.serverUrl = serverUrl;
        metadataNet.session = session;
        metadataNet.taskStatus = taskStatusResume;
        
        [CCCoreData addTableAutomaticUpload:metadataNet account:app.activeAccount context:nil];
        
        // Upldate Camera Upload data  
        if ([metadataNet.selector isEqualToString:selectorUploadAutomatic])
            [CCCoreData setCameraUploadDateAssetType:assetMediaType assetDate:assetDate activeAccount:app.activeAccount];
    }
    
    // start upload
    if (assetsFull)
        [app loadTableAutomaticUploadForSelector:selectorUploadAutomaticAll];
    else
        [app loadTableAutomaticUploadForSelector:selectorUploadAutomatic];

    // end loading
    [self endLoadingAssets];
    
    // Update icon badge number
    [app updateApplicationIconBadgeNumber];
}

- (BOOL)createFolder:(NSString *)folderPathName
{
    OCnetworking *ocNet;
    
    if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud]) {
        
        NSError *error;
        
        ocNet = [[OCnetworking alloc] initWithDelegate:self metadataNet:nil withUser:app.activeUser withPassword:app.activePassword withUrl:app.activeUrl withTypeCloud:app.typeCloud activityIndicator:NO];
    
        error = [ocNet readFileSync:folderPathName];
        if(!error)
            return YES;
        
        error = [ocNet createFolderSync:folderPathName];
        if (!error) {
        
            [CCCoreData clearDateReadDirectory:[CCUtility deletingLastPathComponentFromServerUrl:folderPathName] activeAccount:app.activeAccount];
            return YES;
        }
    }
    
    return NO;
}

-(void)endLoadingAssets
{
    [_hud hideHud];
    
    // START new request : initStateCameraUpload
    _AutomaticCameraUploadInProgress = NO;
    
    // Enable idle timer
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];

    // START new request : initStateCameraUpload
    _AutomaticCameraUploadInProgress = NO;
}

@end
