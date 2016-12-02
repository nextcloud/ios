//
//  NYXProgressiveImageView.h
//  NYXImagesKit
//
//  Created by @Nyx0uf on 13/01/12.
//  Copyright 2012 Nyx0uf. All rights reserved.
//  www.cocoaintheshell.com
//  Caching stuff by raphaelp
//

#import <UIKit/UIKit.h> 

@protocol NYXProgressiveImageViewDelegate <NSObject>
@optional
-(void)imageDidLoadWithImage:(UIImage*)img;
-(void)imageDownloadCompletedWithImage:(UIImage*)img;
-(void)imageDownloadFailedWithData:(NSData*)data;
@end


@interface NYXProgressiveImageView : UIImageView

#pragma mark - Public messages
/// Launch the image download
-(void)loadImageAtURL:(NSURL*)url;
/// This will remove all cached images managed by any NYXProgressiveImageView instances
+(void)resetImageCache;

#pragma mark - Public properties
/// Delegate
@property (nonatomic, weak) IBOutlet id <NYXProgressiveImageViewDelegate> delegate;
/// Enable / Disable caching
@property (nonatomic, getter = isCaching) BOOL caching;
/// Cache time in seconds
@property (nonatomic) NSTimeInterval cacheTime;
/// Downloading flag
@property (nonatomic, readonly, getter = isDownloading) BOOL downloading;

@end
