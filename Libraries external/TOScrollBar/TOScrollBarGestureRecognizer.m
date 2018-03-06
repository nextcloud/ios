//
//  TOScrollBarGestureRecognizer.h
//
//  Copyright 2017 Timothy Oliver. All rights reserved.
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

#import "TOScrollBarGestureRecognizer.h"
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "TOScrollBar.h"

@interface TOScrollBarGestureRecognizer ()

@property (nonatomic, readonly) TOScrollBar *scrollBar; // The scroll bar this recognizer is attached to

@end

@implementation TOScrollBarGestureRecognizer

#pragma mark - Gesture Recognizer Filtering -
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer
{
    // Ensure that the pan gesture recognizer from the scroll view doesn't override the scroll bar
    UIView *view = preventedGestureRecognizer.view;
    if ([view isEqual:self.scrollBar.scrollView]) {
        return YES;
    }
    
    return NO;
}

#pragma mark - Touch Interaction -
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    self.state = UIGestureRecognizerStateBegan;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    self.state = UIGestureRecognizerStateChanged;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    self.state = UIGestureRecognizerStateEnded;
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    self.state = UIGestureRecognizerStateCancelled;
}

#pragma mark - Accessors -
- (TOScrollBar *)scrollBar
{
    if ([self.view isKindOfClass:[TOScrollBar class]] == NO) { return nil; }
    return (TOScrollBar *)self.view;
}

@end
