//
//  PKPendingView.m
//  Download
//
//  Created by Pavel on 30/05/15.
//  Copyright (c) 2015 Katunin. All rights reserved.
//

#import "PKPendingView.h"
#import "NSLayoutConstraint+PKDownloadButton.h"
#import "CALayer+PKDownloadButtonAnimations.h"

static NSString *const kSpinAnimationKey = @"PKSpin";
static const CGFloat kDefaultRaduis = 13.f;
static const CGFloat kDefaultEmptyLineRadians = 0.4f;
static const CGFloat kDefaultSpinTime = 1.f;

@interface PKPendingView ()

@property (nonatomic, weak) PKCircleView *circleView;
@property (nonatomic, weak) NSLayoutConstraint *width;
@property (nonatomic, weak) NSLayoutConstraint *height;
@property (nonatomic, assign) BOOL isSpinning;

- (PKCircleView *)createCircleView;

- (NSArray *)createConstraints;

@end

static PKPendingView *CommonInit(PKPendingView *self) {
    if (self != nil) {
        PKCircleView *circleView = [self createCircleView];
        circleView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:circleView];
        self.circleView = circleView;
        self.circleView.userInteractionEnabled = NO;
        [self addConstraints:[self createConstraints]];
        
        self.emptyLineRadians = kDefaultEmptyLineRadians;
        self.radius = kDefaultRaduis;
        self.clipsToBounds = NO;
        
        self.spinTime = kDefaultSpinTime;
        [self startSpin];
    }
    return self;
}

@implementation PKPendingView

#pragma mark - initialization

- (id)initWithCoder:(NSCoder *)decoder {
    return CommonInit([super initWithCoder:decoder]);
}

- (instancetype)initWithFrame:(CGRect)frame {
    return CommonInit([super initWithFrame:frame]);
}

#pragma mark - properties

- (void)setSpinTime:(CGFloat)spinTime {
    _spinTime = spinTime;
    [self.circleView.layer removeRotationAnimationWithKey:kSpinAnimationKey];
    if (self.isSpinning) {
        [self startSpin];
    }
}

- (void)setRadius:(CGFloat)radius {
    self.width.constant = radius * 2;
    self.height.constant = radius * 2;
    [self setNeedsLayout];
}

- (void)setLineWidth:(CGFloat)lineWidth {
    self.circleView.lineWidth = lineWidth;
    [self setNeedsDisplay];
}

- (CGFloat)lineWidth {
    return self.circleView.lineWidth;
}

- (void)setEmptyLineRadians:(CGFloat)emptyLineRadians {
    _emptyLineRadians = emptyLineRadians;
    self.circleView.startAngleRadians = 1.5f * M_PI + emptyLineRadians / 2.f;
    self.circleView.endAngleRadians = self.circleView.startAngleRadians + 2 * M_PI - emptyLineRadians;
    [self setNeedsDisplay];
}

- (void)setTintColor:(UIColor *)tintColor {
    self.circleView.tintColor = tintColor;
    [self setNeedsDisplay];
}

#pragma mark - private methods

- (PKCircleView *)createCircleView {
    PKCircleView *circleView = [[PKCircleView alloc] init];
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintForView:circleView
                                                                      withHeight:0.f];
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintForView:circleView
                                                                      withWidth:0.f];
    
    [circleView addConstraints:@[heightConstraint, widthConstraint]];
    
    self.width = widthConstraint;
    self.height = heightConstraint;
    
    return circleView;
}

- (NSArray *)createConstraints {
    NSMutableArray *constraints = [NSMutableArray array];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsForWrappedSubview:self.circleView
                                                                           withInsets:UIEdgeInsetsZero]];
    return constraints;
}

- (void)startSpin {
    self.isSpinning = YES;
    [self.circleView.layer addRotationAnimationWithKey:kSpinAnimationKey
                                  fullRotationDuration:self.spinTime];
}

- (void)stopSpin {
    [self.circleView.layer removeRotationAnimationWithKey:kSpinAnimationKey];
    self.isSpinning = NO;
}

@end
