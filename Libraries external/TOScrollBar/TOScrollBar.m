//
//  TOScrollBar.m
//
//  Copyright 2016-2017 Timothy Oliver. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "TOScrollBar.h"
#import "UIScrollView+TOScrollBar.h"
#import "TOScrollBarGestureRecognizer.h"

/** Default values for the scroll bar */
static const CGFloat kTOScrollBarTrackWidth      = 2.0f;     // The default width of the scrollable space indicator
static const CGFloat kTOScrollBarHandleWidth     = 4.0f;     // The default width of the handle control
static const CGFloat kTOScrollBarEdgeInset       = 7.5f;     // The distance from the edge of the view to the center of the track
static const CGFloat kTOScrollBarHandleMinHeight = 64.0f;    // The minimum usable size to which the handle can shrink
static const CGFloat kTOScrollBarWidth           = 30.0f;    // The width of this control (44 is minimum recommended tapping space)
static const CGFloat kTOScrollBarVerticalPadding = 10.0f;    // The default padding at the top and bottom of the view
static const CGFloat kTOScrollBarMinimumContentScale = 5.0f; // The minimum scale of the content view before showing the scroll view is necessary

/************************************************************************/

// A struct to hold the scroll view's previous state before this bar was applied
struct TOScrollBarScrollViewState {
    BOOL showsVerticalScrollIndicator;
};
typedef struct TOScrollBarScrollViewState TOScrollBarScrollViewState;

/************************************************************************/
// Private interface exposure for scroll view category

@interface UIScrollView () //TOScrollBar
- (void)setTo_scrollBar:(TOScrollBar *)scrollBar;
@end

/************************************************************************/

@interface TOScrollBar () <UIGestureRecognizerDelegate> {
    TOScrollBarScrollViewState _scrollViewState;
}

@property (nonatomic, weak, readwrite) UIScrollView *scrollView;   // The parent scroll view in which we belong

@property (nonatomic, assign) BOOL userHidden;          // View was explicitly hidden by the user as opposed to us

@property (nonatomic, strong) UIImageView *trackView;   // The track indicating the scrollable distance
@property (nonatomic, strong) UIImageView *handleView;  // The handle that may be dragged in the scroll bar

@property (nonatomic, assign, readwrite) BOOL dragging; // The user is presently dragging the handle
@property (nonatomic, assign) CGFloat yOffset;          // The offset from the center of the thumb

@property (nonatomic, assign) CGFloat originalYOffset;  // The original placement of the scroll bar when the user started dragging
@property (nonatomic, assign) CGFloat originalHeight;   // The original height of the scroll bar when the user started dragging
@property (nonatomic, assign) CGFloat originalTopInset; // The original safe area inset of the scroll bar when the user started dragging

@property (nonatomic, assign) CGFloat horizontalOffset; // The horizontal offset when the edge inset is too small for the touch region

@property (nonatomic, assign) BOOL disabled;            // Disabled when there's not enough scroll content to merit showing this

@property (nonatomic, strong) UIImpactFeedbackGenerator *feedbackGenerator; // Taptic feedback for iPhone 7 and above

@property (nonatomic, strong) TOScrollBarGestureRecognizer *gestureRecognizer; // Our custom recognizer for handling user interactions with the scroll bar

@end

/************************************************************************/

@implementation TOScrollBar

#pragma mark - Class Creation -

- (instancetype)initWithStyle:(TOScrollBarStyle)style
{
    if (self = [super initWithFrame:CGRectZero]) {
        _style = style;
        [self setUpInitialProperties];
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setUpInitialProperties];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self setUpInitialProperties];
    }

    return self;
}

#pragma mark - Set-up -

- (void)setUpInitialProperties
{
    _trackWidth  = kTOScrollBarTrackWidth;
    _handleWidth = kTOScrollBarHandleWidth;
    _edgeInset   = kTOScrollBarEdgeInset;
    _handleMinimiumHeight = kTOScrollBarHandleMinHeight;
    _minimumContentHeightScale = kTOScrollBarMinimumContentScale;
    _verticalInset = UIEdgeInsetsMake(kTOScrollBarVerticalPadding, 0.0f, kTOScrollBarVerticalPadding, 0.0f);
    _feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    _gestureRecognizer = [[TOScrollBarGestureRecognizer alloc] initWithTarget:self action:@selector(scrollBarGestureRecognized:)];
}

- (void)setUpViews
{
    if (self.trackView || self.handleView) {
        return;
    }

    self.backgroundColor = [UIColor clearColor];

    // Create and add the track view
    self.trackView = [[UIImageView alloc] initWithImage:[TOScrollBar verticalCapsuleImageWithWidth:self.trackWidth]];
    [self addSubview:self.trackView];

    // Add the handle view
    self.handleView = [[UIImageView alloc] initWithImage:[TOScrollBar verticalCapsuleImageWithWidth:self.handleWidth]];
    [self addSubview:self.handleView];

    // Add the initial styling
    [self configureViewsForStyle:self.style];
    
    // Add gesture recognizer
    [self addGestureRecognizer:self.gestureRecognizer];
}

- (void)configureViewsForStyle:(TOScrollBarStyle)style
{
    BOOL dark = (style == TOScrollBarStyleDark);

    CGFloat whiteColor = 0.0f;
    if (dark) {
        whiteColor = 1.0f;
    }
    self.trackView.tintColor = [UIColor colorWithWhite:whiteColor alpha:0.1f];
}

- (void)dealloc
{
    [self restoreScrollView:self.scrollView];
}

- (void)configureScrollView:(UIScrollView *)scrollView
{
    if (scrollView == nil) {
        return;
    }

    // Make a copy of the scroll view's state and then configure
    _scrollViewState.showsVerticalScrollIndicator = self.scrollView.showsVerticalScrollIndicator;
    scrollView.showsVerticalScrollIndicator = NO;

    //Key-value Observers
    [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
    [scrollView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)restoreScrollView:(UIScrollView *)scrollView
{
    if (scrollView == nil) {
        return;
    }

    // Restore the scroll view's state
    scrollView.showsVerticalScrollIndicator = _scrollView.showsVerticalScrollIndicator;

    // Remove the observers
    [scrollView removeObserver:self forKeyPath:@"contentOffset"];
    [scrollView removeObserver:self forKeyPath:@"contentSize"];
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    [self setUpViews];
}

#pragma mark - Content Layout -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    [self updateStateForScrollView];
    if (self.hidden) { return; }
    [self layoutInScrollView];
    [self setNeedsLayout];
}

- (CGFloat)heightOfHandleForContentSize
{
    if (_scrollView == nil) {
        return _handleMinimiumHeight;
    }

    CGFloat heightRatio = self.scrollView.frame.size.height / self.scrollView.contentSize.height;
    CGFloat height = self.frame.size.height * heightRatio;

    return MAX(floorf(height), _handleMinimiumHeight);
}

- (void)updateStateForScrollView
{
    CGRect frame = _scrollView.frame;
    CGSize contentSize = _scrollView.contentSize;
    self.disabled = (contentSize.height / frame.size.height) < _minimumContentHeightScale;
    [self setHidden:(self.disabled || self.userHidden) animated:NO];
}

- (void)layoutInScrollView
{
    CGRect scrollViewFrame = _scrollView.frame;
    UIEdgeInsets insets    = _scrollView.contentInset;
    CGPoint contentOffset  = _scrollView.contentOffset;
    CGFloat halfWidth      = (kTOScrollBarWidth * 0.5f);

    if (@available(iOS 11.0, *)) {
        insets = _scrollView.adjustedContentInset;
    }

    // Contract the usable space by the scroll view's content inset (eg navigation/tool bars)
    scrollViewFrame.size.height -= (insets.top + insets.bottom);

    CGFloat largeTitleDelta = 0.0f;
    if (_insetForLargeTitles) {
        largeTitleDelta = fabs(MIN(insets.top + contentOffset.y, 0.0f));
    }

    // Work out the final height be further contracting by the padding
    CGFloat height = (scrollViewFrame.size.height - (_verticalInset.top + _verticalInset.bottom)) - largeTitleDelta;

    // Work out how much we have to offset the track by to make sure all of the parent view
    // is visible at the edge of the screen (Or else we'll be unable to tap properly)
    CGFloat horizontalOffset = halfWidth - _edgeInset;
    self.horizontalOffset = (horizontalOffset > 0.0f) ? horizontalOffset : 0.0f;

    // Work out the frame for the scroll view
    CGRect frame = CGRectZero;
    
    // Size
    frame.size.width = kTOScrollBarWidth;
    frame.size.height = (_dragging ? _originalHeight : height);
    
    // Horizontal placement
    frame.origin.x = scrollViewFrame.size.width - (_edgeInset + halfWidth);
    if (@available(iOS 11.0, *)) { frame.origin.x -= _scrollView.safeAreaInsets.right; }
    frame.origin.x = MIN(frame.origin.x, scrollViewFrame.size.width - kTOScrollBarWidth);

    // Vertical placement in scroll view
    if (_dragging) {
        frame.origin.y = _originalYOffset;
    }
    else {
        frame.origin.y = _verticalInset.top;
        frame.origin.y += insets.top;
        frame.origin.y += largeTitleDelta;
    }
    frame.origin.y += contentOffset.y;

    // Set the frame
    self.frame = frame;
    
    // Bring the scroll bar to the front in case other subviews were subsequently added over it
    [self.superview bringSubviewToFront:self];
}

- (void)layoutSubviews
{
    CGRect frame = self.frame;

    // The frame of the track
    CGRect trackFrame = CGRectZero;
    trackFrame.size.width = _trackWidth;
    trackFrame.size.height = frame.size.height;
    trackFrame.origin.x = ceilf(((frame.size.width - _trackWidth) * 0.5f) + _horizontalOffset);
    self.trackView.frame = CGRectIntegral(trackFrame);

    // Don't handle automatic layout when dragging; we'll do that manually elsewhere
    if (self.dragging || self.disabled) {
        return;
    }

    // The frame of the handle
    CGRect handleFrame = CGRectZero;
    handleFrame.size.width = _handleWidth;
    handleFrame.size.height = [self heightOfHandleForContentSize];
    handleFrame.origin.x = ceilf(((frame.size.width - _handleWidth) * 0.5f) + _horizontalOffset);

    // Work out the y offset of the handle
    UIEdgeInsets contentInset = _scrollView.contentInset;
    if (@available(iOS 11.0, *)) {
        contentInset = _scrollView.safeAreaInsets;
    }

    CGPoint contentOffset     = _scrollView.contentOffset;
    CGSize contentSize        = _scrollView.contentSize;
    CGRect scrollViewFrame    = _scrollView.frame;

    CGFloat scrollableHeight = (contentSize.height + contentInset.top + contentInset.bottom) - scrollViewFrame.size.height;
    CGFloat scrollProgress = (contentOffset.y + contentInset.top) / scrollableHeight;
    handleFrame.origin.y = (frame.size.height - handleFrame.size.height) * scrollProgress;

    // If the scroll view expanded beyond its scrollable range, shrink the handle to match the rubber band effect
    if (contentOffset.y < -contentInset.top) { // The top
        handleFrame.size.height -= (-contentOffset.y - contentInset.top);
        handleFrame.size.height = MAX(handleFrame.size.height, (_trackWidth * 2 + 2));
    }
    else if (contentOffset.y + scrollViewFrame.size.height > contentSize.height + contentInset.bottom) { // The bottom
        CGFloat adjustedContentOffset = contentOffset.y + scrollViewFrame.size.height;
        CGFloat delta = adjustedContentOffset - (contentSize.height + contentInset.bottom);
        handleFrame.size.height -= delta;
        handleFrame.size.height = MAX(handleFrame.size.height, (_trackWidth * 2 + 2));
        handleFrame.origin.y = frame.size.height - handleFrame.size.height;
    }

    // Clamp to the bounds of the frame
    handleFrame.origin.y = MAX(handleFrame.origin.y, 0.0f);
    handleFrame.origin.y = MIN(handleFrame.origin.y, (frame.size.height - handleFrame.size.height));

    self.handleView.frame = handleFrame;
}

- (void)setScrollYOffsetForHandleYOffset:(CGFloat)yOffset animated:(BOOL)animated
{
    CGFloat heightRange = _trackView.frame.size.height - _handleView.frame.size.height;
    yOffset = MAX(0.0f, yOffset);
    yOffset = MIN(heightRange, yOffset);

    CGFloat positionRatio = yOffset / heightRange;

    CGRect frame       = _scrollView.frame;
    UIEdgeInsets inset = _scrollView.contentInset;
    CGSize contentSize = _scrollView.contentSize;

    if (@available(iOS 11.0, *)) {
        inset = _scrollView.adjustedContentInset;
    }
    inset.top = _originalTopInset;

    CGFloat totalScrollSize = (contentSize.height + inset.top + inset.bottom) - frame.size.height;
    CGFloat scrollOffset = totalScrollSize * positionRatio;
    scrollOffset -= inset.top;

    CGPoint contentOffset = _scrollView.contentOffset;
    contentOffset.y = scrollOffset;

    // Animate to help coax the large title navigation bar to behave
    if (@available(iOS 11.0, *)) {
        [UIView animateWithDuration:animated ? 0.1f : 0.00001f animations:^{
            [self.scrollView setContentOffset:contentOffset animated:NO];
        }];
    }
    else {
        [self.scrollView setContentOffset:contentOffset animated:NO];
    }
}

#pragma mark - Scroll View Integration -

- (void)addToScrollView:(UIScrollView *)scrollView
{
    if (scrollView == self.scrollView) {
        return;
    }

    // Restore the previous scroll view
    [self restoreScrollView:self.scrollView];

    // Assign the new scroll view
    self.scrollView = scrollView;

    // Apply the observers/settings to the new scroll view
    [self configureScrollView:scrollView];

    // Add the scroll bar to the scroll view's content view
    [self.scrollView addSubview:self];

    // Add ourselves as a property of the scroll view
    [self.scrollView setTo_scrollBar:self];

    // Begin layout
    [self layoutInScrollView];
}

- (void)removeFromScrollView
{
    [self restoreScrollView:self.scrollView];
    [self removeFromSuperview];
    [self.scrollView setTo_scrollBar:nil];
    self.scrollView = nil;
}

- (UIEdgeInsets)adjustedTableViewSeparatorInsetForInset:(UIEdgeInsets)inset
{
    inset.right = _edgeInset * 2.0f;
    return inset;
}

- (UIEdgeInsets)adjustedTableViewCellLayoutMarginsForMargins:(UIEdgeInsets)layoutMargins manualOffset:(CGFloat)offset
{
    layoutMargins.right = (_edgeInset * 2.0f) + 15.0f; // Magic system number is 20, but we can't infer that from here on time
    layoutMargins.right += offset;
    return layoutMargins;
}

#pragma mark - User Interaction -
- (void)scrollBarGestureRecognized:(TOScrollBarGestureRecognizer *)recognizer
{
    CGPoint touchPoint = [recognizer locationInView:self];
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            [self gestureBeganAtPoint:touchPoint];
            break;
        case UIGestureRecognizerStateChanged:
            [self gestureMovedToPoint:touchPoint];
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            [self gestureEnded];
            break;
        default:
            break;
    }
}

- (void)gestureBeganAtPoint:(CGPoint)touchPoint
{
    if (self.disabled) {
        return;
    }

    // Warm-up the feedback generator
    [_feedbackGenerator prepare];

    self.scrollView.scrollEnabled = NO;
    self.dragging = YES;

    // Capture the original position
    self.originalHeight = self.frame.size.height;
    self.originalYOffset = self.frame.origin.y - self.scrollView.contentOffset.y;

    if (@available(iOS 11.0, *)) {
        self.originalTopInset = _scrollView.adjustedContentInset.top;
    } else {
        self.originalTopInset = _scrollView.contentInset.top;
    }

    // Check if the user tapped inside the handle
    CGRect handleFrame = self.handleView.frame;
    if (touchPoint.y > (handleFrame.origin.y - 20) &&
        touchPoint.y < handleFrame.origin.y + (handleFrame.size.height + 20))
    {
        self.yOffset = (touchPoint.y - handleFrame.origin.y);
        return;
    }

	if (!self.handleExclusiveInteractionEnabled) {
		// User tapped somewhere else, animate the handle to that point
		CGFloat halfHeight = (handleFrame.size.height * 0.5f);

		CGFloat destinationYOffset = touchPoint.y - halfHeight;
		destinationYOffset = MAX(0.0f, destinationYOffset);
		destinationYOffset = MIN(self.frame.size.height - halfHeight, destinationYOffset);

		self.yOffset = (touchPoint.y - destinationYOffset);
		handleFrame.origin.y = destinationYOffset;

		[UIView animateWithDuration:0.2f
							  delay:0.0f
			 usingSpringWithDamping:1.0f
			  initialSpringVelocity:0.1f options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
							 self.handleView.frame = handleFrame;
						 } completion:nil];

		[self setScrollYOffsetForHandleYOffset:floorf(destinationYOffset) animated:NO];
	}
}

- (void)gestureMovedToPoint:(CGPoint)touchPoint
{
    if (self.disabled) {
        return;
    }

    CGFloat delta = 0.0f;
    CGRect handleFrame = _handleView.frame;
    CGRect trackFrame = _trackView.frame;
    CGFloat minimumY = 0.0f;
    CGFloat maximumY = trackFrame.size.height - handleFrame.size.height;

	if (self.handleExclusiveInteractionEnabled) {
		if (touchPoint.y < (handleFrame.origin.y - 20) ||
			touchPoint.y > handleFrame.origin.y + (handleFrame.size.height + 20))
		{
			// This touch is not on the handle; eject.
			return;
		}
	}
	
    // Apply the updated Y value plus the previous offset
    delta = handleFrame.origin.y;
    handleFrame.origin.y = touchPoint.y - _yOffset;

    //Clamp the handle, and adjust the y offset to counter going outside the bounds
    if (handleFrame.origin.y < minimumY) {
        _yOffset += handleFrame.origin.y;
        _yOffset = MAX(minimumY, _yOffset);
        handleFrame.origin.y = minimumY;
    }
    else if (handleFrame.origin.y > maximumY) {
        CGFloat handleOverflow = CGRectGetMaxY(handleFrame) - trackFrame.size.height;
        _yOffset += handleOverflow;
        _yOffset = MIN(self.yOffset, handleFrame.size.height);
        handleFrame.origin.y = MIN(handleFrame.origin.y, maximumY);
    }

    _handleView.frame = handleFrame;

    delta -= handleFrame.origin.y;
    delta = fabs(delta);

    // If the delta is not 0.0, but we're at either extreme,
    // this is first frame we've since reaching that point.
    // Play a taptic feedback impact
    if (delta > FLT_EPSILON && (CGRectGetMinY(handleFrame) < FLT_EPSILON || CGRectGetMinY(handleFrame) >= maximumY - FLT_EPSILON)) {
        [_feedbackGenerator impactOccurred];
    }

    // If the user is doing really granualar swipes, add a subtle amount
    // of vertical animation so the scroll view isn't jumping on each frame
    [self setScrollYOffsetForHandleYOffset:floorf(handleFrame.origin.y) animated:NO]; //(delta < 0.51f)
}

- (void)gestureEnded
{
    self.scrollView.scrollEnabled = YES;
    self.dragging = NO;

    [UIView animateWithDuration:0.5f delay:0.0f usingSpringWithDamping:1.0f initialSpringVelocity:0.5f options:0 animations:^{
        [self layoutInScrollView];
        [self layoutIfNeeded];
    } completion:nil];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!self.handleExclusiveInteractionEnabled) {
		return [super pointInside:point withEvent:event];
	}
    else {
		CGFloat handleMinY = CGRectGetMinY(self.handleView.frame);
		CGFloat handleMaxY = CGRectGetMaxY(self.handleView.frame);
		return (0 <= point.x) && (handleMinY <= point.y) && (point.y <= handleMaxY);
	}
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *result = [super hitTest:point withEvent:event];

    if (self.disabled || self.dragging) {
        return result;
    }

    // If the user contacts the screen in a swiping motion,
    // the scroll view will automatically highjack the touch
    // event unless we explicitly override it here.

    self.scrollView.scrollEnabled = (result != self);
    return result;
}

#pragma mark - Accessors -
- (void)setStyle:(TOScrollBarStyle)style
{
    _style = style;
    [self configureViewsForStyle:style];
}

- (UIColor *)trackTintColor { return self.trackView.tintColor; }

- (void)setTrackTintColor:(UIColor *)trackTintColor
{
    self.trackView.tintColor = trackTintColor;
}

- (UIColor *)handleTintColor { return self.handleView.tintColor; }

- (void)setHandleTintColor:(UIColor *)handleTintColor
{
    self.handleView.tintColor = handleTintColor;
}

- (void)setHidden:(BOOL)hidden
{
    self.userHidden = hidden;
    [self setHidden:hidden animated:NO];
}

- (void)setHidden:(BOOL)hidden animated:(BOOL)animated
{
    // Override. It cannot be shown if it's disabled
    if (_disabled) {
        super.hidden = YES;
        return;
    }

    // Simply show or hide it if we're not animating
    if (animated == NO) {
        super.hidden = hidden;
        return;
    }

    // Show it if we're going to animate it
    if (self.hidden && hidden == NO) {
        super.hidden = NO;
        [self layoutInScrollView];
        [self setNeedsLayout];
    }

    CGRect fromFrame = self.frame;
    CGRect toFrame = self.frame;

    CGFloat widestElement = MAX(_trackWidth, _handleWidth);
    CGFloat hiddenOffset = fromFrame.origin.x + _edgeInset + (widestElement * 2.0f);
    if (hidden == NO) {
        fromFrame.origin.x = hiddenOffset;
    }
    else {
        toFrame.origin.x = hiddenOffset;
    }

    self.frame = fromFrame;
    [UIView animateWithDuration:0.3f
                          delay:0.0f
         usingSpringWithDamping:1.0f
          initialSpringVelocity:0.1f
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.frame = toFrame;
                     } completion:^(BOOL finished) {
                         super.hidden = hidden;
                     }];

}

#pragma mark - Image Generation -
+ (UIImage *)verticalCapsuleImageWithWidth:(CGFloat)width
{
    UIImage *image = nil;
    CGFloat radius = width * 0.5f;
    CGRect frame = (CGRect){0, 0, width+1, width+1};

    UIGraphicsBeginImageContextWithOptions(frame.size, NO, 0.0f);
    [[UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:radius] fill];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    image = [image resizableImageWithCapInsets:UIEdgeInsetsMake(radius, radius, radius, radius) resizingMode:UIImageResizingModeStretch];
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    return image;
}

@end
