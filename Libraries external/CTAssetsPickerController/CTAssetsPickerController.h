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


#import <UIKit/UIKit.h>
#import <Photos/Photos.h>


NS_ASSUME_NONNULL_BEGIN

@protocol CTAssetsPickerControllerDelegate;

/**
 *  A controller that allows picking multiple photos and videos from user's photo library.
 */
@interface CTAssetsPickerController : UIViewController

/**
 *  The assets picker’s delegate object.
 */
@property (nonatomic, weak) id <CTAssetsPickerControllerDelegate> delegate;

/**
 *  Set the `assetCollectionSubtypes` to specify which asset collections (albums) to be shown in the picker.
 *
 *  You can specify which albums and their order to be shown in the picker by creating an `NSArray` of `NSNumber`
 *  that containing the value of `PHAssetCollectionSubtype`.
 */
@property (nonatomic, copy) NSArray<NSNumber*> *assetCollectionSubtypes;

/**
 *  Set the `defaultAssetCollection` to specify which asset collection (album) is the default asset collection.
 *
 *  If the `defaultAssetCollection` is explictly set, the picker initially shows the content of default asset
 *  collection instead of a list of albums. By default, there are no default asset collection.
 *
 *  If there are more than one asset collections that match the subtype value of `defaultAssetCollection`, the
 *  first matched asset collection will be the default asset collection.
 */
@property (nonatomic, assign) PHAssetCollectionSubtype defaultAssetCollection;

/**
 *  Set the `PHFetchOptions` to specify options when fetching asset collections (albums).
 *
 *  @see assetsFetchOptions
 */
@property (nonatomic, strong) PHFetchOptions *assetCollectionFetchOptions;

/**
 *  Set the `PHFetchOptions` to specify options when fetching assets.
 *
 *  @see assetCollectionFetchOptions
 */
@property (nonatomic, strong) PHFetchOptions *assetsFetchOptions;


/**
 *  The selected assets.
 *
 *  It contains selected `PHAsset` objects. The order of the objects is the selection order.
 *  
 *  You can use this property to select assets initially when presenting the picker.
 */
@property (nonatomic, strong) NSMutableArray *selectedAssets;

/**
 *  An optional title for the done button
 *
 *  You can override the title of "Done" button by this value.
 */
@property (nonatomic, copy) NSString *doneButtonTitle;

/**
 *  Determines whether or not the cancel button is visible in the picker.
 *
 *  The cancel button is visible by default. To hide the cancel button, (e.g. presenting the picker in `UIPopoverController`)
 *  set this property’s value to `NO`.
 */
@property (nonatomic, assign) BOOL showsCancelButton;

/**
 *  Determines whether or not the empty albums is shown in the album list.
 *
 *  All albums are visible by default. To hide albums without assets matched with `assetsFetchOptions`,
 *  set this property’s value to `NO`.
 *
 *  @see assetsFetchOptions
 */
@property (nonatomic, assign) BOOL showsEmptyAlbums;

/**
 *  Determines whether or not the number of assets is shown in the album list.
 *
 *  The number of assets is visible by default. To hide the number of assets, (e.g. implementing `shouldShowAsset` delegate method)
 *  set this property’s value to `NO`.
 */
@property (nonatomic, assign) BOOL showsNumberOfAssets;

/**
 *  Determines whether or not the done button is always enabled.
 *
 *  The done button is enabled only when assets are selected. To enable the done button even without assets selected,
 *  set this property’s value to `YES`.
 */
@property (nonatomic, assign) BOOL alwaysEnableDoneButton;

/**
 *  Determines whether or not the selection order is shown in the grid view.
 *
 *  Only a checkmark is shown on selected assets by default. To shows the order of selection,
 *  set this property’s value to `YES`.
 */
@property (nonatomic, assign) BOOL showsSelectionIndex;

/**
 *  The split view controller of the picker hierarchy. (read-only)
 *
 *  This property contains the child split view controller of the picker.
 */
@property (nonatomic, readonly, strong) UISplitViewController *childSplitViewController;


/**
 *  @name Managing Selections
 */

/**
 *  Selects an asset in the picker.
 *
 *  @param asset The asset to be selected.
 *
 *  @see deselectAsset:
 */
- (void)selectAsset:(PHAsset *)asset;

/**
 *  Deselects an asset in the picker.
 *
 *  @param asset The asset to be deselected.
 *
 *  @see selectAsset:
 */
- (void)deselectAsset:(PHAsset *)asset;

@end


/**
 *  The `CTAssetsPickerControllerDelegate` protocol defines methods that allow you to to interact with the assets picker interface
 *  and manage the selection and highlighting of assets in the picker.
 *
 *  The methods of this protocol notify your delegate when the user selects, highlights, finish picking assets, or cancels the picker operation.
 *
 *  The delegate methods are responsible for dismissing the picker when the operation completes.
 *  To dismiss the picker, call the `dismissViewControllerAnimated:completion:` method of the presenting controller
 *  responsible for displaying `CTAssetsPickerController` object.
 *
 *  The picked assets are `PHAsset` objects and contain only metadata. The underlying image or video data for any given asset might not be stored on the local device.
 *  You have to use `PHImageManager` object for loading image or video data associated with a `PHAsset`.
 */
@protocol CTAssetsPickerControllerDelegate <NSObject>


/**
 *  @name Closing the Picker
 */

/**
 *  Tells the delegate that the user finish picking photos or videos.
 *
 *  @param picker The controller object managing the assets picker interface.
 *  @param assets An array containing picked `PHAsset` objects.
 *
 *  @see assetsPickerControllerDidCancel:
 */
- (void)assetsPickerController:(CTAssetsPickerController *)picker didFinishPickingAssets:(NSArray<PHAsset*> *)assets;

@optional

/**
 *  Tells the delegate that the user cancelled the pick operation.
 *
 *  @param picker The controller object managing the assets picker interface.
 *
 *  @see assetsPickerController:didFinishPickingAssets:
 */
- (void)assetsPickerControllerDidCancel:(CTAssetsPickerController *)picker;


/**
 *  @name Configuting Asset Selection View
 */

/**
 *  Ask the delegate the layout of asset selection view (UICollectionView).
 *
 *  @param picker The controller object managing the assets picker interface.
 *  @param contentSize  The bounds size of current view.
 *  @param trait The trait collection of current view.
 *
 *  @return Custom `UICollectionViewLayout` for the asset selection view.
 */
- (UICollectionViewLayout *)assetsPickerController:(CTAssetsPickerController *)picker collectionViewLayoutForContentSize:(CGSize)contentSize traitCollection:(UITraitCollection *)trait;


/**
 *  Ask the delegate if the asset selection view should sroll to bottom on shown.
 *
 *  @param picker The controller object managing the assets picker interface.
 *  @param assetCollection  The asset collection of asset selection view.
 *
 *  @return `YES` (the default) if the asset grid should scroll to bottom on shown or `NO` if it should not.
 */

- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker shouldScrollToBottomForAssetCollection:(PHAssetCollection *)assetCollection;


/**
 *  @name Enabling Assets
 */

/**
 *  Ask the delegate if the specified asset should be enabled for selection.
 *
 *  @param picker The controller object managing the assets picker interface.
 *  @param asset  The asset to be enabled.
 *
 *  @return `YES` if the asset should be enabled or `NO` if it should not.
 *
 *  @see assetsPickerController:shouldShowAsset:
 */
- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker shouldEnableAsset:(PHAsset *)asset;


/**
 *  @name Managing the Selected Assets
 */

/**
 *  Asks the delegate if the specified asset should be selected.
 *
 *  @param picker The controller object managing the assets picker interface.
 *  @param asset  The asset to be selected.
 *
 *  @return `YES` if the asset should be selected or `NO` if it should not.
 *
 *  @see assetsPickerController:shouldDeselectAsset:
 */
- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker shouldSelectAsset:(PHAsset *)asset;

/**
 *  Tells the delegate that the asset was selected.
 *
 *  @param picker The controller object managing the assets picker interface.
 *  @param asset  The asset that was selected.
 *
 *  @see assetsPickerController:didDeselectAsset:
 */
- (void)assetsPickerController:(CTAssetsPickerController *)picker didSelectAsset:(PHAsset *)asset;

/**
 *  Asks the delegate if the specified asset should be deselected.
 *
 *  @param picker The controller object managing the assets picker interface.
 *  @param asset  The asset to be deselected.
 *
 *  @return `YES` if the asset should be deselected or `NO` if it should not.
 *
 *  @see assetsPickerController:shouldSelectAsset:
 */
- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker shouldDeselectAsset:(PHAsset *)asset;

/**
 *  Tells the delegate that the item at the specified path was deselected.
 *
 *  @param picker The controller object managing the assets picker interface.
 *  @param asset  The asset that was deselected.
 *
 *  @see assetsPickerController:didSelectAsset:
 */
- (void)assetsPickerController:(CTAssetsPickerController *)picker didDeselectAsset:(PHAsset *)asset;



/**
 *  @name Managing Asset Highlighting
 */

/**
 *  Asks the delegate if the specified asset should be highlighted.
 *
 *  @param picker The controller object managing the assets picker interface.
 *  @param asset  The asset to be highlighted.
 *
 *  @return `YES` if the asset should be highlighted or `NO` if it should not.
 */
- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker shouldHighlightAsset:(PHAsset *)asset;

/**
 *  Tells the delegate that asset was highlighted.
 *
 *  @param picker The controller object managing the assets picker interface.
 *  @param asset  The asset that was highlighted.
 *
 *  @see assetsPickerController:didUnhighlightAsset:
 */
- (void)assetsPickerController:(CTAssetsPickerController *)picker didHighlightAsset:(PHAsset *)asset;


/**
 *  Tells the delegate that the highlight was removed from the asset.
 *
 *  @param picker The controller object managing the assets picker interface.
 *  @param asset  The asset that had its highlight removed.
 *
 *  @see assetsPickerController:didHighlightAsset:
 */
- (void)assetsPickerController:(CTAssetsPickerController *)picker didUnhighlightAsset:(PHAsset *)asset;




/**
 *  @name Notifications
 */

/**
 *  Sent when the assets selected or deselected
 *
 *  The notification’s `object` is an `NSArray` object of selected assets
 */
extern NSString * const CTAssetsPickerSelectedAssetsDidChangeNotification;

/**
 *  Sent when asset is selected
 *
 *  The notification’s `object` is a `PHAsset` that is selected
 */
extern NSString * const CTAssetsPickerDidSelectAssetNotification;

/**
 *  Sent when asset is deselected
 *
 *  The notification’s `object` is a `PHAsset` that is deselected
 */
extern NSString * const CTAssetsPickerDidDeselectAssetNotification;


@end

NS_ASSUME_NONNULL_END