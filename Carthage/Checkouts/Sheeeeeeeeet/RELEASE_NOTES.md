# Release Notes


## 3.0.9

This version adjusts the secondary action to be a regular menu item action.


## 3.0.8

This version adjusts the secondary action signature to also provide the affected item. It's a breaking change, but a small one, so deal with it I guess  ¯\_(ツ)_/¯

This version also make sthe `ActionSheetItemHandler` protocol implementations `open` so they're possible to override.


## 3.0.7

This version adds a new `SecondaryActionItem` which lets you specify a secondary action for an item.

It also adds a new `MenuCreator` protocol that can be implemented to postpone the creation of a menu, which may be good for prestanda when adding a context menu to every item in a large view collection.


## 3.0.6

This version solves an App Store submission rejection that occurred when an app pulled in Sheeeeeeeeet with Carthage.


## 3.0.5

This version changes `ContextMenuDelegateRetainer`'s `contextMenuDelegate` to an `Any` instead of its concrete type, to make it possible to use it on older iOS versions. This should not have any side-effects, since it's only used to retain the instance, never use it.


## 3.0.4

This version makes the `ActionSheet`'s `backgroundView` property public.


## 3.0.3

This version fixes some subtitle problems, where section titles and mutli select toggles didn't display their subtitles.

It also fixes some behavior issues, where subtitles were incorrectly tinted.


## 3.0.2

This version adjusts the popover height calculations to include the height of a visible header. This solves the problem where the popover content would always scroll when a header was used.

The version also adjusts the item height calculations, so that you no longer have to register a height for each item. This solves the problem with all items getting a zero size by default. Now, `height` is recursively resolved to the closest parent height if you haven't overridden `appearance().height` for your custom item.


## 3.0.1

This version adjusts the subtitle style to use `subtitle` instead of `value1`.

It also adds a new `preferredActionSheetCellStyle` property to `MenuItem`, which you can override for your custom items.


## 3.0.0

Sheeeeeeeeet 3 contains many breaking changes, but once you understand the model changes, you will hopefully see the improvements it brings and be able to migrate your apps pretty easily. See [this migration guide][Migration-Guide] for help.

This version separates the menu data model from the custom action sheet implementation, so that you can create menus without caring about how they will be presented.

The new `Menu` type and all `MenuItem` types are decoupled from the presentation. This means that you can use them in more ways, for instance in custom and native action sheets, context menus etc.

With these changes, you now create `ActionSheet`s with a `Menu` instead of `ActionSheetItem`s. Due to this, the `3.0` release of Sheeeeeeeeet has many breaking changes:
 
 * All `ActionSheetItem` have been replaced by the new `MenuItem` types. Most of these items have the same name as the old ones, but without the `ActionSheet` prefix.
 * `ActionSheetDangerButton` corresponds to the new `DestructiveButton` class.
 * `ActionSheetCustomItemContentCell` has been moved and renamed to `CustomItemType`.
 * `ActionSheetCollectionItemContentCell` has been moved and renamed to `CollectionItemType`.
 
 There are also some breaking changes that involve how you work with action sheets:

 * Item heights are no longer static, but an action sheet cell appearance proxy property.
 * The action sheet header behavior is now specified in a `headerViewConfiguration` property.
 * `CustomItem` (`ActionSheetCustomItem`) has been made non-generic.
 * `isOkButton` and `isCancelButton` is gone. Use type checking instead, e.g. `is OkButton`.

Bonus features:

* The popover presenter now supports header views. It no longer hides the header by default.
* `Menu` can be used to create action sheets, which you then present and configure like before.
* `Menu` can be directly presented as a custom action sheet, without creating an `ActionSheet`.
* `Menu` can be added as an iOS 13 context menu to any view.
* `Menu` can be presented as a native `UIAlertController`.

Some of the presentations above require that all items in the menu can be represented in that context.


## 2.1.0

This version adds Xcode 11 and iOS 13 support, including support for dark mode and high contrast color variants.

There is a new `ActionSheetColor` enum with sheet-specific semantic colors. It uses the new, adaptive system colors in iOS 13 and falls back to older, non-adaptive colors in iOS 12 and below. You can either use the enum directly or use the static `UIColor` extension `.sheetColor(...)`.

The appearance model has been extended with new a appearance type, which you can use to style your sheets. There is an `ActionSheetAppearance` base class as well as a standard `StandardActionSheetAppearance` appearance which applies a standard look, including dark mode support, high contrast color variants and SFSymbol icons on iOS 13.

There are adjustments to how sheets can be dismissed. The `isDismissableWithTapOnBackground` has been renamed to `isDismissable`, since it also affects if the system can dismiss the action sheet.


## 2.0.2

This version makes table view footer view sizes smaller to avoid a scroll offset issue that could occur when rotating devices that displayed sheets with a single custom item.


## 2.0.1

This version adjusts accessibility traits for selected select items and improves the overall accessibility experience when working with selectable items.


## 2.0.0

This version upgrades Sheeeeeeeeet and its unit test dependencies to Swift 5. It contains no breaking changes.


## 1.4.1

This version makes `currentContext` the default presentation mode for the default presenter. This is due to accessibility issues with using `keyWindow` while being ina modal presentation. I will change how the default presenteras presents action sheets, but that is a future improvement.


## 1.4.0

This version removes the old deprecated appearance model, so if your app uses it, it's time to start using the appearance proxy model. Just follow the readme, and you'll be done in no time.

This version also change which presenter to use, so that apps behaves correct on iPads in split screen. We still have to come up with a way to switch between the default and popover presenters when the split screen size changes, but that is a future improvement.


## 1.3.3

This version adds a new `headerViewLandscapeMode` property to `ActionSheet`. You can set it to `.hidden` to let action sheets hide their header view in landscape orientation. This will free up more screen estate for the action sheet's options.


## 1.3.3

This version adds a new `headerViewLandscapeMode` property to `ActionSheet`. You can set it to `.hidden` to let action sheets hide their header view in landscape orientation. This will free up more screen estate for the action sheet's options.


## 1.3.2

This version makes the `ActionSheet` `backgroundView` outlet public, so that you can add your own custom effects to it. The other outlets are still internal.

The version also fixes a bug that caused action sheets to be misplaced when they were presented from a custom presentation controller. This fix also adds a brand new `presentationStyle` property to `StandardActionSheetPresenter`, which can be either `keyWindow` (default) or `currentContext`. Setting it to `keyWindow` will present the action sheet in the app's key window (full screen), while setting it to `currentContext` will present it in the presenting view controller's view (it looks straaange, but perhaps you can find a nice use case for it).


## 1.3.1

This version fixes an iOS 9 bug that caused the popover to become square with no arrow. It was caused by the popover presenter, that set the background color for the popover after it had been presented, which is not supported in iOS 9. It now sets the bg color for all iOS versions before it presents the popover, then only refreshes it for iOS 10 and later.

This version fixes another iOS 9 bug that caused the item cell separator line to behave strangely and not honor the insets set using the appearance proxy. I have added a fix to the item cell class, that only runs for iOS 9.


## 1.3.0

This version removes the last separator line from the item and button table view.

This version also changes the default behavior of the popover presenter. It used to keep the popover presented as the device orientation changed, but this can be wrong in many cases. For instance, in collection or table views, the orientation change may cause cells to shuffle around as they are reused. If a reused cell is used as the popover source view, and the popover is still presented, the popover will point to the cell, but the cell model will have changed. In this case, your action sheet will appear to point to a specific object, but will be contextually bound to another one. 

Another way that orientation changes may mess with popovers are if a source view is removed from the view hierarchy when the orientation changes. If your popover is still presented, but the source view is removed, the popover arrow will point to a random point, e.g. the top-left part of the screen.

To solve these bugs, I have added new orientation change handling in the popover presenter. It has a new `isListeningToOrientationChanges` property, as well as a `handleOrientationChange` and `setupOrientationChangeDetection` function. If you want to, you can override these functions to customize their behavior, otherwise just set `isListeningToOrientationChanges` to `false` to make the popover behave like before.


## 1.2.4

This version fixes the https://github.com/danielsaidi/Sheeeeeeeeet/issues/64 bug, which caused an iPad popover to become a bottom action sheet on black background, if the idiom changes from pad to phone while the action sheet is open. I now let the popover remain as long as the action sheet is open.


## 1.2.3

This version reloads data when scrolling to row to solve a bug that could happen on some iPad devices.


## 1.2.2

This hotfix adds two new properties to `ActionSheetSelectItem`, that can be used to style the selected fonts: `selectedTitleFont` and `selectedSubtitleFont`.


## 1.2.1

This hotfix fixes a font bug in the title item and color bugs in the select item. 


## 1.2.0

This is a huge update, that completely rewrites how action sheet appearances are handled. Instead of the old appearance model, Sheeeeeeeeet now relies on the iOS appearance proxy model as much as possible.

The old appearance model is still around, but has been marked as deprecated, and will be removed in `1.4.0`. Make sure that you switch over to the new appearance model as soon as possible. Have a look at the example app and [here][Appearance] to see how you should customize the action sheet appearance from now on. 

In short, item appearance customizations are handled in three different ways now:

* Item appearances such as colors and fonts, are customized with cell properties, for instance: `ActionSheetSelectItemCell.appearance().titleColor = .green`.
* Item heights are now customized by setting the `height` property of every item type you want to customize, for instance: `ActionSheetTitle.height = 22`.
* Action sheet margins, insets etc. are now customized by setting the properties of each `ActionSheet` instance. If you want to change the default values for all action sheets in your app, you have to subclass `ActionSheet`.

All built-in action sheet items now have their own cells. Your custom items only have to use custom cells if you want to apply custom item appearances to them.

Sheeeeeeeeet now contains several new views, which are used by the action sheets:

  * `ActionSheetTableView`
  * `ActionSheetItemTableView`
  * `ActionSheetButtonTableView`
  * `ActionSheetBackgroundView`
  * `ActionSheetStackView`

The new classes make it easy to modify the appearance of these views, since they have appearance properties as well. For instance, to change the corner radius of the table views, just type: `ActionSheetTableView.appearance().cornerRadius = 8`.

`ActionSheet` has two new extensions: 
  * `items<T>(ofType:)`
  * `scrollToFirstSelectedItem(at:)`

This new version has also rebuilt all unit tests from scratch. They are now more robust and easier to maintain.


## 1.1.0

This version increases the action sheet integrity by restricting what you can do with it. This involves some breaking changes, but they should not affect you. If you think any new rule is bad or affect you, please let me know.


**New Features**

@sebbo176 has added support for subtitles in the various select items, which now also changes the cell style of an item if the subtitle is set. He has also added an unselected icon to the select items, which means that you can now have images for unselected items as well (e.g. an unchecked checkbox).


**Breaking Changes - ActionSheet:**

* The `items` and `buttons` properties are now `internal(set)`, which means that they can only be set with `init(...)` or with `setup(items:)`. This protects the integrity of the item and button separation logic.
* The code no longer contains any `didSet` events, since these events called the same functionality many times. Call `refresh` if you change any outlets manually from now on.
* Since the `didSet` events have been removed, `refreshHeaderVisibility` is only called once and has therefore been moved into `refreshHeader`.
* Since the `didSet` events have been removed, `refreshButtonsVisibility` is now only called once and has therefore been moved into `refreshButtons`.
* A small delay in `handleTap(on:)`, that should not be needed, has been removed.

Let me know if it causes any side-effects.



## 1.0.3

This version removes a debug print that I used to ensure that action sheets were properly deinitialized after being dismissed.



## 1.0.2

This version adds new background color properties to the action sheet appearance class. They can be used to set the background color of an entire sheet.

This version fixes a bug, where the background color behind an action sheet went black when the action sheet was presented in a split view.



## 1.0.1

This version fixes a bug, where the presenters incorrectly updated the scrolling behavior of the action sheet when rotating the device.



## 1.0.0

Sheeeeeeeeet 1.0.0 is finally here, with many internal changes and some external.

This version decouples action sheets from their presentation to great extent. An action sheet still styles its items and components, but the presenters now takes care of a lot more than before. The sheet setup is now also based on constraints instead of manual calculations, which means that popover scrolling etc. works by how the constraints are setup, instead of relying on manual calculations.

This should result in much more robust action sheets, but it requires testing on a wide range of devices and orientations, so please let me know if there are any issues with this approach.

`IMPORTANT` The button item values have changed. Insted of `true` and `nil` they now have a strong `ButtonType` value. You can still create custom buttons with a custom value, though. You can also use the new `isOkButton` and `isCancelButton` extensions to quickly see if a user tapped "OK" or "Cancel".

### Breaking changes

Since the presentation logic has been rewritten from scratch, you have to adjust your code to fit the new structure, if you have subclassed any presenter or made presentation tweaks in your sheets. The changes are too many and extensive to be listed here, so please have a look at the new structure. There is much less code, so changing your code to the new standard should be easy.

* `ActionSheetButton` and its sublasses has new values.
* `ActionSheet.itemTapAction` has been removed
* `ActionSheet.handleTap(on:)` is now called when an item is tapped
* `ActionSheetAppearance.viewMargins` is renamed to `groupMargins`
* `ActionSheetItem.itemType` has been removed; just check the raw type
* `ActionSheetItem.handleTap(in:)` no longer has a `cell` parameter
* `ActionSheetStandardPresenter` is renamed to `ActionSheetStandardPresenter`

### New features

* `ActionSheetAppearance` has new properties, which adds new way to style sheets.
* `ActionSheetButton` adds `isOkButton` and `isCancelButton` extension functions to `ActionSheetItem`. They can be used to quickly check if a cancel or ok button was tapped, instead of having to check if the item can be cast to a button type. 

### Bug fixes

* The big presentation adjustments solves the scrolling issues that occured with popovers and many items.
* The `hideSeparator()` function is adjusted to behave correctly when the device is rotated.

### Deprecated logic

Instead of deprecating presentation-related properties and functions that are no longer used or available, I removed them completely. Let me know if you used any properties that are no longer available.

* `ActionSheetItem.setupItemsAndButtons(with:)` is renamed to `setup(items:)`
* `ActionSheetItem.itemSelectAction` is renamed to `selectAction`

Perform the deprecation warnings, and you should be all good. Deprecated members will be removed in the next minor version.



# Legacy versions

## 0.11.0

This version adds a `customAppearance` property to `ActionSheetItem` and fixes a
few appearance glitches. Overall, it makes the appearance setup more consistent.

* I use early returns in every appearance class and have optimized imports. Many
appearance classes have also been made `open` instead of `public`.

* The `ActionSheetItemAppearance` now has extensions for `noSeparator`, that can
be used to hide the separator for certain item types.

* The `ActionSheetCollectionItemAppearance` and `ActionSheetCustomItemAppearance`
and `ActionSheetSectionMarginAppearance` classes have no overridden initializers
anymore. This makes the work as expected when you use the same appearance tweaks
as everywhere else.

* The `ActionSheetPopoverAppearance` class doesn't inherit any appearance classes
and has thus been moved out to the appearance root.



## 0.10.1

This revision fixes a project config that caused Carthage installations to fail.



## 0.10.0

`Sheeeeeeeeet` has a new item type: `ActionSheetCustomItem`. You can use it when
you want to use a completely custom view in your action sheet. Just tell it what
view you want to use and make sure that the view class inherits `ActionSheetItem`
and implements `ActionSheetCustomItemCell`. Have a look at the example app for a
simple example.

`ActionSheetCollectionItem` `cellType` has been renamed to `itemCellType`, which
makes it clearer that the type regards the collection view items.

`ActionSheetItem` now has a `cellReuseIdentifier` and `className` property, that
can be useful when sublassing various item classes. It also makes it much easier
to register custom cell types. See `ActionSheetCollectionItem` `cell(for: ...)`.

The collection item `CollectionItemCellAction` has been renamed to `CellAction`.



## 0.9.9

Let's all party like it's 0.9.9! 

I've done some refactoring and will introduce a few breaking changes that can be
easily fixed. They will hopefully not affect you at all.

`ActionSheetItem` has an `itemType` property, that can be used to e.g. check the
type of item that is tapped. For now, the enum has `item`, `button` and `title`.

The `ActionSheetMargin` `fallback` function param has been renamed to `minimum`.

`ActionSheetItemSelectAction` has been renamed to `ActionSheetItem.SelectAction`
and `ActionSheetItemTapAction` has been renamed to `ActionSheetItemTapAction`.

`ActionSheetItemHandler.CollectionType` has been renamed to `ItemType`.

The two `ActionSheetItem` `handleTap` functions have been combined to one single
function.



## 0.9.8

`ActionSheetPresenter` now has an `events` property, which contains presentation
event actions that you can assign to get callbacks when certain events happen. A
first `didDismissWithBackgroundTap` event has been added, which helps you detect
if an action sheet is dismissed because a user tapped on the background, outside
the actin sheet bounds. This works for both the standard and popover presenters.



## 0.9.7

`ActionSheetItem` now has `tapBehavior` as part of the constructor.

`ActionSheetCollectionItem` now uses `open` instead of `public` for `collection`
and `layout` related functions as well, which means that you can override them.



## 0.9.6

This version migrates Sheeeeeeeeeet to Swift 4.2. You will need Xcode 10 to work
with the source code from now on.



## 0.9.5

This version adds a `backgroundColor` property to `ActionSheetItemAppearance`. I
however want to emphasize that many appearance properties that can be controlled
with the appearance classes, can also be setup using standard appearance proxies.



## 0.9.4

This version fixes a bug where all items with tap behavior `.none` did not get a
highlight effect when they were tapped. Instead, title items set `selectionStyle`
to `.none` for their cell.

We have also added an index check in the item handler. We have seen some strange
crashes in the logs, that hints at that the item handler sheet property could be
deallocated but that users can still tap at an item...which then tries to access
a deallocated item array. Hopefully, this helps.



## [0.9.3](https://github.com/danielsaidi/Sheeeeeeeeet/milestone/8?closed=1)

This fixes a crash that occured if the library was installed with CocoaPods. The
podspec didn't include xibs, which caused the collection item to crash.



## [0.9.2]

In this version, the `ActionSheetStandardPresenter` initializer is finally public.
I have forgot to do this for a couple of versions, which means that you have not
been able to create custom instances of this class from within an app.

This means that you can set the presenter to a `ActionSheetStandardPresenter` for
any action sheet, which means that even iPads can now get iPhone-styled sheets.



## [0.9.1](https://github.com/danielsaidi/Sheeeeeeeeet/milestone/7?closed=1)

This version contains minor updates and minor breaking changes in internal logic.

* The `ActionSheet` `appearance` and `presenter` properties are not lazy anymore.
  Their initial values are set in a different way as well. `itemSelectAction` is
  now set differently by the two initializers.

* Popover action sheets on iPad caused a strange flickering effect, if they were
  presented when the app was awaken from the background. @ullstrm found out that
  it was caused by setting the separator inset to .greatestFiniteMagnitude in an
  iPad popover. Really strange, but fixed by setting it to a laaaarge value.

* Sheeeeeeeeet did handle the flickering bug by dismissing the popover sheets as
  the app was sent to the background. This is no longer needed.



## [0.9.0](https://github.com/danielsaidi/Sheeeeeeeeet/milestone/6?closed=1)

`ActionSheetStandardPresenter` used to contain an embedded iPad presenter. I have
never been happy with this design, and have now redesigned this setup. I removed
the embedded presenter, merged `ActionSheetStandardPresenter` with the base class
and now let the action sheet initializer resolve which default presenter to use.

I have felt a little lost in how to use the various select items, especially now
when Sheeeeeeeeet has select items, single-select items and multiselect items. I
initially designed the select item to be a regular item, that could indicate its
selected state. However, this behaved strange when another item became selected, 
since the initially selected item was not deselected. After introducing this new
item set, with single-select items and multiselect items, I have come to realize
that the base class is probably not a good stand-alone class and have decided to
make it private, to enforce using either of the two subclasses.

The new `isDismissableWithTapOnBackground` presenter property can be used to set
whether or not an action sheet can be dismissed by tapping on the background. It
is true by default for all presenters.

### Improvements:

* The demo app presents action sheets from the tapped cells. However, this means
  that on iPad, the popover will not use the full available screen height, since
  it will be displayed above or below the cell. I have changed this, so that the
  action sheet is presented from the cell's text label instead, which causes the
  action sheet to float above the cell and make use of the entire screen size.

### Bug fixes:

* `ActionSheetPopoverPresenter` did not release its action sheet whenever a user
  tapped on the background, causing a memory leak. This is fixed.

### Breaking changes:

* `ActionSheetStandardPresenter` no longer have an embedded `iPadPresenter`. This
  is no longer needed, since the action sheet resolves the default presenter for
  the current device.

* `ActionSheetPresenterBase` has been removed and is now fully incorporated with
  the `ActionSheetStandardPresenter` class.

* `ActionSheetSelectItem`s initializer has been made library internal to enforce
  using single and multi select items instead. This makes the api much clearer.

* I have chosen to remove the `peek & pop` features, since the implementation is
  so-so and it feels strange to peek and pop an action sheet. I hope that no one
  actually used this feature (since it looked horrible from 0.8, for some reason).
  You can still use Sheeeeeeeeeet with peek and pop, since the action sheets are
  regular view controllers, but you have to write the logic yourself.



## [0.8.4](https://github.com/danielsaidi/Sheeeeeeeeet/milestone/5?closed=1)

Sheeeeeeeeet now has a new `ActionSheetMultiSelectToggleItem` item, which can be
used to select and deselect all multiselect items in the same group.



## [0.8.3](https://github.com/danielsaidi/Sheeeeeeeeet/milestone/4?closed=1)

In this version, no cancel buttons will be displayed in popover presented action
sheets, since the convention is to dismiss a popover by tapping anywhere outside
the popover callout view.



## 0.8.1

The color properties in `ActionSheetSelectItemAppearance` have been renamed. The
change is small, but the change will be breaking if you have used the properties
to customize your action sheet appearances.



## [0.8.0](https://github.com/danielsaidi/Sheeeeeeeeet/milestone/3?closed=1)

Breaking changes! The toggle item has been a strange part of Sheeeeeeeeet. It is
basically a select item with individual styling, which is easy to customize with
the built-in appearance. We have therefore decided to remove this item type from
`Sheeeeeeeeet`, with hopes that it will make the api more obvious.

The `ActionSheetSingleSelectItem` tap behavior has been changed to use `.dismiss`.
This makes the behavior consistent with the standard select item. This means you
have to manually set the tap behavior `.none` whenever you need that behavior.

We have added a `ActionSheetSingleSelectItemAppearance` class to the library and
added a new `singleSelectItem` property to the appearance class.



## 0.7.1

Select items can now have a separate select tint color for the left icon.



## 0.7.0

We have added a subtitle to the section title item and clarified the examples by
moving action sheets into their own separate classes.


[Appearance]: https://github.com/danielsaidi/Sheeeeeeeeet/blob/master/Readmes/Appearance.md
[Migration-Guide]: https://github.com/danielsaidi/Sheeeeeeeeet/blob/master/Readmes/Migration-Guide.md
