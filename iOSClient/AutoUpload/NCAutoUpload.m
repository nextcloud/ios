//
//  NCAutoUpload.m
//  Nextcloud
//
//  Created by Marino Faggiana on 07/06/17.
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
        
        [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Check if location is enabled: authorizationStatus: %d", [CLLocationManager authorizationStatus]]];
        
        if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways) {
            
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined ) {
                
                [[NCCommunicationCommon shared] writeLog:@"Check if location is enabled: Location services not determined"];
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
                
                [[NCCommunicationCommon shared] writeLog:@"Changed Location call upload new assets"];
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
    if (!appDelegate.account || appDelegate.maintenanceMode) {
         return;
    }
    
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    if (tableAccount == nil) {
        return;
    }
    
    NSMutableArray *metadataFull = [NSMutableArray new];
    NSString *autoUploadPath = [[NCManageDatabase sharedInstance] getAccountAutoUploadPathWithUrlBase:appDelegate.urlBase account:appDelegate.account];
    NSString *serverUrl;
    
    // Check Asset : NEW or FULL
    NSArray *newAssetToUpload = [self getCameraRollAssets:tableAccount selector:selector alignPhotoLibrary:NO];
    
    // News Assets ? if no verify if blocked Table Auto Upload -> Autostart
    if (newAssetToUpload == nil || [newAssetToUpload count] == 0) {
        
        [[NCCommunicationCommon shared] writeLog:@"Auto upload, no new assets found"];
        return;
        
    } else {
        
        [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Auto upload, new %lu assets found", (unsigned long)[newAssetToUpload count]]];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([selector isEqualToString:selectorUploadAutoUploadAll]) {
            if (!_hud)
                _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
        
            [[NCContentPresenter shared] messageNotification:@"_attention_" description:@"_create_full_upload_" delay:k_dismissAfterSecondLong type:messageTypeInfo errorCode:0 forced:true];
            [_hud visibleHudTitle:NSLocalizedString(@"_wait_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
        }
    });
    
    // Create the folder for auto upload & if request the subfolders
    if ([[NCNetworking shared] createFolderWithAssets:newAssetToUpload selector:selector useSubFolder:tableAccount.autoUploadCreateSubfolder account:appDelegate.account urlBase:appDelegate.urlBase]) {
        if ([selector isEqualToString:selectorUploadAutoUploadAll]) {        
            [[NCContentPresenter shared] messageNotification:@"_error_" description:@"_error_createsubfolders_upload_" delay:k_dismissAfterSecond type:messageTypeError errorCode:k_CCErrorInternalError forced:true];
            dispatch_async(dispatch_get_main_queue(), ^{
                [_hud hideHud];
            });
        }
        
        return;
    }
    
    for (PHAsset *asset in newAssetToUpload) {
        
        BOOL livePhoto = false;
        NSDate *assetDate = asset.creationDate;
        PHAssetMediaType assetMediaType = asset.mediaType;
        NSString *session;
        NSString *fileName = [CCUtility createFileName:[asset valueForKey:@"filename"] fileDate:asset.creationDate fileType:asset.mediaType keyFileName:k_keyFileNameAutoUploadMask keyFileNameType:k_keyFileNameAutoUploadType keyFileNameOriginal:k_keyFileNameOriginalAutoUpload];

        // Detect LivePhoto Upload
        if ((asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive || asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive+PHAssetMediaSubtypePhotoHDR) && CCUtility.getLivePhoto) {
            livePhoto = true;
        }
        
        // Select type of session
        
        if ([selector isEqualToString:selectorUploadAutoUploadAll]) {
            session = NCCommunicationCommon.shared.sessionIdentifierUpload;
        } else {
            if (assetMediaType == PHAssetMediaTypeImage && tableAccount.autoUploadWWAnPhoto == NO) session = NCNetworking.shared.sessionIdentifierBackground;
            else if (assetMediaType == PHAssetMediaTypeVideo && tableAccount.autoUploadWWAnVideo == NO) session = NCNetworking.shared.sessionIdentifierBackground;
            else if (assetMediaType == PHAssetMediaTypeImage && tableAccount.autoUploadWWAnPhoto) session = NCNetworking.shared.sessionIdentifierBackgroundWWan;
            else if (assetMediaType == PHAssetMediaTypeVideo && tableAccount.autoUploadWWAnVideo) session = NCNetworking.shared.sessionIdentifierBackgroundWWan;
            else session = NCNetworking.shared.sessionIdentifierBackground;
        }
        
        NSDateFormatter *formatter = [NSDateFormatter new];
        
        [formatter setDateFormat:@"yyyy"];
        NSString *yearString = [formatter stringFromDate:assetDate];
        
        [formatter setDateFormat:@"MM"];
        NSString *monthString = [formatter stringFromDate:assetDate];
        
        if (tableAccount.autoUploadCreateSubfolder)
            serverUrl = [NSString stringWithFormat:@"%@/%@/%@", autoUploadPath, yearString, monthString];
        else
            serverUrl = autoUploadPath;
        
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileNameView == %@", appDelegate.account, serverUrl, fileName]];
        if (!metadata) {
        
            tableMetadata *metadataForUpload = [[NCManageDatabase sharedInstance] createMetadataWithAccount:appDelegate.account fileName:fileName ocId:[[NSUUID UUID] UUIDString] serverUrl:serverUrl urlBase:appDelegate.urlBase url:@"" contentType:@"" livePhoto:livePhoto];
            
            metadataForUpload.assetLocalIdentifier = asset.localIdentifier;
            metadataForUpload.session = session;
            metadataForUpload.sessionSelector = selector;
            metadataForUpload.size = [[NCUtilityFileSystem shared] getFileSizeWithAsset:asset];
            metadataForUpload.status = k_metadataStatusWaitUpload;
            if (assetMediaType == PHAssetMediaTypeVideo) {
                metadataForUpload.typeFile = k_metadataTypeFile_video;
            } else if (assetMediaType == PHAssetMediaTypeImage) {
                metadataForUpload.typeFile = k_metadataTypeFile_image;
            }

            // Add Medtadata MOV LIVE PHOTO for upload
            if (livePhoto) {
                
                NSString *fileNameMove = [NSString stringWithFormat:@"%@.mov", fileName.stringByDeletingPathExtension];
                NSString *ocId = [[NSUUID UUID] UUIDString];
                NSString *filePath = [CCUtility getDirectoryProviderStorageOcId:ocId fileNameView:fileNameMove];
                
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                
                [CCUtility extractLivePhotoAsset:asset filePath:filePath withCompletion:^(NSURL *url) {
                    if (url != nil) {
                        unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil] fileSize];
                        
                        tableMetadata *metadataMOVForUpload = [[NCManageDatabase sharedInstance] createMetadataWithAccount:appDelegate.account fileName:fileNameMove ocId:ocId serverUrl:serverUrl urlBase:appDelegate.urlBase url:@"" contentType:@"" livePhoto:livePhoto];
                        
                        metadataForUpload.livePhoto = true;
                        metadataMOVForUpload.livePhoto = true;
                        
                        metadataMOVForUpload.session = session;
                        metadataMOVForUpload.sessionSelector = selector;
                        metadataMOVForUpload.size = fileSize;
                        metadataMOVForUpload.status = k_metadataStatusWaitUpload;
                        metadataMOVForUpload.typeFile = k_metadataTypeFile_video;

                        [metadataFull addObject:metadataMOVForUpload];
                                                
                        // Update database Auto Upload
                        if ([selector isEqualToString:selectorUploadAutoUpload])
                            [[NCManageDatabase sharedInstance] addMetadataForAutoUpload:metadataMOVForUpload];
                    }
                    
                    dispatch_semaphore_signal(semaphore);
                }];
                
                while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER))
                       [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:30]];
            }
            
            [metadataFull addObject:metadataForUpload];
                       
            // Update database Auto Upload
            if ([selector isEqualToString:selectorUploadAutoUpload]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self addQueueUploadAndPhotoLibrary:metadataForUpload asset:asset];
                });
            }
        }
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        // Insert all assets (Full) in tableQueueUpload
        if ([selector isEqualToString:selectorUploadAutoUploadAll] && [metadataFull count] > 0) {
            [[NCManageDatabase sharedInstance] addMetadatas:metadataFull];
        }
        // end loadingcand reload
        [_hud hideHud];
        // START
        [[appDelegate networkingAutoUpload] startProcess];
    });
}

- (void)addQueueUploadAndPhotoLibrary:(tableMetadata *)metadata asset:(PHAsset *)asset
{
    @synchronized(self) {
        
        [[NCManageDatabase sharedInstance] addMetadataForAutoUpload:metadata];
        
        // Add asset in table Photo Library
        if ([metadata.sessionSelector isEqualToString:selectorUploadAutoUpload]) {
            (void)[[NCManageDatabase sharedInstance] addPhotoLibrary:@[asset] account:appDelegate.account];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== get Camera Roll new Asset ====
#pragma --------------------------------------------------------------------------------------------

- (NSArray *)getCameraRollAssets:(tableAccount *)account selector:(NSString *)selector alignPhotoLibrary:(BOOL)alignPhotoLibrary
{
    @synchronized(self) {
        
        if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
            
            PHFetchResult *result = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];
            if (result.count == 0) {
                return nil;
            }
            
            NSPredicate *predicateImage = [NSPredicate predicateWithFormat:@"mediaType == %i", PHAssetMediaTypeImage];
            NSPredicate *predicateVideo = [NSPredicate predicateWithFormat:@"mediaType == %i", PHAssetMediaTypeVideo];
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

                NSArray *idsAsset = [[NCManageDatabase sharedInstance] getPhotoLibraryIdAssetWithImage:account.autoUploadImage video:account.autoUploadVideo account:account.account];
                
                for (PHAsset *asset in assets) {
                    
                    (asset.creationDate != nil) ? (creationDate = [NSString stringWithFormat:@"%@", asset.creationDate]) : (creationDate = @"");
                    
                    idAsset = [NSString stringWithFormat:@"%@%@%@", account.account, asset.localIdentifier, creationDate];
                    
                    if (![idsAsset containsObject: idAsset])
                        [newAssets addObject:asset];
                }
                
                return newAssets;
                
            } else {
            
                return (NSArray *)[assets copy];
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

    NSArray *assets = [self getCameraRollAssets:account selector:selectorUploadAutoUploadAll alignPhotoLibrary:YES];
   
    [[NCManageDatabase sharedInstance] clearTable:[tablePhotoLibrary class] account:appDelegate.account];
    if (assets != nil) {
        (void)[[NCManageDatabase sharedInstance] addPhotoLibrary:assets account:account.account];

        [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Align Photo Library %lu", (unsigned long)[assets count]]];
    }
}

@end
