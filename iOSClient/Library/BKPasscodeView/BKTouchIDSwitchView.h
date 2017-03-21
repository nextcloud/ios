//
//  BKTouchIDSwitchView.h
//  BKPasscodeViewDemo
//
//  Created by Byungkook Jang on 2014. 10. 11..
//  Copyright (c) 2014년 Byungkook Jang. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BKTouchIDSwitchViewDelegate;


@interface BKTouchIDSwitchView : UIView

@property (nonatomic, weak) id<BKTouchIDSwitchViewDelegate> delegate;

@property (nonatomic, strong) UIView        *switchBackgroundView;
@property (nonatomic, strong) UILabel       *messageLabel;
@property (nonatomic, strong) UILabel       *titleLabel;
@property (nonatomic, strong) UISwitch      *touchIDSwitch;
@property (nonatomic, strong) UIButton      *doneButton;

@end


@protocol BKTouchIDSwitchViewDelegate <NSObject>

- (void)touchIDSwitchViewDidPressDoneButton:(BKTouchIDSwitchView *)view;

@end