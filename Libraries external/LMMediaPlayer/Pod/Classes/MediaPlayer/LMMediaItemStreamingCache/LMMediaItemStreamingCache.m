//
//  LMMediaItemCache.m
//  LMMediaPlayer
//
//  Created by Akira Matsuda on 10/13/14.
//  Copyright (c) 2014 Akira Matsuda. All rights reserved.
//

#import "LMMediaItemStreamingCache.h"
#import <AVFoundation/AVFoundation.h>

@interface LMMediaItemStreamingCache ()

@end

@implementation LMMediaItemStreamingCache

+ (instancetype)sharedCache
{
	static id sharedInstance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[[self class] alloc] init];
	});

	return sharedInstance;
}

- (BOOL)isCacheAvailable:(NSString *)key
{
	return NO;
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
	return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
}

@end
