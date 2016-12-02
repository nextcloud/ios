//
//  BKPasscodeDummyViewController.m
//  BKPasscodeViewDemo
//
//  Created by Byungkook Jang on 2014. 8. 3..
//  Copyright (c) 2014년 Byungkook Jang. All rights reserved.
//

#import "BKPasscodeDummyViewController.h"

@interface BKPasscodeDummyViewController ()

@end

@implementation BKPasscodeDummyViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.delegate dummyViewControllerWillAppear:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.presentedViewController == nil) {
        // only calls delegate when presented view controller(modal view controller) does not exists.
        [self.delegate dummyViewControllerDidAppear:self];
    }
}

@end
