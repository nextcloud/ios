//
//  MediaViewController.m
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/14.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "MediaViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface MediaViewController ()

@property (nonatomic, strong) NSString * URLString;

@end

@implementation MediaViewController

- (instancetype)initWithURLString:(NSString *)URLString
{
    if (self = [super init])
    {
        self.URLString = URLString;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.player = [AVPlayer playerWithURL:[NSURL URLWithString:self.URLString]];
    [self.player play];
}

- (void)dealloc
{
    [self.player.currentItem.asset cancelLoading];
    [self.player.currentItem cancelPendingSeeks];
    [self.player cancelPendingPrerolls];
}

@end
