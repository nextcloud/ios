//
//  BKShiftingView.h
//  BKPasscodeViewDemo
//
//  Created by Byungkook Jang on 2014. 10. 11..
//  Copyright (c) 2014년 Byungkook Jang. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, BKShiftingDirection) {
    BKShiftingDirectionForward,
    BKShiftingDirectionBackward,
};

@interface BKShiftingView : UIView

@property (nonatomic, strong) UIView        *currentView;

- (void)showView:(UIView *)view withDirection:(BKShiftingDirection)direction;

@end
