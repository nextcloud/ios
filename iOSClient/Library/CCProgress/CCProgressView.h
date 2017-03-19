//
//  CCProgressView.h
//  NavigationProgress
//
//  Created by Shawn Gryschuk on 2013-09-19.
//  Copyright (c) 2013 Shawn Gryschuk. All rights reserved.
//
//  Modify Marino Faggiana

#import <UIKit/UIKit.h>

@interface CCProgressView : UIView

/**
 *  The current progress shown by the receiver.
 *  The progress value ranges from 0 to 1. The default value is 0.
 */
@property (nonatomic, assign) float progress;

@end
