#import "NSLayoutConstraint+PKDownloadButton.h"

@implementation NSLayoutConstraint (PKDownloadButton)

+ (NSArray *)constraintsForWrappedSubview:(UIView *)view withInsets:(UIEdgeInsets)insets {
    NSArray *horizontalConstraints = [self horizontalConstraintsForWrappedSubview:view withInsets:insets];
    NSArray *verticalConstraints = [self verticalConstraintsForWrappedSubview:view withInsets:insets];
    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:[horizontalConstraints count] + [verticalConstraints count]];
    [resultArray addObjectsFromArray:horizontalConstraints];
    [resultArray addObjectsFromArray:verticalConstraints];
    return resultArray;
}

+ (NSArray *)horizontalConstraintsForWrappedSubview:(UIView *)view withInsets:(UIEdgeInsets)insets {
    NSString *horizontalConstraintsFormat = [NSString stringWithFormat:@"H:|-(%d)-[view]-(%d)-|",
                                             (int)insets.left,
                                             (int)roundf(insets.right)];
    NSArray *horizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:horizontalConstraintsFormat
                                                                             options:0
                                                                             metrics:nil
                                                                               views:NSDictionaryOfVariableBindings(view)];
    return horizontalConstraints;
}

+ (NSArray *)verticalConstraintsForWrappedSubview:(UIView *)view withInsets:(UIEdgeInsets)insets {
    NSString *verticalConstraintsFormat = [NSString stringWithFormat:@"V:|-(%d)-[view]-(%d)-|", (int)insets.top, (int)insets.bottom];
    NSArray *verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:verticalConstraintsFormat
                                                                           options:0
                                                                           metrics:nil
                                                                             views:NSDictionaryOfVariableBindings(view)];
    return verticalConstraints;
}

+ (NSLayoutConstraint *)constraintForView:(UIView *)view withWidth:(CGFloat)width {
    return [NSLayoutConstraint constraintWithItem:view
                                        attribute:NSLayoutAttributeWidth
                                        relatedBy:NSLayoutRelationEqual
                                           toItem:nil
                                        attribute:NSLayoutAttributeNotAnAttribute
                                       multiplier:1.0
                                         constant:width];
}

+ (NSLayoutConstraint *)constraintForView:(UIView *)view withHeight:(CGFloat)height {
    return [NSLayoutConstraint constraintWithItem:view
                                        attribute:NSLayoutAttributeHeight
                                        relatedBy:NSLayoutRelationEqual
                                           toItem:nil
                                        attribute:NSLayoutAttributeNotAnAttribute
                                       multiplier:1.0
                                         constant:height];
}

+ (NSArray *)constraintsForView:(UIView *)view withSize:(CGSize)size {
    NSLayoutConstraint *width = [NSLayoutConstraint constraintForView:view
                                                            withWidth:size.width];
    NSLayoutConstraint *height = [NSLayoutConstraint constraintForView:view
                                                             withHeight:size.height];
    return @[width, height];
}

+ (NSArray *)constraintsWithVisualFormat:(NSString *)format views:(NSDictionary *)views {
    return [self constraintsWithVisualFormat:format options:0 metrics:nil views:views];
}

+ (NSLayoutConstraint *)constraintForCenterByXView:(UIView *)overlay withView:(UIView *)view {
    return [NSLayoutConstraint constraintWithItem:overlay
                                          attribute:NSLayoutAttributeCenterX
                                          relatedBy:NSLayoutRelationEqual
                                             toItem:view
                                          attribute:NSLayoutAttributeCenterX
                                         multiplier:1.0
                                           constant:0.0];
}

+ (NSLayoutConstraint *)constraintForCenterByYView:(UIView *)overlay withView:(UIView *)view {
    return [NSLayoutConstraint constraintWithItem:overlay
                                          attribute:NSLayoutAttributeCenterY
                                          relatedBy:NSLayoutRelationEqual
                                             toItem:view
                                          attribute:NSLayoutAttributeCenterY
                                         multiplier:1.0
                                           constant:0.0];
}

+ (NSArray *)constraintsForCenterView:(UIView *)overlay {
    return [self constraintsForCenterView:overlay withView:overlay.superview];
}

+ (NSArray *)constraintsForCenterView:(UIView *)overlay withView:(UIView *)view {
    NSMutableArray *constraints = [NSMutableArray array];
    
    [constraints addObject:[self constraintForCenterByXView:overlay withView:view]];
    [constraints addObject:[self constraintForCenterByYView:overlay withView:view]];
    
    return constraints;
}

@end
