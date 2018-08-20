//
//  PKDownloadButton.m
//  PKDownloadButton
//
//  Created by Pavel on 28/05/15.
//  Copyright (c) 2015 Katunin. All rights reserved.
//

#import "PKDownloadButton.h"
#import "PKMacros.h"
#import "NSLayoutConstraint+PKDownloadButton.h"
#import "UIImage+PKDownloadButton.h"
#import "PKPendingView.h"

@interface PKDownloadButton ()

@property (nonatomic, weak) PKBorderedButton *startDownloadButton;
@property (nonatomic, weak) PKStopDownloadButton *stopDownloadButton;
@property (nonatomic, weak) PKBorderedButton *downloadedButton;
@property (nonatomic, weak) PKPendingView *pendingView;

@property (nonatomic, strong) NSMutableArray *stateViews;

- (PKBorderedButton *)createStartDownloadButton;
- (PKStopDownloadButton *)createStopDownloadButton;
- (PKBorderedButton *)createDownloadedButton;
- (PKPendingView *)createPendingView;

- (void)currentButtonTapped:(id)sender;

- (void)createSubviews;
- (NSArray *)createConstraints;

@end

static PKDownloadButton *CommonInit(PKDownloadButton *self) {
    if (self != nil) {
        [self createSubviews];
        [self addConstraints:[self createConstraints]];
        
        self.state = kPKDownloadButtonState_StartDownload;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

@implementation PKDownloadButton

#pragma mark - Properties

- (void)setState:(PKDownloadButtonState)state {
    _state = state;
    
    [self.stateViews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SafeObjClassCast(UIView, view, obj);
        view.hidden = YES;
    }];
    
    switch (state) {
        case kPKDownloadButtonState_StartDownload:
            self.startDownloadButton.hidden = NO;
            break;
        case kPKDownloadButtonState_Pending:
            self.pendingView.hidden = NO;
            [self.pendingView startSpin];
            break;
        case kPKDownloadButtonState_Downloading:
            self.stopDownloadButton.hidden = NO;
            self.stopDownloadButton.progress = 0.f;
            break;
        case kPKDownloadButtonState_Downloaded:
            self.downloadedButton.hidden = NO;
            break;
        default:
            NSAssert(NO, @"unsupported state");
            break;
    }
}

#pragma mark - Initialization

- (id)initWithCoder:(NSCoder *)decoder {
    return CommonInit([super initWithCoder:decoder]);
}

- (instancetype)initWithFrame:(CGRect)frame {
    return CommonInit([super initWithFrame:frame]);
}

- (void)tintColorDidChange {
	[super tintColorDidChange];
	
    [self updateButton:self.startDownloadButton title:[self.startDownloadButton titleForState:UIControlStateNormal] font:self.startDownloadButton.titleLabel.font];
	[self updateButton:self.downloadedButton title:[self.downloadedButton titleForState:UIControlStateNormal] font:self.downloadedButton.titleLabel.font];
}


#pragma mark - appearance

-(void)updateStartDownloadButtonText:(NSString *)title {
    [self updateButton:self.startDownloadButton title:title];
}

-(void)updateDownloadedButtonText:(NSString *)title {
    [self updateButton:self.downloadedButton title:title];
}


-(void)updateStartDownloadButtonText:(NSString *)title font:(UIFont *)font {
    [self updateButton:self.startDownloadButton title:title font: font];
}

-(void)updateDownloadedButtonText:(NSString *)title font:(UIFont *)font {
    [self updateButton:self.downloadedButton title:title font: font];
}


- (void)updateButton:(UIButton *)button title:(NSString *)title {
    [self updateButton:button title:title font:[UIFont systemFontOfSize:14.f]];
}

- (void)updateButton:(UIButton *)button title:(NSString *)title font:(UIFont *)font {
    if (title == nil) {
        title = @"";
    }
    
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:self.tintColor forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateHighlighted];
    
    button.titleLabel.font = font;
}

#pragma mark - private methods

- (PKBorderedButton *)createStartDownloadButton {
    PKBorderedButton *startDownloadButton = [PKBorderedButton buttonWithType:UIButtonTypeCustom];
    [startDownloadButton configureDefaultAppearance];
    
	[self updateButton:startDownloadButton title:@"DOWNLOAD"];
	
    [startDownloadButton addTarget:self
                            action:@selector(currentButtonTapped:)
                  forControlEvents:UIControlEventTouchUpInside];
    return startDownloadButton;
}

- (PKStopDownloadButton *)createStopDownloadButton {
    PKStopDownloadButton *stopDownloadButton = [[PKStopDownloadButton alloc] init];
    [stopDownloadButton.stopButton addTarget:self action:@selector(currentButtonTapped:)
                            forControlEvents:UIControlEventTouchUpInside];
    return stopDownloadButton;
}

- (PKBorderedButton *)createDownloadedButton {
    PKBorderedButton *downloadedButton = [PKBorderedButton buttonWithType:UIButtonTypeCustom];
    [downloadedButton configureDefaultAppearance];

	[self updateButton:downloadedButton title:@"REMOVE"];
    
    [downloadedButton addTarget:self
                         action:@selector(currentButtonTapped:)
               forControlEvents:UIControlEventTouchUpInside];
    return downloadedButton;
}

- (PKPendingView *)createPendingView {
    PKPendingView *pendingView = [[PKPendingView alloc] init];
    [pendingView addTarget:self action:@selector(currentButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    return pendingView;
}

- (void)currentButtonTapped:(id)sender {
    [self.delegate downloadButtonTapped:self currentState:self.state];
    BlockSafeRun(self.callback, self, self.state);
}

- (void)createSubviews {
    self.stateViews = (__bridge_transfer NSMutableArray *)CFArrayCreateMutable(nil, 0, nil);
    
    PKBorderedButton *startDownloadButton = [self createStartDownloadButton];
    startDownloadButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:startDownloadButton];
    self.startDownloadButton = startDownloadButton;
    [self.stateViews addObject:startDownloadButton];
    
    PKStopDownloadButton *stopDownloadButton = [self createStopDownloadButton];
    stopDownloadButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:stopDownloadButton];
    self.stopDownloadButton = stopDownloadButton;
    [self.stateViews addObject:stopDownloadButton];
    
    PKBorderedButton *downloadedButton = [self createDownloadedButton];
    downloadedButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:downloadedButton];
    self.downloadedButton = downloadedButton;
    [self.stateViews addObject:downloadedButton];
    
    PKPendingView *pendingView = [self createPendingView];
    pendingView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:pendingView];
    self.pendingView = pendingView;
    [self.stateViews addObject:pendingView];
}

- (NSArray *)createConstraints {
    NSMutableArray *constraints = [NSMutableArray array];
    
    [self.stateViews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SafeObjClassCast(UIView, view, obj);
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsForWrappedSubview:view
                                                                               withInsets:UIEdgeInsetsZero]];
    }];
    
    return constraints;
}

@end

