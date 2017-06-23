//
//  NCRequestAsset.m
//  Nextcloud
//
//  Created by Marino Faggiana on 16/06/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "NCRequestAsset.h"
#import "AppDelegate.h"

#import "NCBridgeSwift.h"

@implementation NCRequestAsset

- (void)writeAssetToSandboxFileName:(NSString *)fileName assetLocalIdentifier:(NSString *)assetLocalIdentifier selector:(NSString *)selector selectorPost:(NSString *)selectorPost errorCode:(NSInteger)errorCode metadataNet:(CCMetadataNet *)metadataNet serverUrl:(NSString *)serverUrl activeUrl:(NSString *)activeUrl directoryUser:(NSString *)directoryUser cryptated:(BOOL)cryptated session:(NSString *)session taskStatus:(NSInteger)taskStatus delegate:(id)delegate
{
    PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetLocalIdentifier] options:nil];
    
    if (!result.count) {
        
        [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:assetLocalIdentifier action:k_activityDebugActionUpload selector:selector note:@"Internal error image/video not found" type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:activeUrl];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (delegate)
                if ([delegate respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                    [delegate uploadFileFailure:nil fileID:nil serverUrl:serverUrl selector:selector message:@"Internal error image/video not found" errorCode: k_CCErrorInternalError];
        });
        
        return;
    }

    PHAsset *asset = result[0];
    PHAssetMediaType assetMediaType = asset.mediaType;
    NSDate *modificationDate = asset.modificationDate;
    __block NSError *error = nil;
    
    // VIDEO
    if (assetMediaType == PHAssetMediaTypeVideo) {

        @autoreleasepool {
            
            dispatch_semaphore_t semaphoreGroup = dispatch_semaphore_create(0);

            PHVideoRequestOptions *options = [PHVideoRequestOptions new];
            options.networkAccessAllowed = YES; // iCloud
            
            [[PHImageManager defaultManager] requestPlayerItemForVideo:asset options:options resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, fileName]])
                    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, fileName] error:nil];
                
                _exportSession = [[AVAssetExportSession alloc] initWithAsset:playerItem.asset presetName:AVAssetExportPresetHighestQuality];
                
                if (_exportSession) {
                    
                    _exportSession.outputURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", directoryUser, fileName]];
                    _exportSession.outputFileType = AVFileTypeQuickTimeMovie;
                    
                    [_exportSession exportAsynchronouslyWithCompletionHandler:^{
                        
                        dispatch_semaphore_signal(semaphoreGroup);
                        
                        if (AVAssetExportSessionStatusCompleted == _exportSession.status) {
                            
                            //OK selectorUploadAutoUpload
                            if ([selector isEqualToString:selectorUploadAutoUpload]) {
                                if ([self.delegate respondsToSelector:@selector(addDatabaseAutoUpload:modificationDate:assetMediaType:)])
                                    [self.delegate addDatabaseAutoUpload:metadataNet modificationDate:modificationDate assetMediaType:assetMediaType];
                            } else {
                                if ([self.delegate respondsToSelector:@selector(upload:serverUrl:cryptated:template:onlyPlist:fileNameTemplate:assetLocalIdentifier:session:taskStatus:selector:selectorPost:errorCode:delegate:)])
                                    [self.delegate upload:fileName serverUrl:serverUrl cryptated:cryptated template:NO onlyPlist:NO fileNameTemplate:nil assetLocalIdentifier:assetLocalIdentifier session:session taskStatus:taskStatus selector:selector selectorPost:selectorPost errorCode:errorCode delegate:delegate];
                            }
                            
                        } else if (AVAssetExportSessionStatusFailed == _exportSession.status) {
                            
                            // Delete record on Table Auto Upload
                            if ([selector isEqualToString:selectorUploadAutoUpload] || [selector isEqualToString:selectorUploadAutoUploadAll])
                                [[NCManageDatabase sharedInstance] deleteAutoUploadWithAssetLocalIdentifier:assetLocalIdentifier];
                            
                            // Activity
                            [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:assetLocalIdentifier action:k_activityDebugActionUpload selector:selector note:[NSString stringWithFormat:@"%@ [%@]",NSLocalizedString(@"_read_file_error_", nil), error.description] type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:activeUrl];
                            
                            // Error for uploadFileFailure
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (delegate)
                                    if ([delegate respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                                        [delegate uploadFileFailure:nil fileID:nil serverUrl:serverUrl selector:selector message:@"_read_file_error_" errorCode:[NSError errorWithDomain:@"it.twsweb.cryptocloud" code:kCFURLErrorFileDoesNotExist userInfo:nil].code];
                            });
                            
                        } else {
                            NSLog(@"Export Session Status: %ld", (long)_exportSession.status);
                        }
                    }];
                    
                } else {
                    
                    dispatch_semaphore_signal(semaphoreGroup);
                    
                    // Delete record on Table Auto Upload
                    if ([selector isEqualToString:selectorUploadAutoUpload] || [selector isEqualToString:selectorUploadAutoUploadAll])
                        [[NCManageDatabase sharedInstance] deleteAutoUploadWithAssetLocalIdentifier:assetLocalIdentifier];
                    
                    // Activity
                    [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:assetLocalIdentifier action:k_activityDebugActionUpload selector:selector note:[NSString stringWithFormat:@"%@ [%@]",NSLocalizedString(@"_read_file_error_", nil), error.description] type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:activeUrl];
                    
                    // Error for uploadFileFailure
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (delegate)
                            if ([delegate respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                                [delegate uploadFileFailure:nil fileID:nil serverUrl:serverUrl selector:selector message:@"_read_file_error_" errorCode:[NSError errorWithDomain:@"it.twsweb.cryptocloud" code:kCFURLErrorFileDoesNotExist userInfo:nil].code];
                    });
                }
            }];
            
            while (dispatch_semaphore_wait(semaphoreGroup, DISPATCH_TIME_NOW))
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
    }
    
    // IMAGE
    if (assetMediaType == PHAssetMediaTypeImage) {
        
        @autoreleasepool {
            
            dispatch_semaphore_t semaphoreGroup = dispatch_semaphore_create(0);
            
            PHImageRequestOptions *options = [PHImageRequestOptions new];
            options.networkAccessAllowed = YES; // iCloud
            
            [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                
                [imageData writeToFile:[NSString stringWithFormat:@"%@/%@", directoryUser, fileName] options:NSDataWritingAtomic error:&error];
                
                if (error) {
                    
                    // Delete record on Table Auto Upload
                    if ([selector isEqualToString:selectorUploadAutoUpload] || [selector isEqualToString:selectorUploadAutoUploadAll])
                        [[NCManageDatabase sharedInstance] deleteAutoUploadWithAssetLocalIdentifier:assetLocalIdentifier];
                    
                    // Activity
                    [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:assetLocalIdentifier action:k_activityDebugActionUpload selector:selector note:[NSString stringWithFormat:@"%@ [%@]",NSLocalizedString(@"_read_file_error_", nil), error.description] type:k_activityTypeFailure verbose:k_activityVerboseDefault  activeUrl:activeUrl];
                    
                    // Error for uploadFileFailure
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (delegate)
                            if ([delegate respondsToSelector:@selector(uploadFileFailure:fileID:serverUrl:selector:message:errorCode:)])
                                [delegate uploadFileFailure:nil fileID:nil serverUrl:serverUrl selector:selector message:@"_read_file_error_" errorCode:[NSError errorWithDomain:@"it.twsweb.cryptocloud" code:kCFURLErrorFileDoesNotExist userInfo:nil].code];
                    });
                    
                } else {
                    
                    //OK selectorUploadAutoUpload
                    if ([selector isEqualToString:selectorUploadAutoUpload]) {
                        if ([self.delegate respondsToSelector:@selector(addDatabaseAutoUpload:modificationDate:assetMediaType:)])
                            [self.delegate addDatabaseAutoUpload:metadataNet modificationDate:modificationDate assetMediaType:assetMediaType];
                    } else {
                        if ([self.delegate respondsToSelector:@selector(upload:serverUrl:cryptated:template:onlyPlist:fileNameTemplate:assetLocalIdentifier:session:taskStatus:selector:selectorPost:errorCode:delegate:)])
                            [self.delegate upload:fileName serverUrl:serverUrl cryptated:cryptated template:NO onlyPlist:NO fileNameTemplate:nil assetLocalIdentifier:assetLocalIdentifier session:session taskStatus:taskStatus selector:selector selectorPost:selectorPost errorCode:errorCode delegate:delegate];
                    }
                }
                
                dispatch_semaphore_signal(semaphoreGroup);
            }];
            
            while (dispatch_semaphore_wait(semaphoreGroup, DISPATCH_TIME_NOW))
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
    }
}

@end
