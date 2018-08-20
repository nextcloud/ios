//
//  PKBorderedButton.h
//  Pods
//
//  Created by Holden, Ryan on 2/7/16.
//
//

#import <UIKit/UIKit.h>

@interface PKBorderedButton : UIButton

@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) CGFloat lineWidth;

- (void)configureDefaultAppearance;

- (void)cleanDefaultAppearance;

@end
