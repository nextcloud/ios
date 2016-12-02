//
//  PHAsset+Utilities.h
//
//  Created by Zakk Hoyt on 9/22/14.
//  Copyright (c) 2014 Zakk Hoyt. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Photos;

typedef void (^PHAssetBoolBlock)(BOOL success);
typedef void (^PHAssetMetadataBlock)(NSDictionary *metadata);
typedef void (^PHAssetAssetBoolBlock)(PHAsset *asset, BOOL success);

@interface PHAsset (Utilities)

/*!
 @method        saveToAlbum:completionBlock
 @description   Save a copy of a PHAsset to a photo album. Will create the album if it doesn't exist.
 @param         title                  The title of the album.
 @param         completionBlock        This block is passed a BOOL for success.  This parameter may be nil.
 */
-(void)saveToAlbum:(NSString*)title completionBlock:(PHAssetBoolBlock)completionBlock;

/*!
 @method        requestMetadataWithCompletionBlock
 @description   Get metadata dictionary of an asset (the kind with {Exif}, {GPS}, etc...
 @param         completionBlock        This block is passed a dictionary of metadata properties. See ImageIO framework for parsing/reading these. This parameter may be nil.
 */
-(void)requestMetadataWithCompletionBlock:(PHAssetMetadataBlock)completionBlock;

/*!
 @method        updateLocation:creationDate:completionBlock
 @description   Update the location and date of an existing asset
 @param         location               A CLLocation object to be written to the PHAsset. See CoreLocation framework for obtaining locations.
 @param         creationDate           An NSDate to be written to the PHAsset.
 @param         completionBlock        This block is passed the PHAsset updated with location/date (if applied) and BOOL for success. This parameter may be nil.
 */
-(void)updateLocation:(CLLocation*)location creationDate:(NSDate*)creationDate completionBlock:(PHAssetBoolBlock)completionBlock;

/*!
 @method        saveImageToCameraRoll:location:completionBlock
 @description   Save an image to camera roll with optional completion (returns PHAsset in completion block)
 @param         location               A CLLocation object to be written to the PHAsset. See CoreLocation framework for obtaining locations. This parameter may be nil.
 @param         creationDate           An NSDate to be written to the PHAsset.
 @param         completionBlock        Returns the PHAsset which was written and BOOL for success. This parameter may be nil.
 */
+(void)saveImageToCameraRoll:(UIImage*)image location:(CLLocation*)location completionBlock:(PHAssetAssetBoolBlock)completionBlock;

/*!
 @method        saveVideoAtURL:location:completionBlock
 @description   Save a video to camera roll with optional completion (returns PHAsset in completion block)
 @param         location               A CLLocation object to be written to the PHAsset. See CoreLocation framework for obtaining locations. This parameter may be nil.
 @param         creationDate           An NSDate to be written to the PHAsset.
 @param         completionBlock        Returns the PHAsset which was written and BOOL for success. This parameter may be nil.
 */
+(void)saveVideoAtURL:(NSURL*)url location:(CLLocation*)location completionBlock:(PHAssetAssetBoolBlock)completionBlock;

@end


