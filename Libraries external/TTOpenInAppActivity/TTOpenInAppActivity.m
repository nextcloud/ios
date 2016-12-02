//
//  TTOpenInAppActivity.m
//
//  Created by Tobias Tiemerding on 12/25/12.
//  Copyright (c) 2012-2013 Tobias Tiemerding
// 
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "TTOpenInAppActivity.h"
#import <MobileCoreServices/MobileCoreServices.h> // For UTI
#import <ImageIO/ImageIO.h>

@interface TTOpenInAppActivity () <UIActionSheetDelegate>

// Private attributes
@property (nonatomic, strong) NSArray *fileURLs;
@property (atomic) CGRect rect;
@property (nonatomic, strong) UIBarButtonItem *barButtonItem;
@property (nonatomic, strong) UIView *superView;
@property (nonatomic, strong) UIDocumentInteractionController *docController;

// Private methods
- (NSString *)UTIForURL:(NSURL *)url;
- (void)openDocumentInteractionControllerWithFileURL:(NSURL *)fileURL;
- (void)openSelectFileActionSheet;

@end

@implementation TTOpenInAppActivity
@synthesize rect = _rect;
@synthesize superView = _superView;
@synthesize superViewController = _superViewController;

+ (NSBundle *)bundle
{
    NSBundle *bundle;
    NSURL *openInAppActivityBundleURL = [[NSBundle mainBundle] URLForResource:@"TTOpenInAppActivity" withExtension:@"bundle"];

    if (openInAppActivityBundleURL) {
        // TTOpenInAppActivity.bundle will likely only exist when used via CocoaPods
        bundle = [NSBundle bundleWithURL:openInAppActivityBundleURL];
    } else {
        bundle = [NSBundle mainBundle];
    }

    return bundle;
}

- (id)initWithView:(UIView *)view andRect:(CGRect)rect
{
    if(self =[super init]){
        self.superView = view;
        self.rect = rect;
    }
    return self;
}

- (id)initWithView:(UIView *)view andBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    if(self =[super init]){
        self.superView = view;
        self.barButtonItem = barButtonItem;
    }
    return self;
}

- (NSString *)activityType
{
	return NSStringFromClass([self class]);
}

- (NSString *)activityTitle
{
    return NSLocalizedStringFromTableInBundle(@"Open in ...", @"TTOpenInAppActivityLocalizable", [TTOpenInAppActivity bundle], nil);
}

- (UIImage *)activityImage
{
    if([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0){
        return [UIImage imageNamed:@"TTOpenInAppActivity8"];
    } else if([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0){
        return [UIImage imageNamed:@"TTOpenInAppActivity7"];
    } else {
        return [UIImage imageNamed:@"TTOpenInAppActivity"];
    }
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    NSUInteger count = 0;
    
    for (id activityItem in activityItems) {
		if ([activityItem isKindOfClass:[NSURL class]] && [(NSURL *)activityItem isFileURL]) {
			count++;
		}
        if ([activityItem isKindOfClass:[UIImage class]]) {
            count++;
        }
	}
	
	return (count >= 1);
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    NSMutableArray *fileURLs = [NSMutableArray array];
    
	for (id activityItem in activityItems) {
		if ([activityItem isKindOfClass:[NSURL class]] && [(NSURL *)activityItem isFileURL]) {
            [fileURLs addObject:activityItem];
		}
        if ([activityItem isKindOfClass:[UIImage class]]) {
            NSURL *imageURL = [self localFileURLForImage:activityItem];
            [fileURLs addObject:imageURL];
        }
	}
    
    self.fileURLs = [fileURLs copy];
}

- (void)performActivity
{
    if(!self.superViewController){
        [self activityDidFinish:YES];
        return;
    }

    void(^presentOpenIn)(void) = ^{
        if (self.fileURLs.count > 1) {
            [self openSelectFileActionSheet];
        }
        else {
            // Open UIDocumentInteractionController
            [self openDocumentInteractionControllerWithFileURL:self.fileURLs.lastObject];
        }
    };

    //  Check to see if it's presented via popover
    if ([self.superViewController respondsToSelector:@selector(dismissPopoverAnimated:)]) {
        [self.superViewController dismissPopoverAnimated:YES];
        [((UIPopoverController *)self.superViewController).delegate popoverControllerDidDismissPopover:self.superViewController];
        
        presentOpenIn();
    } else if([self.superViewController presentingViewController]) {    //  Not in popover, dismiss as if iPhone
        [self.superViewController dismissViewControllerAnimated:YES completion:^(void){
            presentOpenIn();
        }];
    } else {
        presentOpenIn();
    }
}

#pragma mark - Helper
- (NSString *)UTIForURL:(NSURL *)url
{
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)url.pathExtension, NULL);
    return (NSString *)CFBridgingRelease(UTI) ;
}

- (void)openDocumentInteractionControllerWithFileURL:(NSURL *)fileURL
{
    // Open "Open in"-menu
    self.docController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.docController.delegate = self;
    self.docController.UTI = [self UTIForURL:fileURL];
    BOOL sucess; // Sucess is true if it was possible to open the controller and there are apps available
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
        sucess = [self.docController presentOpenInMenuFromRect:CGRectZero inView:self.superView animated:YES];
    } else {
        if(self.barButtonItem){
            sucess = [self.docController presentOpenInMenuFromBarButtonItem:self.barButtonItem animated:YES];
        } else {
            sucess = [self.docController presentOpenInMenuFromRect:self.rect inView:self.superView animated:YES];
        }
    }
    
    if(!sucess){
        // There is no app to handle this file
        NSString *deviceType = [UIDevice currentDevice].localizedModel;
        NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Your %@ doesn't seem to have any other Apps installed that can open this document.", @"TTOpenInAppActivityLocalizable", [TTOpenInAppActivity bundle], nil), deviceType];

        // Display alert
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"No suitable App installed", @"TTOpenInAppActivityLocalizable", [TTOpenInAppActivity bundle], nil)
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedStringFromTableInBundle(@"OK", @"TTOpenInAppActivityLocalizable", [TTOpenInAppActivity bundle], nil)
                                              otherButtonTitles:nil];
        [alert show];
        
        // Inform app that the activity has finished
        // Return NO because the service was canceled and did not finish because of an error.
        // http://developer.apple.com/library/ios/#documentation/uikit/reference/UIActivity_Class/Reference/Reference.html
        [self activityDidFinish:NO];
    }
}

- (void)dismissDocumentInteractionControllerAnimated:(BOOL)animated {
    // Hide menu
    [self.docController dismissMenuAnimated:animated];
    
    // Inform app that the activity has finished
    [self activityDidFinish:NO];
}

- (void)openSelectFileActionSheet
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Select a file", @"TTOpenInAppActivityLocalizable", [TTOpenInAppActivity bundle], nil)
                                                             delegate:self
                                                    cancelButtonTitle:nil
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:nil];
    
    for (NSURL *fileURL in self.fileURLs) {
        [actionSheet addButtonWithTitle:[fileURL lastPathComponent]];
    }
    
    actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", @"TTOpenInAppActivityLocalizable", [TTOpenInAppActivity bundle], nil)];

    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
        [actionSheet showFromRect:CGRectZero inView:self.superView animated:YES];
    } else {
        if(self.barButtonItem){
            [actionSheet showFromBarButtonItem:self.barButtonItem animated:YES];
        } else {
            [actionSheet showFromRect:self.rect inView:self.superView animated:YES];
        }
    }
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (void) documentInteractionControllerWillPresentOpenInMenu:(UIDocumentInteractionController *)controller
{
    // Inform delegate
    if([self.delegate respondsToSelector:@selector(openInAppActivityWillPresentDocumentInteractionController:)]) {
        [self.delegate openInAppActivityWillPresentDocumentInteractionController:self];
    }
}

- (void) documentInteractionControllerDidDismissOpenInMenu: (UIDocumentInteractionController *) controller
{
    // Inform delegate
    if([self.delegate respondsToSelector:@selector(openInAppActivityDidDismissDocumentInteractionController:)]) {
        [self.delegate openInAppActivityDidDismissDocumentInteractionController:self];
    }
}

- (void) documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application
{
    // Inform delegate
    if([self.delegate respondsToSelector:@selector(openInAppActivityDidEndSendingToApplication:)]) {
        [self.delegate openInAppActivityDidDismissDocumentInteractionController:self];
    }
    if ([self.delegate respondsToSelector:@selector(openInAppActivityDidSendToApplication:)]) {
        [self.delegate openInAppActivityDidSendToApplication:application];
    }
    
    // Inform app that the activity has finished
    [self activityDidFinish:YES];
}

#pragma mark - Action sheet delegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != actionSheet.cancelButtonIndex) {
        [self openDocumentInteractionControllerWithFileURL:self.fileURLs[buttonIndex]];
    } else {
	    // Inform app that the activity has finished
	    [self activityDidFinish:NO];
    }
}

#pragma mark - Image conversion

- (NSURL *)localFileURLForImage:(UIImage *)image
{
    // save this image to a temp folder
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSString *filename = [[NSUUID UUID] UUIDString];
    NSURL *fileURL;
    // if there is an images array, this is an animated image.
    if (image.images) {
        fileURL = [[tmpDirURL URLByAppendingPathComponent:filename] URLByAppendingPathExtension:@"gif"];
        NSInteger frameCount = image.images.count;
        CGFloat frameDuration = image.duration / frameCount;
        NSDictionary *fileProperties = @{
                                         (__bridge id)kCGImagePropertyGIFDictionary: @{
                                                 (__bridge id)kCGImagePropertyGIFLoopCount: @0, // 0 means loop forever
                                                 }
                                         };
        NSDictionary *frameProperties = @{
                                          (__bridge id)kCGImagePropertyGIFDictionary: @{
                                                  (__bridge id)kCGImagePropertyGIFDelayTime: [NSNumber numberWithFloat:frameDuration],
                                                  }
                                          };
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL, kUTTypeGIF, frameCount, NULL);
        CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);
        for (NSUInteger i = 0; i < frameCount; i++) {
            @autoreleasepool {
                UIImage *frameImage = [image.images objectAtIndex:i];
                CGImageDestinationAddImage(destination, frameImage.CGImage, (__bridge CFDictionaryRef)frameProperties);
            }
        }
        NSAssert(CGImageDestinationFinalize(destination),@"Failed to create animated image.");
        CFRelease(destination);
    } else {
        fileURL = [[tmpDirURL URLByAppendingPathComponent:filename] URLByAppendingPathExtension:@"jpg"];
        NSData *data = [NSData dataWithData:UIImageJPEGRepresentation(image, 0.8)];
        [[NSFileManager defaultManager] createFileAtPath:[fileURL path] contents:data attributes:nil];
    }
    return fileURL;
}

@end

