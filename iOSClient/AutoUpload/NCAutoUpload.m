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
#import "CCHud.h"

#pragma GCC diagnostic ignored "-Wundeclared-selector"

@interface NCAutoUpload ()
{
    AppDelegate *appDelegate;
    CCHud *_hud;
    BOOL endForAssetToUpload;
}
@end

@implementation NCAutoUpload

+ (NCAutoUpload *)shared {
    
    static NCAutoUpload *shared;
    
    @synchronized(self)
    {
        if (!shared) {
            
            shared = [NCAutoUpload new];
            shared->appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        }
        return shared;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === initStateAutoUpload ===
#pragma --------------------------------------------------------------------------------------------

- (void)initStateAutoUpload
{
    tableAccount *account = [[NCManageDatabase shared] getAccountActive];
    
    if (account.autoUpload) {
        
        [self setupAutoUpload];
        
        if (account.autoUploadBackground) {
         
            [self checkIfLocationIsEnabled];
        }
        
    } else {
        
        [[CCManageLocation shared] stopSignificantChangeUpdates];
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
        
        tableAccount *account = [[NCManageDatabase shared] getAccountActive];

        if (account.autoUpload == YES)
            [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUpload" state:NO];
        
        [[CCManageLocation shared] stopSignificantChangeUpdates];
        
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
        
        tableAccount *account = [[NCManageDatabase shared] getAccountActive];

        if (account.autoUpload == YES)
            [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUpload" state:NO];
        
        [[CCManageLocation shared] stopSignificantChangeUpdates];
        
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
    tableAccount *account = [[NCManageDatabase shared] getAccountActive];
    
    [CCManageLocation shared].delegate = self;
    
    if ([CLLocationManager locationServicesEnabled]) {
        
        [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Check if location is enabled: authorizationStatus: %d", [CLLocationManager authorizationStatus]]];
        
        if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways) {
            
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined ) {
                
                [[NCCommunicationCommon shared] writeLog:@"Check if location is enabled: Location services not determined"];
                [[CCManageLocation shared] startSignificantChangeUpdates];
                
            } else {
                
                if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
                    
                    if (account.autoUploadBackground == YES)
                        [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
                    
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
                    [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadBackground" state:YES];
                
                [[CCManageLocation shared] startSignificantChangeUpdates];
                
            } else {
                
                if (account.autoUploadBackground == YES)
                    [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
                
                [[CCManageLocation shared] stopSignificantChangeUpdates];
                
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil) message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                
                [alertController addAction:okAction];
                [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
            }
        }
        
    } else {
        
        if (account.autoUploadBackground == YES)
            [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
        
        [[CCManageLocation shared] stopSignificantChangeUpdates];
        
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
    
    tableAccount *tableAccount = [[NCManageDatabase shared] getAccountActive];
    return tableAccount.autoUploadBackground;
}

- (void)statusAuthorizationLocationChanged
{
    tableAccount *account = [[NCManageDatabase shared] getAccountActive];
    
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined){
        
        if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
            
            if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
                
                if ([CCManageLocation shared].firstChangeAuthorizationDone) {
                    
                    if (account.autoUploadBackground == YES)
                        [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
                    
                    [[CCManageLocation shared] stopSignificantChangeUpdates];
                }
                
            } else {
                
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil) message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                
                [alertController addAction:okAction];
                [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertController animated:YES completion:nil];
            }
            
        } else if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined){
            
            if (account.autoUploadBackground == YES) {
                
                [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
                
                [[CCManageLocation shared] stopSignificantChangeUpdates];
                
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
        
        if (![CCManageLocation shared].firstChangeAuthorizationDone) {
            
            [CCManageLocation shared].firstChangeAuthorizationDone = YES;
        }
    }
}

- (void)changedLocation
{
    // Only in background
    tableAccount *account = [[NCManageDatabase shared] getAccountActive];
    
    if (account.autoUpload && account.autoUploadBackground && [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        
        if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
            
            //check location
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
                
                [[NCCommunicationCommon shared] writeLog:@"Changed Location call upload new assets"];
                [self uploadNewAssets];
            }
            
        } else {
            
            if (account.autoUpload == YES)
                [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUpload" state:NO];
            
            if (account.autoUploadBackground == YES)
                [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
            
            [[CCManageLocation shared] stopSignificantChangeUpdates];
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
    if (!appDelegate.account) return;
    
    tableAccount *tableAccount = [[NCManageDatabase shared] getAccountActive];
    if (tableAccount == nil) {
        return;
    }
    
    NSMutableArray *metadataFull = [NSMutableArray new];
    NSString *autoUploadPath = [[NCManageDatabase shared] getAccountAutoUploadPathWithUrlBase:appDelegate.urlBase account:appDelegate.account];
    NSString *serverUrl;
    __block NSInteger counterLivePhoto = 0;

    // Check Asset : NEW or FULL
    NSArray *newAssetToUpload = [self getCameraRollAssets:tableAccount selector:selector alignPhotoLibrary:NO];
    
    // News Assets ? if no verify if blocked Table Auto Upload -> Autostart
    if (newAssetToUpload == nil || [newAssetToUpload count] == 0) {
        
        [[NCCommunicationCommon shared] writeLog:@"Automatic upload, no new assets found"];
        return;
        
    } else {
        
        [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Automatic upload, new %lu assets found", (unsigned long)[newAssetToUpload count]]];
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
    
    endForAssetToUpload = false;
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
        
        tableMetadata *metadata = [[NCManageDatabase shared] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileNameView == %@", appDelegate.account, serverUrl, fileName]];
        if (metadata) {
            
            if ([selector isEqualToString:selectorUploadAutoUpload]) {
                [[NCManageDatabase shared] addPhotoLibrary:@[asset] account:appDelegate.account];
            }
            
        } else {
        
            /* INSERT METADATA FOR UPLOAD */
            tableMetadata *metadataForUpload = [[NCManageDatabase shared] createMetadataWithAccount:appDelegate.account fileName:fileName ocId:[[NSUUID UUID] UUIDString] serverUrl:serverUrl urlBase:appDelegate.urlBase url:@"" contentType:@"" livePhoto:livePhoto];
            
            metadataForUpload.assetLocalIdentifier = asset.localIdentifier;
            metadataForUpload.livePhoto = livePhoto;
            metadataForUpload.session = session;
            metadataForUpload.sessionSelector = selector;
            metadataForUpload.size = [[NCUtilityFileSystem shared] getFileSizeWithAsset:asset];
            metadataForUpload.status = k_metadataStatusWaitUpload;
            if (assetMediaType == PHAssetMediaTypeVideo) {
                metadataForUpload.typeFile = k_metadataTypeFile_video;
            } else if (assetMediaType == PHAssetMediaTypeImage) {
                metadataForUpload.typeFile = k_metadataTypeFile_image;
            }
            
            if ([selector isEqualToString:selectorUploadAutoUpload]) {
               
                [[NCManageDatabase shared] addMetadataForAutoUpload:metadataForUpload];
                [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Automatic upload added %@ (%lu bytes) with Identifier %@", metadata.fileNameView, (unsigned long)metadata.size, metadata.assetLocalIdentifier]];
                [[NCManageDatabase shared] addPhotoLibrary:@[asset] account:appDelegate.account];
                
            } else if ([selector isEqualToString:selectorUploadAutoUploadAll]) {
                
                [metadataFull addObject:metadataForUpload];
            }

            /* INSERT METADATA MOV LIVE PHOTO FOR UPLOAD */
            if (livePhoto) {
                
                counterLivePhoto++;
                NSString *fileNameMove = [NSString stringWithFormat:@"%@.mov", fileName.stringByDeletingPathExtension];
                NSString *ocId = [[NSUUID UUID] UUIDString];
                NSString *filePath = [CCUtility getDirectoryProviderStorageOcId:ocId fileNameView:fileNameMove];
                                
                [CCUtility extractLivePhotoAsset:asset filePath:filePath withCompletion:^(NSURL *url) {
                    if (url != nil) {
                        
                        unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil] fileSize];
                        tableMetadata *metadataMOVForUpload = [[NCManageDatabase shared] createMetadataWithAccount:appDelegate.account fileName:fileNameMove ocId:ocId serverUrl:serverUrl urlBase:appDelegate.urlBase url:@"" contentType:@"" livePhoto:livePhoto];
                       
                        metadataMOVForUpload.livePhoto = true;
                        metadataMOVForUpload.session = session;
                        metadataMOVForUpload.sessionSelector = selector;
                        metadataMOVForUpload.size = fileSize;
                        metadataMOVForUpload.status = k_metadataStatusWaitUpload;
                        metadataMOVForUpload.typeFile = k_metadataTypeFile_video;

                        if ([selector isEqualToString:selectorUploadAutoUpload]) {
                            
                            [[NCManageDatabase shared] addMetadataForAutoUpload:metadataMOVForUpload];
                            [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Automatic upload added Live Photo %@ (%llu bytes)", fileNameMove, fileSize]];
                            
                        } else if ([selector isEqualToString:selectorUploadAutoUploadAll]) {
                            
                            [metadataFull addObject:metadataMOVForUpload];
                        }
                    }
                    counterLivePhoto--;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (endForAssetToUpload && counterLivePhoto == 0 && [selector isEqualToString:selectorUploadAutoUploadAll]) {
                            [[NCManageDatabase shared] addMetadatas:metadataFull];
                            [_hud hideHud];
                        }
                    });
                }];
            }
        }
    }
    endForAssetToUpload = true;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (counterLivePhoto == 0 && [selector isEqualToString:selectorUploadAutoUploadAll]) {
            [[NCManageDatabase shared] addMetadatas:metadataFull];
            [_hud hideHud];
        }
    });
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

                NSArray *idsAsset = [[NCManageDatabase shared] getPhotoLibraryIdAssetWithImage:account.autoUploadImage video:account.autoUploadVideo account:account.account];
                
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
    tableAccount *account = [[NCManageDatabase shared] getAccountActive];

    NSArray *assets = [self getCameraRollAssets:account selector:selectorUploadAutoUploadAll alignPhotoLibrary:YES];
   
    [[NCManageDatabase shared] clearTable:[tablePhotoLibrary class] account:appDelegate.account];
    if (assets != nil) {
        (void)[[NCManageDatabase shared] addPhotoLibrary:assets account:account.account];

        [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Align Photo Library %lu", (unsigned long)[assets count]]];
    }
}

@end
