# Release Notes

## 1.0.2

This version adds new background color properties to the action sheet appearance,
to make it possible to set the background color of the table views.

This version fixes a bug, where the background color behind an action sheet went
black when the action sheet was presented in a split view.


## 1.0.1

This version fixes a bug, where the presenters incorrectly updated the scrolling
behavior of the action sheet when rotating the device.


## 1.0.0

Sheeeeeeeeet 1.0.0 is finally here, with many internal changes and some external.

This version decouples action sheets from their presentation to great extent. An
action sheet still styles its items and components, but the presenters now takes
care of a lot more than before. The sheet setup is now also based on constraints
instead of manual calculations, which means that popover scrolling etc. works by
how the constraints are setup, instead of relying on manual calculations.

This should result in much more robust action sheets, but it requires testing on
a wide range of devices and orientations before it can be released as a 1.0.

`IMPORTANT` The button item values have changed. Insted of `true` and `nil` they
now have a strong `ButtonType` value. You can still create custom buttons with a
custom value, though. You can also use the new `isOkButton` and `isCancelButton`
extensions to quickly see if a user tapped "OK" or "Cancel".


### Breaking changes

Since the presentation logic has been rewritten from scratch, you have to adjust
your code to fit the new structure, if you have subclassed any presenter or made
presentation tweaks in your sheets. The changes are too many and extensive to be
listed here, so please have a look at the new structure. There is much less code,
so changing your code to the new standard should be easy.

* `ActionSheetButton` and its sublasses has new values.
* `ActionSheet.itemTapAction` has been removed
* `ActionSheet.handleTap(on:)` is now called when an item is tapped
* `ActionSheetAppearance.viewMargins` is renamed to `groupMargins`
* `ActionSheetItem.itemType` has been removed; just check the raw type
* `ActionSheetItem.handleTap(in:)` no longer has a `cell` parameter
* `ActionSheetStandardPresenter` is renamed to `ActionSheetStandardPresenter`


### New features

* `ActionSheetAppearance` has new properties, which adds new way to style sheets.
* `ActionSheetButton` adds `isOkButton` and `isCancelButton` extension functions
to `ActionSheetItem`. They can be used to quickly check if a cancel or ok button
was tapped, instead of having to check if the item can be cast to a button type. 


### Bug fixes

* The big presentation adjustments solves the scrolling issues that occured with
popovers and many items.
* The `hideSeparator()` function is adjusted to behave correctly when the device
is rotated.


### Deprecated logic

Instead of deprecating presentation-related properties and functions that are no
longer used or available, I removed them completely. Let me know if you used any
properties that are no longer available.

* `ActionSheetItem.setupItemsAndButtons(with:)` is renamed to `setup(items:)`
* `ActionSheetItem.itemSelectAction` is renamed to `selectAction`

Perform the deprecation warnings, and you should be all good. Deprecated members
will be removed in the next minor version.



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
