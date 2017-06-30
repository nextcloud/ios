/*
 
 MIT License (MIT)
 
 Copyright (c) 2015 Clement CN Tsang
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 */

#import "CTAssetsGridViewLayout.h"

@implementation CTAssetsGridViewLayout

- (instancetype)initWithContentSize:(CGSize)contentSize traitCollection:(UITraitCollection *)traits
{
    if (self = [super init])
    {
        CGFloat scale = traits.displayScale;
        NSInteger numberOfColumns = [self numberOfColumnsForTraitCollection:traits];
        CGFloat onePixel = (scale == 3.0) ? (2.0 / scale) : (1.0 / scale);
        
        // spacing is as small as possible
        self.minimumInteritemSpacing = onePixel;
        self.minimumLineSpacing = onePixel;
        
        // total spaces between items (in pixel)
        CGFloat spaces  = self.minimumInteritemSpacing * (numberOfColumns - 1);
        
        // item length (in pixel)
        CGFloat length  = (scale * (contentSize.width - spaces)) / numberOfColumns;
        
        // remaining spaces (in pixel) after rounding the length to integer
        CGFloat insets  = (length - floor(length)) * numberOfColumns;
        
        // round the length to integer (in pixel)
        length = floor(length);
        
        // divide insets to two
        CGFloat left = insets / 2;
        CGFloat right = insets / 2;
        
        // adjust if insets is odd
        if (fmodf(insets, 2.0) == 1.0f)
        {
            left -= 0.5;
            right += 0.5;
        }

        // left / right insets (in point, 2 decimal)
        left    = floorf(left / scale * 100) / 100;
        right   = floorf(right / scale * 100) / 100;
        
        // item length (in point, 2 decimal)
        length  = floorf(length / scale * 100) / 100;
        
        self.sectionInset = UIEdgeInsetsMake(0, left, 0, right);
        self.itemSize = CGSizeMake(length, length);
        
        self.footerReferenceSize = CGSizeMake(contentSize.width, floor(length * 2/3));
    }
    
    return self;
}

- (NSInteger)numberOfColumnsForTraitCollection:(UITraitCollection *)traits
{
    switch (traits.userInterfaceIdiom) {
        case UIUserInterfaceIdiomPad:
        {
            return 6;
            break;
        }
        case UIUserInterfaceIdiomPhone:
        {
            // iPhone 6+ landscape
            if (traits.horizontalSizeClass == UIUserInterfaceSizeClassRegular)
                return 4;
            // iPhone landscape
            else if (traits.verticalSizeClass == UIUserInterfaceSizeClassCompact)
                return 6;
            // iPhone portrait
            else
                return 4;
            break;
        }
        default:
            return 4;
            break;
    }
}

@end
