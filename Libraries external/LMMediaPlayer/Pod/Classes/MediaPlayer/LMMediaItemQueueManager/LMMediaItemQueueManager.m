//
//  LMMediaItemArchiver.m
//  iPodMusicSample
//
//  Created by Akira Matsuda on 2014/01/31.
//  Copyright (c) 2014年 Akira Matsuda. All rights reserved.
//

#import "LMMediaItemQueueManager.h"
#import "LMMediaPlayerHelper.h"

static NSString *const kLMMediaItemQueueManagerQueueList = @"kLMMediaItemQueueManagerQueueList";

@implementation LMMediaItemQueueManager

+ (NSArray *)queueList
{
	return [[NSUserDefaults standardUserDefaults] arrayForKey:kLMMediaItemQueueManagerQueueList];
}

+ (void)removeQueueWithKey:(NSString *)key
{
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
	NSMutableArray *keys = [NSMutableArray arrayWithArray:[LMMediaItemQueueManager queueList]];
	for (NSString *k in keys) {
		if ([k isEqualToString:key]) {
			[keys removeObject:k];
			break;
		}
	}

	[[NSUserDefaults standardUserDefaults] setObject:keys forKey:kLMMediaItemQueueManagerQueueList];
}

+ (void)saveQueueWithKey:(NSString *)key queue:(NSArray *)queue
{
	NSMutableArray *saveArray = [NSMutableArray new];
	LM_AUTORELEASE(saveArray);
	for (LMMediaItem *item in queue) {
		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:item];
		[saveArray addObject:data];
	}
	[[NSUserDefaults standardUserDefaults] setObject:saveArray forKey:key];

	NSMutableArray *keys = [NSMutableArray arrayWithArray:[LMMediaItemQueueManager queueList]];
	[keys addObject:key];
	[[NSUserDefaults standardUserDefaults] setObject:keys forKey:kLMMediaItemQueueManagerQueueList];
}

+ (NSArray *)loadQueueWithKey:(NSString *)key
{
	NSMutableArray *result = [NSMutableArray new];
	LM_AUTORELEASE(result);
	NSArray *array = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
	for (id d in array) {
		LMMediaItem *item = [NSKeyedUnarchiver unarchiveObjectWithData:d];
		[result addObject:item];
	}

	NSArray *newArray = [result copy];
	LM_AUTORELEASE(newArray);
	return newArray;
}

@end
