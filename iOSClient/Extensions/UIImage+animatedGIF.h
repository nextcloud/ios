//
//  UIImage+animatedGIF
//  Nextcloud
//
//  Created by Marino Faggiana on 28/05/17.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Found in Internet
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>

@interface UIImage (animatedGIF)

/*
    UIImage *animation = [UIImage animatedImageWithAnimatedGIFData:theData];
    
    I interpret `theData` as a GIF.  I create an animated `UIImage` using the source images in the GIF.
    
    The GIF stores a separate duration for each frame, in units of centiseconds (hundredths of a second).  However, a `UIImage` only has a single, total `duration` property, which is a floating-point number.
    
    To handle this mismatch, I add each source image (from the GIF) to `animation` a varying number of times to match the ratios between the frame durations in the GIF.
    
    For example, suppose the GIF contains three frames.  Frame 0 has duration 3.  Frame 1 has duration 9.  Frame 2 has duration 15.  I divide each duration by the greatest common denominator of all the durations, which is 3, and add each frame the resulting number of times.  Thus `animation` will contain frame 0 3/3 = 1 time, then frame 1 9/3 = 3 times, then frame 2 15/3 = 5 times.  I set `animation.duration` to (3+9+15)/100 = 0.27 seconds.
*/
+ (UIImage *)animatedImageWithAnimatedGIFData:(NSData *)theData;

/*
    UIImage *image = [UIImage animatedImageWithAnimatedGIFURL:theURL];
    
    I interpret the contents of `theURL` as a GIF.  I create an animated `UIImage` using the source images in the GIF.
    
    I operate exactly like `+[UIImage animatedImageWithAnimatedGIFData:]`, except that I read the data from `theURL`.  If `theURL` is not a `file:` URL, you probably want to call me on a background thread or GCD queue to avoid blocking the main thread.
*/
+ (UIImage *)animatedImageWithAnimatedGIFURL:(NSURL *)theURL;

@end
