//
//  BKPasscodeDummyViewController.h
//  BKPasscodeViewDemo
//
//  Created by Byungkook Jang on 2014. 8. 3..
//  Copyright (c) 2014년 Byungkook Jang. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BKPasscodeDummyViewControllerDelegate;


@interface BKPasscodeDummyViewController : UIViewController

@property (nonatomic, weak) id<BKPasscodeDummyViewControllerDelegate> delegate;

@end


@protocol BKPasscodeDummyViewControllerDelegate <NSObject>

- (void)dummyViewControllerWillAppear:(BKPasscodeDummyViewController *)aViewController;
- (void)dummyViewControllerDidAppear:(BKPasscodeDummyViewController *)aViewController;

@end