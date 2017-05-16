//
//  CCManageAsset.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 23/07/15.
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

#import "CCManageAsset.h"

#import "AppDelegate.h"

@implementation CCManageAsset

- (NSMutableArray *)getCameraRollNewItemsWithDatePhoto:(NSDate *)datePhoto dateVideo:(NSDate *)dateVideo
{
    [self checkAssetsLibraryWithDatePhoto:datePhoto dateVideo:dateVideo];
    
    return self.assetsNewToUpload;
}

- (void)checkAssetsLibraryWithDatePhoto:(NSDate *)datePhoto dateVideo:(NSDate *)dateVideo
{
    self.assetsNewToUpload = [[NSMutableArray alloc] init];
    ALAssetsLibrary *assetLibrary = [CCUtility defaultAssetsLibrary];
    
    if ([CCCoreData getCameraUploadActiveAccount:app.activeAccount]) {
        
        dispatch_semaphore_t semaphoreGroup = dispatch_semaphore_create(0);
        
        [assetLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                        
            if (group == nil) {
                dispatch_semaphore_signal(semaphoreGroup);
                return;
            }
                                        
            NSUInteger nType = [[group valueForProperty:ALAssetsGroupPropertyType] intValue];
                                        
            if (nType == ALAssetsGroupSavedPhotos){
                [self.assetGroups addObject:group];
                self.assetsNewToUpload = [self getArrayNewAssetsFromGroup:group datePhoto:datePhoto dateVideo:dateVideo];
            }
                                        
        } failureBlock:^(NSError *error) {
                                        
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil) message: NSLocalizedString(@"_access_photo_not_enabled_msg_", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"_ok_", nil) otherButtonTitles:nil];
            [alert show];
                                        
            NSLog(@"[LOG] checkAssetsLibrary : Access error at camera roll %@", [error description]);
                                        
            dispatch_semaphore_signal(semaphoreGroup);
        }];
        
        while (dispatch_semaphore_wait(semaphoreGroup, DISPATCH_TIME_NOW))
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

- (NSMutableArray *)getArrayNewAssetsFromGroup:(ALAssetsGroup *)group datePhoto:(NSDate *)datePhoto dateVideo:(NSDate *)dateVideo
{
    if (![CCCoreData getCameraUploadActiveAccount:app.activeAccount])
        return nil;
    
    NSMutableArray *tmpAssetsNew = [[NSMutableArray alloc] init];
    
    // Photo
    
    if ([CCCoreData getCameraUploadPhotoActiveAccount:app.activeAccount]) {
        
        dispatch_semaphore_t semaphoreAsset = dispatch_semaphore_create(0);

        [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
            
            NSDate *assetDate = [result valueForProperty:ALAssetPropertyDate];
            NSString *assetType = [result valueForProperty:ALAssetPropertyType];

            if ([assetDate compare:datePhoto] == NSOrderedDescending) {
                
                if ([assetType isEqualToString:@"ALAssetTypePhoto"]) {
                
                    NSLog(@"[LOG] Insert new asset %@ - %@", assetDate, assetType);
                    
                    [tmpAssetsNew insertObject:result atIndex:0];
                }
                
            } else {
                    
                dispatch_semaphore_signal(semaphoreAsset);
                *stop = YES;
            }
        }];
        
        while (dispatch_semaphore_wait(semaphoreAsset, DISPATCH_TIME_NOW))
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
    // Video
    
    if ([CCCoreData getCameraUploadVideoActiveAccount:app.activeAccount]) {
        
        dispatch_semaphore_t semaphoreAsset = dispatch_semaphore_create(0);
        
        [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
            
            NSDate *assetDate = [result valueForProperty:ALAssetPropertyDate];
            NSString *assetType = [result valueForProperty:ALAssetPropertyType];
            
            if ([assetDate compare:dateVideo] == NSOrderedDescending) {
                    
                if ([assetType isEqualToString:@"ALAssetTypeVideo"]) {
                    
                    NSLog(@"[LOG] Insert new asset %@ - %@", assetDate, assetType);
                    
                    [tmpAssetsNew insertObject:result atIndex:0];
                }
                    
            } else {
                    
                dispatch_semaphore_signal(semaphoreAsset);
                *stop = YES;
            }
        }];
        
        while (dispatch_semaphore_wait(semaphoreAsset, DISPATCH_TIME_NOW))
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
    //NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES];
    
    return tmpAssetsNew; //[tmpAssetsNew sortedArrayUsingDescriptors:@[sort]];
}

- (void)removePhotoCameraRoll:(NSURL *)assetUrl
{    
    NSArray *urls = [[NSArray alloc] initWithObjects:assetUrl, nil];
    
    PHPhotoLibrary *library = [PHPhotoLibrary sharedPhotoLibrary];
    
    [library performChanges:^{
        
        PHFetchResult *assetsToBeDeleted = [PHAsset fetchAssetsWithALAssetURLs:urls options:nil];
        [PHAssetChangeRequest deleteAssets:assetsToBeDeleted];
        
    } completionHandler:^(BOOL success, NSError *error) {
        
         //do something here
    }];
}

@end
