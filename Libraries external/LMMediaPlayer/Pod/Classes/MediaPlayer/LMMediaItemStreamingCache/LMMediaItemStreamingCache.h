//
//  LMMediaItemCache.h
//  LMMediaPlayer
//
//  Created by Akira Matsuda on 10/13/14.
//  Copyright (c) 2014 Akira Matsuda. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface LMMediaItemStreamingCache : NSObject <AVAssetResourceLoaderDelegate>

+ (instancetype)sharedCache;

@end
