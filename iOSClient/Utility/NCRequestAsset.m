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

- (void)writeAssetToSandbox:(NSString *)fileName assetLocalIdentifier:(NSString *)assetLocalIdentifier selector:(NSString *)selector metadataNet:(CCMetadataNet *)metadataNet
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetLocalIdentifier] options:nil];
    
    PHAsset *asset = result[0];
    PHAssetMediaType assetMediaType = asset.mediaType;
    NSDate *assetDate = asset.creationDate;
    __block NSError *error = nil;
    
    // VIDEO
    if (assetMediaType == PHAssetMediaTypeVideo) {
        
        @autoreleasepool {
            
            PHVideoRequestOptions *options = [PHVideoRequestOptions new];
            options.networkAccessAllowed = true;
            
            [[PHImageManager defaultManager] requestPlayerItemForVideo:asset options:options resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", appDelegate.directoryUser, fileName]])
                    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", appDelegate.directoryUser, fileName] error:nil];
                
                AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:playerItem.asset presetName:AVAssetExportPresetHighestQuality];
                
                if (exportSession) {
                    
                    exportSession.outputURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", appDelegate.directoryUser, fileName]];
                    exportSession.outputFileType = AVFileTypeQuickTimeMovie;
                    
                    [exportSession exportAsynchronouslyWithCompletionHandler:^{
                        
                        if (AVAssetExportSessionStatusCompleted == exportSession.status) {
                            
                            //OK
                            if ([self.delegate respondsToSelector:@selector(addDatabaseAutoUpload:assetDate:assetMediaType:)])
                                [self.delegate addDatabaseAutoUpload:metadataNet assetDate:assetDate assetMediaType:assetMediaType];
                            
                        } else if (AVAssetExportSessionStatusFailed == exportSession.status) {
                            
                            // Delete record on Table Auto Upload
                            if ([selector isEqualToString:selectorUploadAutoUpload] || [selector isEqualToString:selectorUploadAutoUploadAll])
                                [[NCManageDatabase sharedInstance] deleteAutoUploadWithAssetLocalIdentifier:assetLocalIdentifier];
                            
                            [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:assetLocalIdentifier action:k_activityDebugActionUpload selector:selector note:[NSString stringWithFormat:@"%@ [%@]",NSLocalizedString(@"_read_file_error_", nil), error.description] type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:appDelegate.activeUrl];
                            
                        } else {
                            NSLog(@"Export Session Status: %ld", (long)exportSession.status);
                        }
                    }];
                    
                } else {
                    
                    // Delete record on Table Auto Upload
                    if ([selector isEqualToString:selectorUploadAutoUpload] || [selector isEqualToString:selectorUploadAutoUploadAll])
                        [[NCManageDatabase sharedInstance] deleteAutoUploadWithAssetLocalIdentifier:assetLocalIdentifier];
                    
                    [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:assetLocalIdentifier action:k_activityDebugActionUpload selector:selector note:[NSString stringWithFormat:@"%@ [%@]",NSLocalizedString(@"_read_file_error_", nil), error.description] type:k_activityTypeFailure verbose:k_activityVerboseDefault activeUrl:appDelegate.activeUrl];
                }
            }];
        }
    }
    
    // IMAGE
    if (assetMediaType == PHAssetMediaTypeImage) {
        
        @autoreleasepool {
            
            PHImageRequestOptions *options = [PHImageRequestOptions new];
            options.synchronous = NO;
            
            [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                
                [imageData writeToFile:[NSString stringWithFormat:@"%@/%@", appDelegate.directoryUser, fileName] options:NSDataWritingAtomic error:&error];
                
                if (error) {
                    
                    NSString *note = [NSString stringWithFormat:@"%@ [%@]",NSLocalizedString(@"_read_file_error_", nil), error.description];
                    
                    [[NCManageDatabase sharedInstance] addActivityClient:fileName fileID:assetLocalIdentifier action:k_activityDebugActionUpload selector:selector note:note type:k_activityTypeFailure verbose:k_activityVerboseDefault  activeUrl:app.activeUrl];
                    
                    // Delete record on Table Auto Upload
                    if ([selector isEqualToString:selectorUploadAutoUpload] || [selector isEqualToString:selectorUploadAutoUploadAll])
                        [[NCManageDatabase sharedInstance] deleteAutoUploadWithAssetLocalIdentifier:assetLocalIdentifier];
                    
                } else {
                    
                    //OK
                    if ([self.delegate respondsToSelector:@selector(addDatabaseAutoUpload:assetDate:assetMediaType:)])
                        [self.delegate addDatabaseAutoUpload:metadataNet assetDate:assetDate assetMediaType:assetMediaType];
                }
            }];
        }
    }
}

@end
