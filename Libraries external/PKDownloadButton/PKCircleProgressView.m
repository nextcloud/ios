//
//  PKCircleProgressView.m
//  PKDownloadButton
//
//  Created by Pavel on 28/05/15.
//  Copyright (c) 2015 Katunin. All rights reserved.
//

#import "PKCircleProgressView.h"
#import "PKCircleView.h"
#import "NSLayoutConstraint+PKDownloadButton.h"

static const CGFloat kDefaultRaduis = 13.f;
static const CGFloat kDefaultFilledLineWidth = 3.f;
static const CGFloat kDefaultEmptyLineWidth = 1.f;
static const CGFloat kStartAngle = M_PI * 1.5;

@interface PKCircleProgressView ()

@property (nonatomic, assign) CGFloat startAngle;
@property (nonatomic, assign) CGFloat endAngle;

@property (nonatomic, weak) PKCircleView *emptyLineCircleView;
@property (nonatomic, weak) PKCircleView *filledLineCircleView;

@property (nonatomic, weak) NSLayoutConstraint *emptyLineCircleWidth;
@property (nonatomic, weak) NSLayoutConstraint *emptyLineCircleHeight;

@property (nonatomic, weak) NSLayoutConstraint *filledLineCircleWidth;
@property (nonatomic, weak) NSLayoutConstraint *filledLineCircleHeight;

@property (nonatomic, assign) CGFloat emptyLineCircleSize;
@property (nonatomic, assign) CGFloat filledLineCircleSize;

- (PKCircleView *)createEmptyLineCircleView;
- (PKCircleView *)createFilledLineCircleView;

- (NSArray *)createCircleConstraints;

@end

static PKCircleProgressView *CommonInit(PKCircleProgressView *self) {
    if (self != nil) {
        self.backgroundColor = [UIColor clearColor];
        self.startAngle = kStartAngle;
        self.endAngle = self.startAngle + (M_PI * 2);
        self.clipsToBounds = NO;
        
        PKCircleView *emptyLineCircleView = [self createEmptyLineCircleView];
        self.emptyLineCircleView = emptyLineCircleView;
        emptyLineCircleView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:emptyLineCircleView];
        
        PKCircleView *filledLineCircleView = [self createFilledLineCircleView];
        self.filledLineCircleView = filledLineCircleView;
        filledLineCircleView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:filledLineCircleView];
        
        [self addConstraints:[self createCircleConstraints]];
        
        self.emptyLineWidth = kDefaultEmptyLineWidth;
        self.filledLineWidth = kDefaultFilledLineWidth;
        self.radius = kDefaultRaduis;
    }
    return self;
}

@implementation PKCircleProgressView

#pragma mark - initilaization / deallocation

- (id)initWithCoder:(NSCoder *)decoder {
    return CommonInit([super initWithCoder:decoder]);
}

- (instancetype)initWithFrame:(CGRect)frame {
    return CommonInit([super initWithFrame:frame]);
}

#pragma mark - properties

- (void)setEmptyLineCircleSize:(CGFloat)emptyLineCircleSize {
    self.emptyLineCircleWidth.constant = emptyLineCircleSize;
    self.emptyLineCircleHeight.constant = emptyLineCircleSize;
}

- (void)setFilledLineCircleSize:(CGFloat)filledLineCircleSize {
    self.filledLineCircleWidth.constant = filledLineCircleSize;
    self.filledLineCircleHeight.constant = filledLineCircleSize;
}

- (void)setProgress:(CGFloat)progress {
    _progress = progress;
    self.filledLineCircleView.startAngleRadians = self.startAngle;
    self.filledLineCircleView.endAngleRadians = (self.endAngle - self.startAngle) * progress + self.startAngle;
    
    [self setNeedsDisplay];
}

- (void)setFilledLineWidth:(CGFloat)filledLineWidth {
    _filledLineWidth = filledLineWidth;
    self.filledLineCircleView.lineWidth = filledLineWidth;
    [self setNeedsUpdateConstraints];
}

- (void)setEmptyLineWidth:(CGFloat)emptyLineWidth {
    _emptyLineWidth = emptyLineWidth;
    self.emptyLineCircleView.lineWidth = emptyLineWidth;
    [self setNeedsUpdateConstraints];
}

- (void)setRadius:(CGFloat)radius {
    _radius = radius;
    [self setNeedsUpdateConstraints];
}

- (void)setFilledLineStyleOuter:(BOOL)filledLineStyleOuter {
    _filledLineStyleOuter = filledLineStyleOuter;
    [self setNeedsUpdateConstraints];
}

#pragma mark - UIView

- (void)updateConstraints {
    [super updateConstraints];
    self.emptyLineCircleSize = self.radius * 2.f;
    CGFloat deltaRaduis = 0.f;
    if (self.filledLineStyleOuter) {
        deltaRaduis = - self.emptyLineCircleView.lineWidth / 2.f + self.filledLineCircleView.lineWidth;
    }
    else {
        deltaRaduis = - self.emptyLineCircleView.lineWidth / 2.f;
    }
    self.filledLineCircleSize = self.radius * 2.f + deltaRaduis * 2.f;
}

#pragma mark - private methods

- (PKCircleView *)createEmptyLineCircleView {
    PKCircleView *emptyCircelView = [[PKCircleView alloc] init];
    
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintForView:emptyCircelView
                                                                      withWidth:0.f];
    self.emptyLineCircleWidth = widthConstraint;
    [emptyCircelView addConstraint:widthConstraint];
    
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintForView:emptyCircelView
                                                                      withHeight:0.f];
    self.emptyLineCircleHeight = heightConstraint;
    [emptyCircelView addConstraint:heightConstraint];
    
    return emptyCircelView;
}

- (PKCircleView *)createFilledLineCircleView {
    PKCircleView *filledCircelView = [[PKCircleView alloc] init];
    
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintForView:filledCircelView
                                                                      withWidth:0.f];
    self.filledLineCircleWidth = widthConstraint;
    [filledCircelView addConstraint:widthConstraint];
    
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintForView:filledCircelView
                                                                      withHeight:0.f];
    self.filledLineCircleHeight = heightConstraint;
    [filledCircelView addConstraint:heightConstraint];
    
    return filledCircelView;
}

- (NSArray *)createCircleConstraints {
    NSMutableArray *constraints = [NSMutableArray array];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsForCenterView:self.emptyLineCircleView
                                                                         withView:self]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsForWrappedSubview:self.filledLineCircleView
                                                                           withInsets:UIEdgeInsetsZero]];
    return constraints;
}

@end
