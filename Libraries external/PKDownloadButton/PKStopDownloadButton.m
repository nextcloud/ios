//
//  PKStopDownloadButton.m
//  PKDownloadButton
//
//  Created by Pavel on 28/05/15.
//  Copyright (c) 2015 Katunin. All rights reserved.
//

#import "PKStopDownloadButton.h"
#import "NSLayoutConstraint+PKDownloadButton.h"
#import "UIImage+PKDownloadButton.h"

static const CGFloat kDefaultStopButtonWidth = 8.f;

@interface PKStopDownloadButton ()

@property (nonatomic, weak) UIButton *stopButton;

- (UIButton *)createStopButton;
- (NSArray *)createStopButtonConstraints;
- (void)updateAppearance;
- (PKCircleProgressView *)createCircleProgressView;

@end

static PKStopDownloadButton *CommonInit(PKStopDownloadButton *self) {
    if (self != nil) {
        UIButton *stopButton = [self createStopButton];
        stopButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:stopButton];
        self.stopButton = stopButton;
        
        [self addConstraints:[self createStopButtonConstraints]];
        [self updateAppearance];
        [self setNeedsDisplay];
    }
    return self;
}

@implementation PKStopDownloadButton

#pragma mark - properties

- (void)setStopButtonWidth:(CGFloat)stopButtonWidth {
    _stopButtonWidth = stopButtonWidth;
    [self.stopButton setImage:[UIImage stopImageOfSize:stopButtonWidth
                                                 color:self.tintColor]
                     forState:UIControlStateNormal];
    [self setNeedsDisplay];
}

#pragma mark - initialization

- (instancetype)initWithCoder:(NSCoder *)decoder {
    return CommonInit([super initWithCoder:decoder]);
}

- (instancetype)initWithFrame:(CGRect)frame {
    return CommonInit([super initWithFrame:frame]);
}

#pragma mark - private methods

- (UIButton *)createStopButton {
    UIButton *stopButton = [UIButton buttonWithType:UIButtonTypeCustom];
	stopButton.tintColor = [UIColor clearColor];
    _stopButtonWidth = kDefaultStopButtonWidth;
    return stopButton;
}

- (NSArray *)createStopButtonConstraints {
    NSMutableArray *constraints = [NSMutableArray array];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsForWrappedSubview:self.stopButton
                                                                           withInsets:UIEdgeInsetsZero]];
    
    return constraints;
}

- (PKCircleProgressView *)createCircleProgressView {
    PKCircleProgressView *circleProgressView = [[PKCircleProgressView alloc] init];
    
    return circleProgressView;
}

#pragma mark - appearance

- (void)updateAppearance {
	[self.stopButton setImage:[UIImage stopImageOfSize:_stopButtonWidth color:self.tintColor]
				forState:UIControlStateNormal];
}

- (void)tintColorDidChange {
	[super tintColorDidChange];
	[self updateAppearance];
}
@end
