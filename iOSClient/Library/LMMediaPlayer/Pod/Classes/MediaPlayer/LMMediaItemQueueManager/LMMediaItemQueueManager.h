//
//  LMMediaItemArchiver.h
//  iPodMusicSample
//
//  Created by Akira Matsuda on 2014/01/31.
//  Copyright (c) 2014年 Akira Matsuda. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LMMediaItem.h"

@interface LMMediaItemQueueManager : NSObject

+ (NSArray *)queueList;
+ (void)removeQueueWithKey:(NSString *)key;
+ (void)saveQueueWithKey:(NSString *)key queue:(NSArray *)queue;
+ (NSArray *)loadQueueWithKey:(NSString *)key;

@end
