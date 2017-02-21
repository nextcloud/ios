//
//  AHKActionSheet.m
//  AHKActionSheetExample
//
//  Created by Arkadiusz on 08-04-14.
//  Copyright (c) 2014 Arkadiusz Holko. All rights reserved.
//

//  Modify by Marino Faggiana on 11/01/17.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//

#import <QuartzCore/QuartzCore.h>
#import "AHKActionSheet.h"
#import "AHKActionSheetViewController.h"
#import "UIImage+AHKAdditions.h"
#import "UIWindow+AHKAdditions.h"


static const NSTimeInterval kDefaultAnimationDuration = 0.2f;
// Length of the range at which the blurred background is being hidden when the user scrolls the tableView to the top.
static const CGFloat kBlurFadeRangeSize = 200.0f;
static NSString * const kCellIdentifier = @"Cell";
// How much user has to scroll beyond the top of the tableView for the view to dismiss automatically.
static const CGFloat kAutoDismissOffset = 80.0f;
// Offset at which there's a check if the user is flicking the tableView down.
static const CGFloat kFlickDownHandlingOffset = 20.0f;
static const CGFloat kFlickDownMinVelocity = 2000.0f;
// How much free space to leave at the top (above the tableView's contents) when there's a lot of elements. It makes this control look similar to the UIActionSheet.
static const CGFloat kTopSpaceMarginFraction = 0.0f;
// cancelButton's shadow height as the ratio to the cancelButton's height
static const CGFloat kSpaceDivide = 5.0f;
// width iPhone 7 Plus
static const CGFloat maxWidth = 414.0f;


/// Used for storing button configuration.
@interface AHKActionSheetItem : NSObject
@property (copy, nonatomic) NSString *title;
@property (strong, nonatomic) UIImage *image;
@property (nonatomic) AHKActionSheetButtonType type;
@property (strong, nonatomic) AHKActionSheetHandler handler;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic) CGFloat height;
@end

@implementation AHKActionSheetItem
@end



@interface AHKActionSheet() <UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate>
@property (strong, nonatomic) NSMutableArray *items;
@property (weak, nonatomic, readwrite) UIWindow *previousKeyWindow;
@property (strong, nonatomic) UIWindow *window;
@property (weak, nonatomic) UIImageView *blurredBackgroundView;
@property (weak, nonatomic) UITableView *tableView;
@property (weak, nonatomic) UIButton *cancelButton;
@property (weak, nonatomic) UIView *cancelButtonShadowView;
@end

@implementation AHKActionSheet

#pragma mark - Init

+ (void)initialize
{
    if (self != [AHKActionSheet class]) {
        return;
    }

    AHKActionSheet *appearance = [self appearance];
    [appearance setBlurRadius:0.0f];
    [appearance setBlurTintColor:[UIColor colorWithWhite:0.0f alpha:0.5f]];
    [appearance setBlurSaturationDeltaFactor:1.8f];
    [appearance setButtonHeight:50.0f];
    [appearance setSeparatorHeight:5.0f];
    [appearance setCancelButtonHeight:44.0f];
    [appearance setAutomaticallyTintButtonImages:@YES];
    [appearance setCancelButtonTextAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:17.0f], NSForegroundColorAttributeName : [UIColor darkGrayColor] }];
    [appearance setButtonTextAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:17.0f]}];
    [appearance setDisableButtonTextAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:17.0f]}];
    [appearance setDestructiveButtonTextAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:17.0f], NSForegroundColorAttributeName : [UIColor redColor] }];
    [appearance setTitleTextAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:14.0f], NSForegroundColorAttributeName : [UIColor grayColor] }];
    [appearance setCancelOnPanGestureEnabled:@(NO)];
    [appearance setCancelOnTapEmptyAreaEnabled:@(YES)];
    [appearance setAnimationDuration:kDefaultAnimationDuration];
}

- (instancetype)initWithTitle:(NSString *)title
{
    self = [super init];

    if (self) {
        _title = [title copy];
        _cancelButtonTitle = @"Cancel";
    }

    return self;
}

- (instancetype)initWithView:(UIView *)view title:(NSString *)title
{
    self = [super init];
    
    if (self) {
        _title = [title copy];
        _cancelButtonTitle = @"Cancel";
        _view = view;
    }
    
    return self;
}

- (instancetype)init
{
    return [self initWithTitle:nil];
}

- (void)dealloc
{
    self.tableView.dataSource = nil;
    self.tableView.delegate = nil;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)[self.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    
    if (cell == nil)
        cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier forIndexPath:indexPath];
    
    //cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    AHKActionSheetItem *item = self.items[(NSUInteger)indexPath.row];

    NSDictionary *attributes = nil;
    switch (item.type)
    {
        case AHKActionSheetButtonTypeDefault:
            attributes = self.buttonTextAttributes;
            break;
        case AHKActionSheetButtonTypeDisabled:
            attributes = self.disableButtonTextAttributes;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        case AHKActionSheetButtonTypeDestructive:
            attributes = self.destructiveButtonTextAttributes;
            break;
        case AHKActionSheetButtonTypeEncrypted:
            attributes = self.encryptedButtonTextAttributes;
            break;
    }
    
    UIImageView *imageView;
    
    if (item.type == AHKActionSheetButtonTypeDisabled) {
        
        imageView = [[UIImageView alloc]initWithFrame:CGRectMake(15, _buttonHeight/2 - (30/2), 30, 30)];
        imageView.backgroundColor = [UIColor clearColor];
        [imageView setImage:item.image];
        
    } else {
        
        imageView = [[UIImageView alloc]initWithFrame:CGRectMake(15, _buttonHeight/2 - (25/2), 25, 25)];
        
        BOOL useTemplateMode = [UIImage instancesRespondToSelector:@selector(imageWithRenderingMode:)] && [self.automaticallyTintButtonImages boolValue];

        imageView.image = useTemplateMode ? [item.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : item.image;
        
        if ([UIImageView instancesRespondToSelector:@selector(tintColor)]){
            imageView.tintColor = attributes[NSForegroundColorAttributeName] ? attributes[NSForegroundColorAttributeName] : [UIColor blackColor];
        }
    }
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(cell.frame.size.height + 5 , 0, cell.frame.size.width - cell.frame.size.height - 20, cell.frame.size.height)];
    NSAttributedString *attrTitle = [[NSAttributedString alloc] initWithString:item.title attributes:attributes];
    label.text =  [NSString stringWithFormat: @"test"];
    label.numberOfLines = 0;
    label.attributedText = attrTitle;
    label.textAlignment = [self.buttonTextCenteringEnabled boolValue] ? NSTextAlignmentCenter : NSTextAlignmentLeft;
    
    cell.backgroundColor = item.backgroundColor;
    cell.selectedBackgroundView = [self createBackgroundView:tableView cell:cell forRowAtIndexPath:indexPath color:self.separatorColor];
    
    for (UIView *subview in [cell.contentView subviews])
        [subview removeFromSuperview];
    
    [cell.contentView addSubview:imageView];
    [cell.contentView addSubview:label];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AHKActionSheetItem *item = self.items[(NSUInteger)indexPath.row];
    
    if (item.type != AHKActionSheetButtonTypeDisabled) {
        [self dismissAnimated:YES duration:self.animationDuration completion:item.handler];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AHKActionSheetItem *item = self.items[(NSUInteger)indexPath.row];
    return item.height;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    AHKActionSheetItem *item = self.items[(NSUInteger)indexPath.row];
    
    cell.backgroundView = [self createBackgroundView:tableView cell:cell forRowAtIndexPath:indexPath color:item.backgroundColor];
}

- (UIView *)createBackgroundView:(UITableView *)tableView cell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath color:(UIColor *)color
{
    CGFloat cornerRadius = 10.f;
    cell.backgroundColor = UIColor.clearColor;
    CAShapeLayer *layer = [[CAShapeLayer alloc] init];
    CGMutablePathRef pathRef = CGPathCreateMutable();
    CGRect bounds = CGRectInset(cell.bounds, 10, 0);
    BOOL addLine = NO;
    
    if (indexPath.row == 0 && indexPath.row == [tableView numberOfRowsInSection:indexPath.section]-1) {
        CGPathAddRoundedRect(pathRef, nil, bounds, cornerRadius, cornerRadius);
    } else if (indexPath.row == 0) {
        CGPathMoveToPoint(pathRef, nil, CGRectGetMinX(bounds), CGRectGetMaxY(bounds));
        CGPathAddArcToPoint(pathRef, nil, CGRectGetMinX(bounds), CGRectGetMinY(bounds), CGRectGetMidX(bounds), CGRectGetMinY(bounds), cornerRadius);
        CGPathAddArcToPoint(pathRef, nil, CGRectGetMaxX(bounds), CGRectGetMinY(bounds), CGRectGetMaxX(bounds), CGRectGetMidY(bounds), cornerRadius);
        CGPathAddLineToPoint(pathRef, nil, CGRectGetMaxX(bounds), CGRectGetMaxY(bounds));
        addLine = YES;
    } else if (indexPath.row == [tableView numberOfRowsInSection:indexPath.section]-1) {
        CGPathMoveToPoint(pathRef, nil, CGRectGetMinX(bounds), CGRectGetMinY(bounds));
        CGPathAddArcToPoint(pathRef, nil, CGRectGetMinX(bounds), CGRectGetMaxY(bounds), CGRectGetMidX(bounds), CGRectGetMaxY(bounds), cornerRadius);
        CGPathAddArcToPoint(pathRef, nil, CGRectGetMaxX(bounds), CGRectGetMaxY(bounds), CGRectGetMaxX(bounds), CGRectGetMidY(bounds), cornerRadius);
        CGPathAddLineToPoint(pathRef, nil, CGRectGetMaxX(bounds), CGRectGetMinY(bounds));
    } else {
        CGPathAddRect(pathRef, nil, bounds);
        addLine = YES;
    }
    
    if (addLine == YES) {
        CALayer *lineLayer = [[CALayer alloc] init];
        CGFloat lineHeight = (1.f / [UIScreen mainScreen].scale);
        lineLayer.frame = CGRectMake(CGRectGetMinX(bounds), bounds.size.height-lineHeight, bounds.size.width, lineHeight);
        lineLayer.backgroundColor = tableView.separatorColor.CGColor;
        [layer addSublayer:lineLayer];
    }

    layer.path = pathRef;
    CFRelease(pathRef);
    layer.fillColor = color.CGColor;

    UIView *testView = [[UIView alloc] initWithFrame:bounds];
    [testView.layer insertSublayer:layer atIndex:0];
    testView.backgroundColor = UIColor.clearColor;

    return testView;
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (![self.cancelOnPanGestureEnabled boolValue]) {
        return;
    }

    [self fadeBlursOnScrollToTop];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (![self.cancelOnPanGestureEnabled boolValue]) {
        return;
    }

    CGPoint scrollVelocity = [scrollView.panGestureRecognizer velocityInView:self];

    BOOL viewWasFlickedDown = scrollVelocity.y > kFlickDownMinVelocity && scrollView.contentOffset.y < -self.tableView.contentInset.top - kFlickDownHandlingOffset;
    BOOL shouldSlideDown = scrollView.contentOffset.y < -self.tableView.contentInset.top - kAutoDismissOffset;
    if (viewWasFlickedDown) {
        // use a shorter duration for a flick down animation
        static const NSTimeInterval duration = 0.2f;
        [self dismissAnimated:YES duration:duration completion:self.cancelHandler];
    } else if (shouldSlideDown) {
        [self dismissAnimated:YES duration:self.animationDuration completion:self.cancelHandler];
    }
}

#pragma mark - Properties

- (NSMutableArray *)items
{
    if (!_items) {
        _items = [NSMutableArray array];
    }

    return _items;
}

#pragma mark - Actions

- (void)cancelButtonTapped:(id)sender
{
    [self dismissAnimated:YES duration:self.animationDuration completion:self.cancelHandler];
}

#pragma mark - Public

- (void)addButtonWithTitle:(NSString *)title image:(UIImage *)image backgroundColor:(UIColor *)backgroundColor height:(CGFloat)height type:(AHKActionSheetButtonType)type handler:(AHKActionSheetHandler)handler
{
    AHKActionSheetItem *item = [[AHKActionSheetItem alloc] init];
    item.title = title;
    item.image = image;
    item.backgroundColor = backgroundColor;
    item.height = height;
    item.type = type;
    item.handler = handler;
    [self.items addObject:item];
}

- (void)show
{
    if ([self isVisible]) {
        return;
    }

    self.previousKeyWindow = [UIApplication sharedApplication].keyWindow;
    UIImage *previousKeyWindowSnapshot = [self.previousKeyWindow ahk_snapshot];

    [self setUpNewWindow];
    [self setUpBlurredBackgroundWithSnapshot:previousKeyWindowSnapshot];
    [self setUpCancelButton];
    [self setUpTableView];
    
    if (self.cancelOnTapEmptyAreaEnabled.boolValue) {
        [self setUpCancelTapGestureForView:self.tableView];
    }
    
    CGFloat slideDownMinOffset = (CGFloat)fmin(CGRectGetHeight(self.frame) + self.tableView.contentOffset.y, CGRectGetHeight(self.frame));
    self.tableView.transform = CGAffineTransformMakeTranslation(0, slideDownMinOffset);

    void(^immediateAnimations)(void) = ^(void) {
        self.blurredBackgroundView.alpha = 1.0f;
    };

    void(^delayedAnimations)(void) = ^(void) {
        
        CGFloat width = CGRectGetWidth(self.bounds);
        if (width > maxWidth) width = maxWidth;
        
        self.cancelButton.frame = CGRectMake(10 + (CGRectGetWidth(self.bounds)/2 - width/2), CGRectGetMaxY(self.bounds) - self.cancelButtonHeight, width - 20, self.cancelButtonHeight - kSpaceDivide);
    
        // Corner Radius
        self.cancelButton.layer.cornerRadius = 10;
        self.cancelButton.clipsToBounds = YES;
        
        // Add White color background
        self.cancelButton.backgroundColor = [UIColor whiteColor];
        
        self.tableView.transform = CGAffineTransformMakeTranslation(0, 0);

        // manual calculation of table's contentSize.height
        CGFloat tableContentHeight = 0;
        
        for (AHKActionSheetItem *item in self.items) {
            tableContentHeight = tableContentHeight + item.height;
        }
        tableContentHeight = tableContentHeight + self.separatorHeight + CGRectGetHeight(self.tableView.tableHeaderView.frame);
        
        CGFloat topInset;
        BOOL buttonsFitInWithoutScrolling = tableContentHeight < CGRectGetHeight(self.tableView.frame) * (1.0 - kTopSpaceMarginFraction);
        if (buttonsFitInWithoutScrolling) {
            // show all buttons if there isn't many
            topInset = CGRectGetHeight(self.tableView.frame) - tableContentHeight;
        } else {
            // leave an empty space on the top to make the control look similar to UIActionSheet
            topInset = (CGFloat)round(CGRectGetHeight(self.tableView.frame) * kTopSpaceMarginFraction);
        }
        
        self.tableView.contentInset = UIEdgeInsetsMake(topInset, 0, 0, 0);

        self.tableView.bounces = [self.cancelOnPanGestureEnabled boolValue] || !buttonsFitInWithoutScrolling;
    };

    if ([UIView respondsToSelector:@selector(animateKeyframesWithDuration:delay:options:animations:completion:)]){
        // Animate sliding in tableView and cancel button with keyframe animation for a nicer effect.
        [UIView animateKeyframesWithDuration:self.animationDuration delay:0 options:0 animations:^{
            immediateAnimations();

            [UIView addKeyframeWithRelativeStartTime:0.3f relativeDuration:0.7f animations:^{
                delayedAnimations();
            }];
        } completion:nil];

    } else {

        [UIView animateWithDuration:self.animationDuration animations:^{
            immediateAnimations();
            delayedAnimations();
        }];
    }
}

- (void)dismissAnimated:(BOOL)animated
{
    [self dismissAnimated:animated duration:self.animationDuration completion:self.cancelHandler];
}

#pragma mark - Private

- (BOOL)isVisible
{
    // action sheet is visible iff it's associated with a window
    return !!self.window;
}

- (void)dismissAnimated:(BOOL)animated duration:(NSTimeInterval)duration completion:(AHKActionSheetHandler)completionHandler
{
    if (![self isVisible]) {
        return;
    }

    // delegate isn't needed anymore because tableView will be hidden (and we don't want delegate methods to be called now)
    self.tableView.delegate = nil;
    self.tableView.userInteractionEnabled = NO;
    // keep the table from scrolling back up
    self.tableView.contentInset = UIEdgeInsetsMake(-self.tableView.contentOffset.y, 0, 0, 0);

    void(^tearDownView)(void) = ^(void) {
        // remove the views because it's easiest to just recreate them if the action sheet is shown again
        for (UIView *view in @[self.tableView, self.cancelButton, self.blurredBackgroundView, self.window]) {
            [view removeFromSuperview];
        }

        self.window = nil;
        [self.previousKeyWindow makeKeyAndVisible];

        if (completionHandler) {
            completionHandler(self);
        }
    };

    if (animated) {
        // animate sliding down tableView and cancelButton.
        [UIView animateWithDuration:duration animations:^{
            self.blurredBackgroundView.alpha = 0.0f;
            self.cancelButton.transform = CGAffineTransformTranslate(self.cancelButton.transform, 0, self.cancelButtonHeight - kSpaceDivide);
            self.cancelButtonShadowView.alpha = 0.0f;

            // Shortest shift of position sufficient to hide all tableView contents below the bottom margin.
            // contentInset isn't used here (unlike in -show) because it caused weird problems with animations in some cases.
            CGFloat slideDownMinOffset = (CGFloat)fmin(CGRectGetHeight(self.frame) + self.tableView.contentOffset.y, CGRectGetHeight(self.frame));
            self.tableView.transform = CGAffineTransformMakeTranslation(0, slideDownMinOffset);
        } completion:^(BOOL finished) {
            tearDownView();
        }];
    } else {
        tearDownView();
    }
}

- (void)setUpNewWindow
{
    AHKActionSheetViewController *actionSheetVC = [[AHKActionSheetViewController alloc] initWithNibName:nil bundle:nil];
    actionSheetVC.actionSheet = self;

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.window.opaque = NO;
    self.window.rootViewController = actionSheetVC;
    [self.window makeKeyAndVisible];
}

- (void)setUpBlurredBackgroundWithSnapshot:(UIImage *)previousKeyWindowSnapshot
{
    UIImage *blurredViewSnapshot = [previousKeyWindowSnapshot
                                    ahk_applyBlurWithRadius:self.blurRadius
                                    tintColor:self.blurTintColor
                                    saturationDeltaFactor:self.blurSaturationDeltaFactor
                                    maskImage:nil];
    UIImageView *backgroundView = [[UIImageView alloc] initWithImage:blurredViewSnapshot];
    backgroundView.frame = self.bounds;
    backgroundView.alpha = 0.0f;
    [self addSubview:backgroundView];
    self.blurredBackgroundView = backgroundView;
}

- (void)setUpCancelTapGestureForView:(UIView*)view {
    UITapGestureRecognizer *cancelTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cancelButtonTapped:)];
    cancelTap.delegate = self;
    [view addGestureRecognizer:cancelTap];
}

- (void)setUpCancelButton
{
    UIButton *cancelButton;
    
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width > maxWidth) width = maxWidth;

    
    // It's hard to check if UIButtonTypeSystem enumeration exists, so we're checking existence of another method that was introduced in iOS 7.
    if ([UIView instancesRespondToSelector:@selector(tintAdjustmentMode)]) {
        cancelButton= [UIButton buttonWithType:UIButtonTypeSystem];
    } else {
        cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    }

    NSAttributedString *attrTitle = [[NSAttributedString alloc] initWithString:self.cancelButtonTitle attributes:self.cancelButtonTextAttributes];
    
    [cancelButton setAttributedTitle:attrTitle forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    cancelButton.frame = CGRectMake(10 + (CGRectGetWidth(self.bounds)/2 - width/2), CGRectGetMaxY(self.bounds) - self.cancelButtonHeight, width - 20, self.cancelButtonHeight - kSpaceDivide);
    
    // move the button below the screen (ready to be animated -show)
    cancelButton.transform = CGAffineTransformMakeTranslation(0, self.cancelButtonHeight - kSpaceDivide);
    cancelButton.clipsToBounds = YES;
    [self addSubview:cancelButton];

    self.cancelButton = cancelButton;
}

- (void)setUpTableView
{
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width > maxWidth) width = maxWidth;
    
    CGRect statusBarViewRect = [self convertRect:[UIApplication sharedApplication].statusBarFrame fromView:nil];
    CGFloat statusBarHeight = CGRectGetHeight(statusBarViewRect);
    
    CGRect frame = CGRectMake((CGRectGetWidth(self.bounds)/2 - width/2), statusBarHeight, width, CGRectGetHeight(self.bounds) - statusBarHeight - self.cancelButtonHeight - self.separatorHeight);

    UITableView *tableView = [[UITableView alloc] initWithFrame:frame];
    
    tableView.backgroundColor = [UIColor clearColor];
    tableView.showsVerticalScrollIndicator = NO;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    if (self.separatorColor) {
        tableView.separatorColor = self.separatorColor;
    }
    
    tableView.delegate = self;
    tableView.dataSource = self;
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellIdentifier];
    [self insertSubview:tableView aboveSubview:self.blurredBackgroundView];
    // move the content below the screen, ready to be animated in -show
    tableView.contentInset = UIEdgeInsetsMake(CGRectGetHeight(self.bounds), 0, 0, 0);
    // removes separators below the footer (between empty cells)
    tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

    self.tableView = tableView;
}

- (void)fadeBlursOnScrollToTop
{
    if (self.tableView.isDragging || self.tableView.isDecelerating) {
        CGFloat alphaWithoutBounds = 1.0f - ( -(self.tableView.contentInset.top + self.tableView.contentOffset.y) / kBlurFadeRangeSize);
        // limit alpha to the interval [0, 1]
        CGFloat alpha = (CGFloat)fmax(fmin(alphaWithoutBounds, 1.0f), 0.0f);
        self.blurredBackgroundView.alpha = alpha;
        self.cancelButtonShadowView.alpha = alpha;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // If the view that is touched is not the view associated with this view's table view, but
    // is one of the sub-views, we should not recognize the touch.
    // Original source: http://stackoverflow.com/questions/10755566/how-to-know-uitableview-is-pressed-when-empty
    if (touch.view != self.tableView && [touch.view isDescendantOfView:self.tableView]) {
        return NO;
    }
    return YES;
}

@end
