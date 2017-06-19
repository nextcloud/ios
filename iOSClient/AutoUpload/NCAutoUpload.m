//
//  NCAutoUpload.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 07/06/17.
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

#import "NCAutoUpload.h"
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@interface NCAutoUpload ()
{
    PHFetchResult *_assetsFetchResult;

    CCHud *_hud;
}
@end

@implementation NCAutoUpload

+ (NCAutoUpload *)sharedInstance {
    
    static NCAutoUpload *sharedInstance;
    
    @synchronized(self)
    {
        if (!sharedInstance) {
            
            sharedInstance = [NCAutoUpload new];
        }
        return sharedInstance;
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
#pragma mark === initStateAutoUpload ===
#pragma --------------------------------------------------------------------------------------------

- (void)initStateAutoUpload
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if (tableAccount.autoUpload) {
        
        [self setupAutoUpload];
        
        if (tableAccount.autoUploadBackground) {
         
            [self checkIfLocationIsEnabled];
        }
        
    } else {
        
        [[NCManageDatabase sharedInstance] setAccountAutoUploadFiled:@"autoUpload" state:NO];
        
        [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:self];
        
        [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Camera Upload & Full ===
#pragma --------------------------------------------------------------------------------------------

- (void)setupAutoUpload
{
    if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
        
        _assetsFetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum | PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
        
        [PHPhotoLibrary.sharedPhotoLibrary registerChangeObserver:self];
        
        [self performSelectorOnMainThread:@selector(uploadNewAssets) withObject:nil waitUntilDone:NO];
        
    } else {
        
        [[NCManageDatabase sharedInstance] setAccountAutoUploadFiled:@"autoUpload" state:NO];
        
        [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:self];
        
        [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil)
                                                        message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (void)setupAutoUploadFull
{
    if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
        
        _assetsFetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum | PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
        
        [PHPhotoLibrary.sharedPhotoLibrary registerChangeObserver:self];
        
        [self performSelectorOnMainThread:@selector(uploadFullAssets) withObject:nil waitUntilDone:NO];
        
    } else {
        
        [[NCManageDatabase sharedInstance] setAccountAutoUploadFiled:@"autoUpload" state:NO];
        
        [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:self];
        
        [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
        
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
    [CCManageLocation sharedInstance].delegate = self;
    
    if ([CLLocationManager locationServicesEnabled]) {
        
        NSLog(@"[LOG] checkIfLocationIsEnabled : authorizationStatus: %d", [CLLocationManager authorizationStatus]);
        
        if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways) {
            
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined ) {
                
                NSLog(@"[LOG] checkIfLocationIsEnabled : Location services not determined");
                [[CCManageLocation sharedInstance] startSignificantChangeUpdates];
                
            } else {
                
                if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
                    
                    [[NCManageDatabase sharedInstance] setAccountAutoUploadFiled:@"autoUploadBackground" state:NO];
                    
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
                
                [[NCManageDatabase sharedInstance] setAccountAutoUploadFiled:@"autoUploadBackground" state:YES];
                [[CCManageLocation sharedInstance] startSignificantChangeUpdates];
                
            } else {
                
                [[NCManageDatabase sharedInstance] setAccountAutoUploadFiled:@"autoUploadBackground" state:NO];
                [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
                
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil)
                                                                 message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil)
                                                                delegate:nil
                                                       cancelButtonTitle:NSLocalizedString(@"_ok_", nil)
                                                       otherButtonTitles:nil];
                [alert show];
            }
        }
        
    } else {
        
        [[NCManageDatabase sharedInstance] setAccountAutoUploadFiled:@"autoUploadBackground" state:NO];
        [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
        
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
    
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    return tableAccount.autoUploadBackground;
}


- (void)statusAuthorizationLocationChanged
{
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined){
        
        if (![CCManageLocation sharedInstance].firstChangeAuthorizationDone) {
            
            ALAssetsLibrary *assetLibrary = [CCUtility defaultAssetsLibrary];
            
            [assetLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
                                        usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                            
                                        } failureBlock:^(NSError *error) {
                                            
                                        }];
        }
        
        if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
            
            if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
                
                if ([CCManageLocation sharedInstance].firstChangeAuthorizationDone) {
                    
                    [[NCManageDatabase sharedInstance] setAccountAutoUploadFiled:@"autoUploadBackground" state:NO];
                    [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
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
            
            tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
            
            if (tableAccount.autoUploadBackground) {
                
                [[NCManageDatabase sharedInstance] setAccountAutoUploadFiled:@"autoUploadBackground" state:NO];
                [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
                
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
        
        if (![CCManageLocation sharedInstance].firstChangeAuthorizationDone) {
            
            [CCManageLocation sharedInstance].firstChangeAuthorizationDone = YES;
        }
    }
}

- (void)changedLocation
{
    // Only in background
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if (tableAccount.autoUpload && tableAccount.autoUploadBackground && [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        
        
        if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) {
            
            //check location
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
                
                NSLog(@"[LOG] Changed Location call uploadNewAssets");
                
                [self uploadNewAssets];
            }
            
        } else {
            
            [[NCManageDatabase sharedInstance] setAccountAutoUploadFiled:@"autoUpload" state:NO];
            [[NCManageDatabase sharedInstance] setAccountAutoUploadFiled:@"autoUploadBackground" state:NO];
            
            [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
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
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    // Check Asset : NEW or FULL
    if (assetsFull) {
        
        newItemsToUpload = [manageAsset getCameraRollNewItemsWithDatePhoto:[NSDate distantPast] dateVideo:[NSDate distantPast]];
        
    } else {
        
        NSDate *databaseDatePhoto = tableAccount.autoUploadDatePhoto;
        NSDate *databaseDateVideo = tableAccount.autoUploadDateVideo;
        
        newItemsToUpload = [manageAsset getCameraRollNewItemsWithDatePhoto:databaseDatePhoto dateVideo:databaseDateVideo];
    }
    
    // News Assets ? if no verify if blocked Table Auto Upload -> Autostart
    if ([newItemsToUpload count] == 0) {
        
        NSLog(@"[LOG] Auto upload, no new asset found for date image %@, date video %@", tableAccount.autoUploadDatePhoto, tableAccount.autoUploadDateVideo);
        return;
        
    } else {
        
        NSLog(@"[LOG] Auto upload, new %lu asset found for date image %@, date video %@", (unsigned long)[newItemsToUpload count], tableAccount.autoUploadDatePhoto, tableAccount.autoUploadDateVideo);
    }
    
    if (assetsFull) {
        
        if (!_hud)
            _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
        
        [_hud visibleHudTitle:NSLocalizedString(@"_create_full_upload_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
    }
    
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
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    NSMutableArray *metadataNetFull = [NSMutableArray new];
  
    NSString *autoUploadPath = [[NCManageDatabase sharedInstance] getAccountAutoUploadPath:app.activeUrl];
    BOOL useSubFolder = tableAccount.autoUploadCreateSubfolder;
    
    // Conversion from ALAsset -to-> PHAsset
    for (ALAsset *asset in newItemsToUpload) {
        
        NSURL *url = [asset valueForProperty:@"ALAssetPropertyAssetURL"];
        PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil];
        PHAsset *asset = [fetchResult firstObject];
        [newItemsPHAssetToUpload addObject:asset];
        NSLog(@"Convert url %@", url);
    }
    
    // Create the folder for Photos & if request the subfolders
    if(![[NCAutoUpload sharedInstance] createFolderSubFolderAutoUploadFolderPhotos:autoUploadPath useSubFolder:useSubFolder assets:newItemsPHAssetToUpload selector:selectorUploadAutoUploadAll]) {
        
        // end loading
        [_hud hideHud];
        
        return;
    }
    
    for (PHAsset *asset in newItemsPHAssetToUpload) {
        
        NSString *serverUrl;
        NSDate *assetDate = asset.creationDate;
        PHAssetMediaType assetMediaType = asset.mediaType;
        NSString *session;
        NSString *fileName = [CCUtility createFileNameFromAsset:asset key:nil];
        
        // Select type of session
        
        if (assetMediaType == PHAssetMediaTypeImage && tableAccount.autoUploadWWAnPhoto == NO) session = k_upload_session;
        if (assetMediaType == PHAssetMediaTypeVideo && tableAccount.autoUploadWWAnVideo == NO) session = k_upload_session;
        if (assetMediaType == PHAssetMediaTypeImage && tableAccount.autoUploadWWAnPhoto) session = k_upload_session_wwan;
        if (assetMediaType == PHAssetMediaTypeVideo && tableAccount.autoUploadWWAnVideo) session = k_upload_session_wwan;
        
        NSDateFormatter *formatter = [NSDateFormatter new];
        
        [formatter setDateFormat:@"yyyy"];
        NSString *yearString = [formatter stringFromDate:assetDate];
        
        [formatter setDateFormat:@"MM"];
        NSString *monthString = [formatter stringFromDate:assetDate];
        
        if (useSubFolder)
            serverUrl = [NSString stringWithFormat:@"%@/%@/%@", autoUploadPath, yearString, monthString];
        else
            serverUrl = autoUploadPath;
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionUploadAsset;
        metadataNet.assetLocalIdentifier = asset.localIdentifier;
        if (assetsFull) {
            metadataNet.selector = selectorUploadAutoUploadAll;
            metadataNet.selectorPost = selectorUploadRemovePhoto;
            metadataNet.priority = NSOperationQueuePriorityLow;
        } else {
            metadataNet.selector = selectorUploadAutoUpload;
            metadataNet.selectorPost = nil;
            metadataNet.priority = NSOperationQueuePriorityLow;
        }
        metadataNet.fileName = fileName;
        metadataNet.serverUrl = serverUrl;
        metadataNet.session = session;
        metadataNet.taskStatus = k_taskStatusResume;
        
        if (assetsFull) {
            [metadataNetFull addObject:metadataNet];
        } else {            
            NCRequestAsset *requestAsset = [NCRequestAsset new];
            requestAsset.delegate = self;
            
            [requestAsset writeAssetToSandboxFileName:metadataNet.fileName assetLocalIdentifier:metadataNet.assetLocalIdentifier selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorCode:0 metadataNet:metadataNet serverUrl:serverUrl activeUrl:app.activeUrl directoryUser:app.directoryUser cryptated:NO session:metadataNet.session taskStatus:0 delegate:nil];
        }
    }
    
    // Insert all assets (Full) in TableAutoUpload
    if (assetsFull && [metadataNetFull count] > 0) {
        
        [[NCManageDatabase sharedInstance] addAutoUploadWithMetadatasNet:metadataNetFull];
          
        // Update icon badge number
        [app updateApplicationIconBadgeNumber];
    }
    
    // end loading
    [_hud hideHud];
}

- (void)addDatabaseAutoUpload:(CCMetadataNet *)metadataNet assetDate:(NSDate *)assetDate assetMediaType:(PHAssetMediaType)assetMediaType
{
    if ([[NCManageDatabase sharedInstance] addAutoUploadWithMetadataNet:metadataNet]) {
        
        [[NCManageDatabase sharedInstance] addActivityClient:metadataNet.fileName fileID:metadataNet.assetLocalIdentifier action:k_activityDebugActionAutoUpload selector:metadataNet.selector note:[NSString stringWithFormat:@"Add Auto Upload, Asset Data: %@", [NSDateFormatter localizedStringFromDate:assetDate dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle]] type:k_activityTypeInfo verbose:k_activityVerboseHigh activeUrl:app.activeUrl];
        
    } else {
        
        [[NCManageDatabase sharedInstance] addActivityClient:metadataNet.fileName fileID:metadataNet.assetLocalIdentifier action:k_activityDebugActionAutoUpload selector:metadataNet.selector note:[NSString stringWithFormat:@"Add Auto Upload [File already present in Table autoUpload], Asset Data: %@", [NSDateFormatter localizedStringFromDate:assetDate dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle]] type:k_activityTypeInfo verbose:k_activityVerboseHigh activeUrl:app.activeUrl];
    }
    
    // Update Camera Auto Upload data
    if ([metadataNet.selector isEqualToString:selectorUploadAutoUpload])
        [[NCManageDatabase sharedInstance] setAccountAutoUploadDateAssetType:assetMediaType assetDate:assetDate];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update icon badge number
        [app updateApplicationIconBadgeNumber];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Load Auto Upload ====
#pragma --------------------------------------------------------------------------------------------

- (void)loadAutoUpload:(NSNumber *)maxConcurrent
{
    CCMetadataNet *metadataNet;
    PHFetchResult *result;
    
    NSInteger maxConcurrentUpload = [maxConcurrent integerValue];
    NSInteger counterUpload = [app getNumberUploadInQueues] + [app getNumberUploadInQueuesWWan] + [[[NCManageDatabase sharedInstance] getLockAutoUpload] count];
    
    // ------------------------- <selector Auto Upload> -------------------------
    
    while (counterUpload < maxConcurrentUpload) {
        
        metadataNet = [[NCManageDatabase sharedInstance] getAutoUploadWithSelector:selectorUploadAutoUpload];
        if (metadataNet)
            result = [PHAsset fetchAssetsWithLocalIdentifiers:@[metadataNet.assetLocalIdentifier] options:nil];
        else
            break;
        
        if (result.count > 0) {
            
            [[CCNetworking sharedNetworking] uploadFileFromAssetLocalIdentifier:metadataNet.assetLocalIdentifier fileName:metadataNet.fileName serverUrl:metadataNet.serverUrl cryptated:metadataNet.cryptated session:metadataNet.session taskStatus:metadataNet.taskStatus selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorCode:metadataNet.errorCode delegate:app.activeMain];
            
        } else {
            
            [[NCManageDatabase sharedInstance] addActivityClient:metadataNet.fileName fileID:metadataNet.assetLocalIdentifier action:k_activityDebugActionUpload selector:selectorUploadAutoUploadAll note:@"Internal error image/video not found [0]" type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:app.activeUrl];
            
            [[NCManageDatabase sharedInstance] deleteAutoUploadWithAssetLocalIdentifier:metadataNet.assetLocalIdentifier];
        }
        
        counterUpload = [app getNumberUploadInQueues] + [app getNumberUploadInQueuesWWan] + [[[NCManageDatabase sharedInstance] getLockAutoUpload] count];
    }
    
    // ------------------------- <selector Auto Upload All> ----------------------
    
    // Verify num error MAX 10 after STOP
    NSArray *metadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND sessionSelector = %@ AND (sessionTaskIdentifier = %i OR sessionTaskIdentifierPlist = %i)", app.activeAccount, selectorUploadAutoUploadAll, k_taskIdentifierError, k_taskIdentifierError] sorted:nil ascending:NO];
    
    NSInteger errorCount = [metadatas count];
    
    if (errorCount >= 10) {
        
        [app messageNotification:@"_error_" description:@"_too_errors_automatic_all_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
        return;
    }
    
    while (counterUpload < maxConcurrentUpload) {
        
        metadataNet =  [[NCManageDatabase sharedInstance] getAutoUploadWithSelector:selectorUploadAutoUploadAll];
        if (metadataNet)
            result = [PHAsset fetchAssetsWithLocalIdentifiers:@[metadataNet.assetLocalIdentifier] options:nil];
        else
            break;
            
        if (result.count > 0) {
            
            [[CCNetworking sharedNetworking] uploadFileFromAssetLocalIdentifier:metadataNet.assetLocalIdentifier fileName:metadataNet.fileName serverUrl:metadataNet.serverUrl cryptated:metadataNet.cryptated session:metadataNet.session taskStatus:metadataNet.taskStatus selector:metadataNet.selector selectorPost:metadataNet.selectorPost errorCode:metadataNet.errorCode delegate:app.activeMain];
                            
        } else {
            
            [[NCManageDatabase sharedInstance] addActivityClient:metadataNet.fileName fileID:metadataNet.assetLocalIdentifier action:k_activityDebugActionUpload selector:selectorUploadAutoUploadAll note:@"Internal error image/video not found [0]" type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:app.activeUrl];
            
            [[NCManageDatabase sharedInstance] deleteAutoUploadWithAssetLocalIdentifier:metadataNet.assetLocalIdentifier];
        }
        
        counterUpload = [app getNumberUploadInQueues] + [app getNumberUploadInQueuesWWan] + [[[NCManageDatabase sharedInstance] getLockAutoUpload] count];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Create Folder SubFolder Auto Upload Folder Photos ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)createFolderSubFolderAutoUploadFolderPhotos:(NSString *)folderPhotos useSubFolder:(BOOL)useSubFolder assets:(NSArray *)assets selector:(NSString *)selector
{
    OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:nil metadataNet:nil withUser:app.activeUser withPassword:app.activePassword withUrl:app.activeUrl isCryptoCloudMode:NO];
    
    if ([ocNetworking automaticCreateFolderSync:folderPhotos]) {
        
        (void)[[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:folderPhotos permissions:@""];
        
    } else {
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:folderPhotos fileID:@"" action:k_activityDebugActionAutoUpload selector:selector note:NSLocalizedStringFromTable(@"_not_possible_create_folder_", @"Error", nil) type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:app.activeUrl];
        
        [app messageNotification:@"_error_" description:@"_error_createsubfolders_upload_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];

        return false;
    }
    
    // Create if request the subfolders
    if (useSubFolder) {
        
        for (NSString *dateSubFolder in [CCUtility createNameSubFolder:assets]) {
            
            if ([ocNetworking automaticCreateFolderSync:[NSString stringWithFormat:@"%@/%@", folderPhotos, dateSubFolder]]) {
                
                (void)[[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:[NSString stringWithFormat:@"%@/%@", folderPhotos, dateSubFolder] permissions:@""];
                
            } else {
                
                // Activity
                [[NCManageDatabase sharedInstance] addActivityClient:[NSString stringWithFormat:@"%@/%@", folderPhotos, dateSubFolder] fileID:@"" action:k_activityDebugActionAutoUpload selector:selector note:NSLocalizedString(@"_error_createsubfolders_upload_",nil) type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:app.activeUrl];
                
                [app messageNotification:@"_error_" description:@"_error_createsubfolders_upload_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];

                return false;
            }
        }
    }
    
    return true;
}


@end
