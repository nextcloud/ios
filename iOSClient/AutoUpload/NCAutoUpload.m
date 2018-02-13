//
//  NCAutoUpload.m
//  Nextcloud iOS
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

#pragma GCC diagnostic ignored "-Wundeclared-selector"

@interface NCAutoUpload ()
{
    AppDelegate *appDelegate;
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
            sharedInstance->appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        }
        return sharedInstance;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === initStateAutoUpload ===
#pragma --------------------------------------------------------------------------------------------

- (void)initStateAutoUpload
{
    tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if (account.autoUpload) {
        
        [self setupAutoUpload];
        
        if (account.autoUploadBackground) {
         
            [self checkIfLocationIsEnabled];
        }
        
    } else {
        
        [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Camera Upload & Full ===
#pragma --------------------------------------------------------------------------------------------

- (void)setupAutoUpload
{
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
        
        [self performSelectorOnMainThread:@selector(uploadNewAssets) withObject:nil waitUntilDone:NO];
        
    } else {
        
        tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];

        if (account.autoUpload == YES)
            [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUpload" state:NO];
        
        [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil) message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
        return;        
    }
}

- (void)setupAutoUploadFull
{
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
        
        [self performSelectorOnMainThread:@selector(uploadFullAssets) withObject:nil waitUntilDone:NO];
        
    } else {
        
        tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];

        if (account.autoUpload == YES)
            [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUpload" state:NO];
        
        [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil) message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Location ===
#pragma --------------------------------------------------------------------------------------------

- (BOOL)checkIfLocationIsEnabled
{
    tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];
    
    [CCManageLocation sharedInstance].delegate = self;
    
    if ([CLLocationManager locationServicesEnabled]) {
        
        NSLog(@"[LOG] checkIfLocationIsEnabled : authorizationStatus: %d", [CLLocationManager authorizationStatus]);
        
        if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways) {
            
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined ) {
                
                NSLog(@"[LOG] checkIfLocationIsEnabled : Location services not determined");
                [[CCManageLocation sharedInstance] startSignificantChangeUpdates];
                
            } else {
                
                if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
                    
                    if (account.autoUploadBackground == YES)
                        [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
                    
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_location_not_enabled_", nil) message:NSLocalizedString(@"_location_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                    
                    [alertController addAction:okAction];
                    [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
                    
                } else {
                    
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil) message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                    
                    [alertController addAction:okAction];
                    [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
                }
            }
            
        } else {
            
            if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
                
                if (account.autoUploadBackground == NO)
                    [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadBackground" state:YES];
                
                [[CCManageLocation sharedInstance] startSignificantChangeUpdates];
                
            } else {
                
                if (account.autoUploadBackground == YES)
                    [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
                
                [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
                
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil) message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                
                [alertController addAction:okAction];
                [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
            }
        }
        
    } else {
        
        if (account.autoUploadBackground == YES)
            [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
        
        [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
        
        if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_location_not_enabled_", nil) message:NSLocalizedString(@"_location_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
            
            [alertController addAction:okAction];
            [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
            
        } else {
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_access_photo_location_not_enabled_", nil) message:NSLocalizedString(@"_access_photo_location_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
            
            [alertController addAction:okAction];
            [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
        }
    }
    
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    return tableAccount.autoUploadBackground;
}

- (void)statusAuthorizationLocationChanged
{
    tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined){
        
        if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
            
            if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
                
                if ([CCManageLocation sharedInstance].firstChangeAuthorizationDone) {
                    
                    if (account.autoUploadBackground == YES)
                        [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
                    
                    [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
                }
                
            } else {
                
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil) message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                
                [alertController addAction:okAction];
                [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
            }
            
        } else if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined){
            
            if (account.autoUploadBackground == YES) {
                
                [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
                
                [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
                
                if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
                    
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_location_not_enabled_", nil) message:NSLocalizedString(@"_location_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                    
                    [alertController addAction:okAction];
                    [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
                    
                } else {
                    
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_access_photo_location_not_enabled_", nil) message:NSLocalizedString(@"_access_photo_location_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                    
                    [alertController addAction:okAction];
                    [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
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
    tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if (account.autoUpload && account.autoUploadBackground && [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        
        if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
            
            //check location
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
                
                NSLog(@"[LOG] Changed Location call uploadNewAssets");
                
                [self uploadNewAssets];
            }
            
        } else {
            
            if (account.autoUpload == YES)
                [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUpload" state:NO];
            
            if (account.autoUploadBackground == YES)
                [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
            
            [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Upload Assets : NEW & FULL ====
#pragma --------------------------------------------------------------------------------------------

- (void)uploadNewAssets
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self uploadAssetsNewAndFull:selectorUploadAutoUpload];
    });
}

- (void)uploadFullAssets
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self uploadAssetsNewAndFull:selectorUploadAutoUploadAll];
    });
}

- (void)uploadAssetsNewAndFull:(NSString *)selector
{
     if (!appDelegate.activeAccount || appDelegate.maintenanceMode)
         return;
    
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    NSMutableArray *metadataNetFull = [NSMutableArray new];
    NSString *autoUploadPath = [[NCManageDatabase sharedInstance] getAccountAutoUploadPath:appDelegate.activeUrl];

    // Check Asset : NEW or FULL
    PHFetchResult *newAssetToUpload = [self getCameraRollAssets:tableAccount selector:selector alignPhotoLibrary:NO];
    
    // News Assets ? if no verify if blocked Table Auto Upload -> Autostart
    if ([newAssetToUpload count] == 0) {
        
        NSLog(@"[LOG] Auto upload, no new asset found");
        return;
        
    } else {
        
        NSLog(@"[LOG] Auto upload, new %lu asset found", (unsigned long)[newAssetToUpload count]);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([selector isEqualToString:selectorUploadAutoUploadAll]) {
            if (!_hud)
                _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
        
            [_hud visibleHudTitle:NSLocalizedString(@"_create_full_upload_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
        }
    });
    
    // Create the folder for Photos & if request the subfolders
    if(![[NCAutoUpload sharedInstance] createFolderSubFolderAutoUploadFolderPhotos:autoUploadPath useSubFolder:tableAccount.autoUploadCreateSubfolder assets:newAssetToUpload selector:selector]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // end loading
            [_hud hideHud];
        });
        return;
    }
    
    for (PHAsset *asset in newAssetToUpload) {
        
        NSString *serverUrl;
        NSDate *assetDate = asset.creationDate;
        PHAssetMediaType assetMediaType = asset.mediaType;
        NSString *session;
        NSString *fileName = [CCUtility createFileName:[asset valueForKey:@"filename"] fileDate:asset.creationDate fileType:asset.mediaType keyFileName:k_keyFileNameAutoUploadMask keyFileNameType:k_keyFileNameAutoUploadType];

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
        
        if (tableAccount.autoUploadCreateSubfolder)
            serverUrl = [NSString stringWithFormat:@"%@/%@/%@", autoUploadPath, yearString, monthString];
        else
            serverUrl = autoUploadPath;
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
        
        metadataNet.assetLocalIdentifier = asset.localIdentifier;
        if ([selector isEqualToString:selectorUploadAutoUploadAll]) {
            // Option 
            if ([[NCBrandOptions sharedInstance] use_storeLocalAutoUploadAll] == true)
                metadataNet.selectorPost = nil;
            else
                metadataNet.selectorPost = selectorUploadRemovePhoto;
        } else {
            metadataNet.selectorPost = nil;
        }
        
        metadataNet.fileName = fileName;
        metadataNet.selector = selector;
        metadataNet.serverUrl = serverUrl;
        metadataNet.session = session;
        metadataNet.taskStatus = k_taskStatusResume;
        
        [metadataNetFull addObject:metadataNet];
        
        // Update database Auto Upload
        if ([selector isEqualToString:selectorUploadAutoUpload])
            [self addQueueUploadAndPhotoLibrary:metadataNet asset:asset];
    }
    
    // Insert all assets (Full) in tableQueueUpload
    if ([selector isEqualToString:selectorUploadAutoUploadAll] && [metadataNetFull count] > 0) {
    
        [[NCManageDatabase sharedInstance] addQueueUploadWithMetadatasNet:metadataNetFull];
        
        // Update icon badge number
        dispatch_async(dispatch_get_main_queue(), ^{
            [appDelegate updateApplicationIconBadgeNumber];
        });
    }
    
    // end loading
    dispatch_async(dispatch_get_main_queue(), ^{
        [_hud hideHud];
    });
}

- (void)addQueueUploadAndPhotoLibrary:(CCMetadataNet *)metadataNet asset:(PHAsset *)asset
{
    @synchronized(self) {
        
        if ([[NCManageDatabase sharedInstance] addQueueUploadWithMetadataNet:metadataNet]) {
        
            [[NCManageDatabase sharedInstance] addActivityClient:metadataNet.fileNameView fileID:metadataNet.assetLocalIdentifier action:k_activityDebugActionAutoUpload selector:metadataNet.selector note:@"Add Auto Upload, add new asset" type:k_activityTypeInfo verbose:k_activityVerboseHigh activeUrl:appDelegate.activeUrl];
        
        } else {
    
            [[NCManageDatabase sharedInstance] addActivityClient:metadataNet.fileNameView fileID:metadataNet.assetLocalIdentifier action:k_activityDebugActionAutoUpload selector:metadataNet.selector note:@"Add Auto Upload, asset already present or db in write transaction" type:k_activityTypeInfo verbose:k_activityVerboseHigh activeUrl:appDelegate.activeUrl];
        }
    
        // Add asset in table Photo Library
        if ([metadataNet.selector isEqualToString:selectorUploadAutoUpload]) {
            if (![[NCManageDatabase sharedInstance] addPhotoLibrary:@[asset]]) {
                [[NCManageDatabase sharedInstance] addActivityClient:metadataNet.fileNameView fileID:metadataNet.assetLocalIdentifier action:k_activityDebugActionAutoUpload selector:metadataNet.selector note:@"Add Photo Library, db in write transaction" type:k_activityTypeInfo verbose:k_activityVerboseHigh activeUrl:appDelegate.activeUrl];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Update icon badge number
            [appDelegate updateApplicationIconBadgeNumber];
        });
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Create Folder SubFolder Auto Upload Folder Photos ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)createFolderSubFolderAutoUploadFolderPhotos:(NSString *)folderPhotos useSubFolder:(BOOL)useSubFolder assets:(PHFetchResult *)assets selector:(NSString *)selector
{
    NSString *fileID;
    BOOL encrypted = [CCUtility isFolderEncrypted:folderPhotos account:appDelegate.activeAccount depth:YES];
    
    NSError *error = [[NCNetworkingSync sharedManager] createFolderAutomaticUpload:folderPhotos user:appDelegate.activeUser userID:appDelegate.activeUserID password:appDelegate.activePassword url:appDelegate.activeUrl encrypted:encrypted fileID:&fileID];
    
    if (error == nil) {
        
        tableDirectory *tableDirectory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", appDelegate.activeAccount, folderPhotos]];
        if (!tableDirectory)
            (void)[[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:folderPhotos fileID:fileID permissions:nil encrypted:encrypted];
        
    } else {
        
        // Activity
        [[NCManageDatabase sharedInstance] addActivityClient:folderPhotos fileID:@"" action:k_activityDebugActionAutoUpload selector:selector note:NSLocalizedStringFromTable(@"_not_possible_create_folder_", @"Error", nil) type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:appDelegate.activeUrl];
        
        if ([selector isEqualToString:selectorUploadAutoUploadAll])
            [appDelegate messageNotification:@"_error_" description:@"_error_createsubfolders_upload_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];

        return false;
    }
    
    // Create if request the subfolders
    if (useSubFolder) {
        
        for (NSString *dateSubFolder in [CCUtility createNameSubFolder:assets]) {
            
            error = [[NCNetworkingSync sharedManager] createFolderAutomaticUpload:[NSString stringWithFormat:@"%@/%@", folderPhotos, dateSubFolder] user:appDelegate.activeUser userID:appDelegate.activeUserID password:appDelegate.activePassword url:appDelegate.activeUrl encrypted:encrypted fileID:&fileID];
            
            if ( error == nil) {
                
                (void)[[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:[NSString stringWithFormat:@"%@/%@", folderPhotos, dateSubFolder] fileID:fileID permissions:nil encrypted:encrypted];
                
            } else {
                
                // Activity
                [[NCManageDatabase sharedInstance] addActivityClient:[NSString stringWithFormat:@"%@/%@", folderPhotos, dateSubFolder] fileID:@"" action:k_activityDebugActionAutoUpload selector:selector note:NSLocalizedString(@"_error_createsubfolders_upload_",nil) type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:appDelegate.activeUrl];
                
                if ([selector isEqualToString:selectorUploadAutoUploadAll])
                    [appDelegate messageNotification:@"_error_" description:@"_error_createsubfolders_upload_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];

                return false;
            }
        }
    }
    
    return true;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== get Camera Roll new Asset ====
#pragma --------------------------------------------------------------------------------------------

- (PHFetchResult *)getCameraRollAssets:(tableAccount *)account selector:(NSString *)selector alignPhotoLibrary:(BOOL)alignPhotoLibrary
{
    @synchronized(self) {
        
        if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
            
            PHFetchResult *result = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];
            
            NSPredicate *predicateImage = [NSPredicate predicateWithFormat:@"mediaType = %i", PHAssetMediaTypeImage];
            NSPredicate *predicateVideo = [NSPredicate predicateWithFormat:@"mediaType = %i", PHAssetMediaTypeVideo];
            NSPredicate *predicate;

            NSMutableArray *newAssets =[NSMutableArray new];
            
            if (alignPhotoLibrary || (account.autoUploadImage && account.autoUploadVideo)) {
                
                predicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicateImage, predicateVideo]];
                
            } else if (account.autoUploadImage) {
                
                predicate = predicateImage;
                
            } else if (account.autoUploadVideo) {
                
                predicate = predicateVideo;
                
            } else {
                
                return nil;
            }
            
            PHFetchOptions *fetchOptions = [PHFetchOptions new];
            fetchOptions.predicate = predicate;
            
            PHAssetCollection *collection = result[0];
            
            PHFetchResult *assets = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptions];
            
            if ([selector isEqualToString:selectorUploadAutoUpload]) {
            
                NSString *creationDate;
                NSString *idAsset;

                NSArray *idsAsset = [[NCManageDatabase sharedInstance] getPhotoLibraryIdAssetWithImage:account.autoUploadImage video:account.autoUploadVideo];
                
                for (PHAsset *asset in assets) {
                    
                    (asset.creationDate != nil) ? (creationDate = [NSString stringWithFormat:@"%@", asset.creationDate]) : (creationDate = @"");
                    
                    idAsset = [NSString stringWithFormat:@"%@%@%@", account.account, asset.localIdentifier, creationDate];
                    
                    if (![idsAsset containsObject: idAsset])
                        [newAssets addObject:asset];
                }
                
                return (PHFetchResult *)newAssets;
                
            } else {
            
                return assets;
            }
        }
    }
    
    return nil;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Align Photo Library ====
#pragma --------------------------------------------------------------------------------------------

- (void)alignPhotoLibrary
{
    tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];

    PHFetchResult *assets = [self getCameraRollAssets:account selector:selectorUploadAutoUploadAll alignPhotoLibrary:YES];
        
    [[NCManageDatabase sharedInstance] clearTable:[tablePhotoLibrary class] account:appDelegate.activeAccount];
    (void)[[NCManageDatabase sharedInstance] addPhotoLibrary:(NSArray *)assets];

    NSLog(@"[LOG] Align Photo Library %lu", (unsigned long)[assets count]);
}

@end
