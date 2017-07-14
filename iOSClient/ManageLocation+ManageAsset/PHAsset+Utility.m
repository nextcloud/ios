//
//  PHAsset+Utilities.m
//
//  Created by Zakk Hoyt on 9/22/14.
//  Copyright (c) 2014 Zakk Hoyt. All rights reserved.
//

#import "PHAsset+Utility.h"
@import Photos;

@implementation PHAsset (Utilities)

#pragma mark Public methods

-(void)saveToAlbum:(NSString*)title completionBlock:(PHAssetBoolBlock)completionBlock{
    void (^saveAssetCollection)(PHAssetCollection *assetCollection) = ^(PHAssetCollection *assetCollection){
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCollectionChangeRequest *changeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:assetCollection];
            [changeRequest addAssets:@[self]];
        } completionHandler:^(BOOL success, NSError *error) {
            if(success == NO) {
                NSLog(@"[LOG] Failed to add PHAsset to album: %@ error: %@", title, error.localizedDescription);
            }
            return completionBlock(success);
        }];
    };
    
    PHAssetCollection *assetCollection = [self albumWithTitle:title];
    if(assetCollection){
        // Album exists
        saveAssetCollection(assetCollection);
    } else {
        // Need to create album before saving
        // Create new album (will create duplicates)
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:title];
        } completionHandler:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"[LOG] Error creating album: %@", error);
            } else {
                PHAssetCollection *assetCollection = [self albumWithTitle:title];
                saveAssetCollection(assetCollection);
            }
        }];
    }
}

-(void)requestMetadataWithCompletionBlock:(PHAssetMetadataBlock)completionBlock{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        PHContentEditingInputRequestOptions *editOptions = [[PHContentEditingInputRequestOptions alloc]init];
        editOptions.networkAccessAllowed = YES;
        [self requestContentEditingInputWithOptions:editOptions completionHandler:^(PHContentEditingInput *contentEditingInput, NSDictionary *info) {
            CIImage *image = [CIImage imageWithContentsOfURL:contentEditingInput.fullSizeImageURL];
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(image.properties);
            });
        }];
    });
}

-(void)updateLocation:(CLLocation*)location creationDate:(NSDate*)creationDate completionBlock:(PHAssetBoolBlock)completionBlock{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *assetRequest = [PHAssetChangeRequest changeRequestForAsset:self];
        if(location) assetRequest.location = location;
        if(creationDate) assetRequest.creationDate = creationDate;
    } completionHandler:^(BOOL success, NSError *error) {
        if(success){
            completionBlock(YES);
        } else {
            completionBlock(NO);
        }
    }];
}


+(void)saveImageToCameraRoll:(UIImage*)image location:(CLLocation*)location completionBlock:(PHAssetAssetBoolBlock)completionBlock{
    __block PHObjectPlaceholder *placeholderAsset = nil;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *newAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        newAssetRequest.location = location;
        newAssetRequest.creationDate = [NSDate date];
        placeholderAsset = newAssetRequest.placeholderForCreatedAsset;
    } completionHandler:^(BOOL success, NSError *error) {
        if(success){
            PHAsset *asset = [self getAssetFromlocalIdentifier:placeholderAsset.localIdentifier];
            completionBlock(asset, YES);
        } else {
            completionBlock(nil, NO);
        }
    }];
}

+(void)saveVideoAtURL:(NSURL*)url location:(CLLocation*)location completionBlock:(PHAssetAssetBoolBlock)completionBlock{
    __block PHObjectPlaceholder *placeholderAsset = nil;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *newAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
        newAssetRequest.location = location;
        newAssetRequest.creationDate = [NSDate date];
        placeholderAsset = newAssetRequest.placeholderForCreatedAsset;
    } completionHandler:^(BOOL success, NSError *error) {
        if(success){
            PHAsset *asset = [self getAssetFromlocalIdentifier:placeholderAsset.localIdentifier];
            completionBlock(asset, YES);
        } else {
            completionBlock(nil, NO);
        }
    }];
}

#pragma mark Private helpers

-(PHAssetCollection*)albumWithTitle:(NSString*)title{
    // Check if album exists. If not, create it.
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"localizedTitle = %@", title];
    PHFetchOptions *options = [[PHFetchOptions alloc]init];
    options.predicate = predicate;
    PHFetchResult *result = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:options];
    if(result.count){
        return result[0];
    }
    return nil;
    
}

+(PHAsset*)getAssetFromlocalIdentifier:(NSString*)localIdentifier{
    if(localIdentifier == nil){
        NSLog(@"[LOG] Cannot get asset from localID because it is nil");
        return nil;
    }
    
    PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier] options:nil];
    
    if(result.count){
        return result[0];
    }
    return nil;
}

@end

