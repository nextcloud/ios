<!--
  SPDX-FileCopyrightText: Nextcloud GmbH
  SPDX-FileCopyrightText: 2026 Marino Faggiana
  SPDX-License-Identifier: GPL-3.0-or-later
-->

# Experimental adaptive media layout

The viewer has independent normal and adaptive controls. In adaptive mode, the
media occupies the area above an active horizontal fold, while standalone buttons and
controls occupy the area below it. Unfolding restores the normal layout.

## One experimental switch

The only feature switch is in [Views/NCMediaAdaptiveLayoutView.swift](Views/NCMediaAdaptiveLayoutView.swift):

```swift
enum NCMediaAdaptiveLayoutConfiguration {
    static let isAdaptiveLayoutEnabled = true
}
```

The switch is currently `true` for experimental verification. This enables
paged images, audio, video covers and both fullscreen video engines
(AVPlayer and VLC). Set it to `false` to use the normal layout. There is no
user-facing setting.

`NCMediaAdaptiveLayoutView.isLayoutEnabled` is the container's operating state,
not another feature switch. Video containers inherit the central value. The
paging bridge combines that value with the selected media type, returning to the
normal layout when an unsupported page is selected in the pager.

Shared background and control-color rules live in
`Helpers/NCMediaViewerAppearance.swift`: background resolution, control surfaces,
foreground/border colors and contrast appearance. Image/audio controls consume
these rules; the common lower panel applies the resolved appearance once.
Presented folded video uses black across both regions with light controls;
normal playback retains its existing appearance policy.

## Previewing the adaptive graphics

Open `Views/Controls/NCMediaAdaptiveControlsView.swift` in Xcode's canvas.
Its previews show the complete lower region, including actions, Previous/Next and
the rounded thumbnail island:

- Image, Audio and Video Cover in light and dark appearance.
- Video Cover while loading.
- Video Playback Controls, including the persistent footer.

These previews are independent of an active fold and use the current layout and
color settings. `Helpers/NCMediaViewerPreviewLoader.swift` supplies DEBUG-only
local sample metadata and the bundled `testimage` for thumbnails. No server,
download, audio playback or video engine is started. Interaction is disabled so
canvas exploration does not change saved playback preferences. These are graphics
previews, not verification of playback or navigation. Xcode still compiles preview
code; running/installing the complete app is unnecessary.

## State and ownership

Keep these responsibilities separate when editing the viewer:

| Data/state | Owner | Purpose |
| --- | --- | --- |
| File list, selected page and thumbnails | `NCMediaViewerModel` | One model shared by the pager and adaptive player footer. Video receives it as `mediaViewerModel`; no model is created for folding. |
| Metadata of a specific page | `NCMediaViewerPageModel` / content view `metadata` | Identifies that page's file, including neighboring pages; do not replace it with `selectedMetadata`. |
| Audio playback | `NCAudioViewerPlaybackRegistry` / `NCAudioViewerModel` | Existing audio player and position, observed by both normal and adaptive controls. |
| Video playback | Prepared AVPlayer/VLC playback and their controllers | Existing player engine; the adaptive footer adds paging data and selection callbacks only. |
| Feature enabled | `NCMediaAdaptiveLayoutConfiguration` | Central experimental switch. |
| Currently folded | `NCMediaAdaptiveLayoutView` | Geometry determines the active mode; SwiftUI content receives it through `mediaViewerIsFoldedLayout`. |
| Lower control heights and spacing | `NCMediaAdaptiveControlsLayout` | One set of unchanged geometry rules for image/audio/video. |
| Colors and appearance | `NCMediaViewerAppearance.swift` | Background and control palettes, independent of playback and geometry. |

The legacy `NCVideoAdaptiveLayoutView` and its excluded tests have been removed.
Images, audio and both video engines use the shared container. Normal control
compositions remain separate. Cleanup must preserve player lifecycle, selection
ordering and dismissal callbacks; graphical changes belong in the lower views.

## Changing colors and appearance

Start in [Helpers/NCMediaViewerAppearance.swift](Helpers/NCMediaViewerAppearance.swift).
The file separates three choices: content background, adaptive lower-panel
background and adaptive control colors. The lower panel follows content by
default, but has its own customization entry.

| What to change | Entry point | Used by |
| --- | --- | --- |
| Default content background | `ncViewerBackgroundStyle(for:)` | Normal and folded pages, paging collection backgrounds; the adaptive panel inherits it by default. |
| Background when controls are hidden | `ncViewerBackgroundStyle(for:isChromeHidden:)` | The same consumers; folding does not itself change `isChromeHidden`. |
| Adaptive lower-panel background | `ncViewerAdaptivePanelBackgroundStyle(contentStyle:)` | Common paged-media lower panel only; upper content and normal mode remain independent. |
| Presented adaptive video background | `ncViewerVideoPlaybackBackgroundStyle(for:isChromeHidden:isFoldedLayout:)` | AVPlayer/VLC root and rendering surface: folded playback stays black across both regions. |
| Mapping a background style to a color | `UIColor.ncViewerBackground(_:)` | UIKit backgrounds and the SwiftUI `Color` wrapper. |
| Control island/button fill | `UIColor.ncViewerAdaptiveControlBackground` | Adaptive image/audio islands, video-cover status controls and shared Close/Info/More buttons. |
| Control text and icon color | `UIColor.ncViewerAdaptiveControlForeground` | Adaptive image/audio and video-cover controls, the common lower panel and shared action buttons. |
| Control border color/width | `UIColor.ncViewerAdaptiveControlBorder` / `ncViewerAdaptiveControlBorderWidth` | All adaptive control islands and buttons, including thumbnails and video playback controls. |
| Control contrast in light/dark appearance | `ncViewerAdaptiveControlsColorScheme(for:inherited:)` | The common lower panel: black uses dark appearance, white uses light, system/custom inherit. |
| Adaptive audio played-track tint | `Color.ncViewerAdaptiveProgressTint(account:)` | Selected file account’s `NCBrandColor.shared.getElement(account:)`; other controls retain their palette. |
| Loading indicator tint | `Color.ncViewerProgressTint(_:)` | Media loading indicators. |

For example, changing an island fill requires editing only
`UIColor.ncViewerAdaptiveControlBackground`. Its SwiftUI counterpart forwards to that
same entry, so image/audio islands and UIKit action buttons stay consistent.
SwiftUI controls use `ncAdaptiveControlSurface(shape:)` for the shared fill and
border; UIKit action buttons read the same palette and border width. Circular and
capsule video controls use this surface too, rather than a separate glass style.
The border dynamically uses white at 22% opacity in dark appearance and black at
14% in light appearance, with the shared 0.5-point width. Adjust these values in
`ncViewerAdaptiveControlBorder` to tune the relief for every adaptive control.
Keep dynamic system colors unresolved until rendering, so appearance changes
continue to work. A custom background must contrast with its inherited controls.

To make only the lower paged-media panel orange, change its dedicated resolver:

```swift
func ncViewerAdaptivePanelBackgroundStyle(contentStyle: NCViewerBackgroundStyle) -> NCViewerBackgroundStyle {
    .custom(.systemOrange)
}
```

This does not change the upper content or normal mode. Returning `contentStyle`
restores the standard matching background. `.black` and `.white` also select the
matching control appearance; custom colors inherit appearance unless you change
`ncViewerAdaptiveControlsColorScheme(for:inherited:)`.

The common lower panel first resolves content from the selected media and
`model.isChromeHidden`, then passes that style through the dedicated panel resolver
and applies the resulting control appearance to its descendants.
Image/audio controls consume the shared palette rather than forcing dark mode.
Inline information uses a clear background so the containing island/panel owns
its fill; normal information sheets retain their system background. The UIKit
action host synchronizes its appearance with the SwiftUI panel on updates.
The folded upper audio artwork uses the background passed by its page, just as
normal audio does. The folded-layout environment value controls composition and
gestures; it must not become a second color switch.

These entries cover shared backgrounds and adaptive control colors. Normal
navigation, normal playback controls, thumbnail artwork, maps and fullscreen
AVPlayer/VLC presentation retain their existing styling. Do not change player
lifecycle or layout geometry to experiment with this palette. Spacing, corner
radii and island sizes remain in the corresponding controls views.

After changing colors, manually check light/dark appearance, tap-to-hide chrome,
fold/unfold, local and remote image information, audio controls and video-cover
loading. Verify readable text/icons in both regions and the existing fullscreen
video playback behavior. Local builds and tests remain user-run in Xcode.

## Components

| Component | Responsibility |
| --- | --- |
| `Helpers/NCMediaAdaptiveControlsLayout.swift` | Shared spacing, middle-area budget and navigation/footer heights for all adaptive media. |
| `Views/NCMediaAdaptiveLayoutView.swift` | Shared UIKit geometry, normal/adaptive visibility and layout change callback. Keeps the media view in place. |
| `Content/Image/Controls/NCImageControlsView.swift` | Normal thumbnail overlay, with the existing visibility, spacing and selection actions. Normal navigation and the information sheet remain in the hosting controller. |
| `Content/Image/Controls/NCImageAdaptiveControlsView.swift` | Always hosts the shared information view inside its fixed island, plus previous/next buttons; the shared panel owns actions and thumbnails. |
| `Views/Controls/NCMediaAdaptivePagingFooterView.swift` | Presented adaptive video footer: persistent previous/next and thumbnails sharing the viewer model, with dismissal-aware selection. |
| `Views/Controls/NCMediaAdaptiveControlsView.swift` | Lower composition for paged images, audio and video covers: standalone buttons, image-only inline information, playback/cover actions and thumbnails. Also contains the SwiftUI/UIKit bridge and its hosting support types. |
| `Content/Audio/Controls/NCAudioAdaptiveControlsView.swift` | Independent lower audio controls: ±10 seconds, Play/Pause, seeking and Previous/Next; Repeat/Auto-advance belong to the shared top row, with no information island. Observes the existing playback model. |
| `NCMediaViewerHostingController.swift` | Owns paged-media navigation actions, title updates and information loading. Hides the upper navigation bar when folded and routes information into the lower controls. |
| `Core/NCMediaViewerView.swift` | Selects the normal composition or experimental paging bridge using the central switch. |
| `Views/NCMediaViewerThumbnail.swift` | Shared thumbnail strip and collection implementation for all media; callers own normal/adaptive visibility and spacing. |
| `Content/Video/NCVideoPlaybackCoverView.swift` | Preview surface, shared cover presentation data/actions and the normal cover controls renderer. |
| `Content/Video/Controls/NCVideoAdaptivePlaybackCoverControlsView.swift` | Exclusive adaptive cover controls renderer, with the same playback/download actions as normal mode. |
| `Content/Video/Controls/NCVideoControlsView.swift` | Normal video controls and shared playback state. |
| `Content/Video/Controls/NCVideoAdaptiveControlsView.swift` | Independent adaptive video controls and standalone action buttons, observing the same playback state. |

The paging bridge retains its paging host across fold changes. The normal controls
host passes image gestures through outside the thumbnail strip. The video
controllers retain their existing AVPlayer/VLC instances and rendering surfaces;
layout changes do not recreate a player.

The image paging host disables its own safe-area regions to match the normal
pager's `ignoresSafeArea()`. This lets the media cover the area behind the
transparent navigation bar even with the experiment enabled and no active fold.
The controls hosts retain their own safe-area handling. The adaptive lower panel
extends through the bottom container safe area so its thumbnail lane stays near
the lower edge with the 12-point bottom margin (5-point outer spacing plus 7-point thumbnail clearance); top and side safe areas remain
in effect for actions. The lower host is created
only for a suitable active fold, retained across subsequent transitions and
clipped to its region. If its factory cannot supply controls, the normal layout
remains usable and the next layout pass may retry.

Video covers use the same split as images before fullscreen playback starts.
`NCVideoPlaybackCoverView` keeps the preview and image tap action in the upper
area. While folded, its preview is fitted and explicitly centered within the
upper region, without ignoring that region's safe-area edges. Its Play button, loading indicator, download message and Cancel action
move into the lower composition while folded and return to the normal overlay
when unfolded. Paging cells receive the shared adaptive context explicitly,
because each cell has its own SwiftUI hosting controller. Cover presentation data and actions (not SwiftUI control views) are
registered by media ID and owner, preventing neighboring or reused pages from
replacing or removing the selected cover's controls. The existing playback
and download actions are reused. Each registration keeps its owner and presentation
in one entry, so updates and removals cannot leave two separate registries out of
sync. Lower view construction is shared by initial creation and subsequent updates;
its controller forwards updates to the existing host without replacing that host.

## Editing the layout safely

### Normal/adaptive boundaries

The normal image overlay (`NCImageControlsView`) and the adaptive lower panel
(`NCMediaAdaptiveControlsView`) own separate compositions. Fullscreen video also
has separate visual implementations (`NCVideoControlsView` and
`NCVideoAdaptiveControlsView`). Video cover buttons have independent renderers:
`NCVideoPlaybackCoverControlsView` for normal mode and
`NCVideoAdaptivePlaybackCoverControlsView` for adaptive mode. Change adaptive
spacing, backgrounds and button graphics in those adaptive components.

Share media state and action callbacks, rather than normal/adaptive rendered
views. Keep the paging and playback hosts stable across layout changes. The
thumbnail renderer is still shared: layout-specific styling belongs in the
adaptive composition; editing its internal graphics affects both modes.
Adaptive images use `NCImageAdaptiveControlsView` as their independent layout,
but reuse the existing `NCMediaViewerDetailView` for the Info contents, just like
normal mode and other media. Changes inside that information view affect both
modes; its hosting island, buttons and thumbnail placement remain independent.

The adaptive image island always uses the same scrollable information panel.
It starts with available file metadata (including dimensions and coordinates),
without downloading the original. When the original already exists locally,
its EXIF is read automatically and the adaptive Info button is disabled. Reads
are deduplicated by media ID/etag; callbacks from another page/version are ignored.
For remote-only images, the existing Info action loads the original and updates
the same panel, then disables Info once the original is local. Normal-mode Info
behavior is unchanged. Data is retained for the last inspected image only,
matched by media ID, and remains visible after closing Info. The adaptive caller
sets `showsOnlyAvailableData` to omit missing camera/lens/exposure fields; the
default remains false for normal sheets. The filename is displayed by the viewer
header, not repeated inside the information panel. Both information presentations
prefer the EXIF date and use the file date when it is unavailable. The normal
viewer header uses the file date, which may differ from the EXIF capture date.
EXIF loading delivers one result after reading the original and resolving any
location, so the normal sheet cannot retain an earlier incomplete result. Previous/next buttons
remain outside the fixed island and work while information is open. Map taps
retain the existing Maps action.
The two `Adaptive Image` canvas previews isolate these visual states. The adaptive
image panel uses the standard viewer background and system-colored control
islands, text and symbols. Previous/next buttons use a compact icon/text row and
match the top action row at 60 points, using the same `actionsHeight` setting;
in very small regions navigation shrinks to fit. The
remaining space is a bounded information island. Both sizes depend only on the
available region, not Info visibility or metadata length. Details scroll inside
the island without moving the buttons or thumbnails. Both regions follow the standard appearance/chrome rule: system background
when chrome is visible, black with contrasting controls when chrome is hidden.
Folding itself does not change that rule. Fullscreen video retains its black
playback background. Each retained page
host observes fold changes and passes that state to its content; the image zoom
surface and UIKit paging backgrounds use the same resolution rule. Unfolding
retains the same appearance/chrome rule without replacing the page host.

Fullscreen video currently uses fixed proxy frames to exclude control touches
from player gestures. When repositioning those controls, update the proxy frames
in `NCVideoAdaptiveControlsView` together with its SwiftUI layout. In the paged
lower panel, horizontal swipes belong to the middle area: future sliders or
other horizontal controls need their own gesture area so scrubbing cannot also
change pages. These are interaction requirements, not dependencies on normal
mode graphics.

The adaptive paging panel is shared, not an image-specific container. In
`Views/Controls/NCMediaAdaptiveControlsView.swift`, edit the top-level `VStack`
to arrange standalone buttons, the flexible `mediaControls` area and thumbnails.
There is no adaptive `UINavigationBar`, navigation item or title.
`NCMediaAdaptiveActionsView` contains standalone Close, Info (paged media) and
More buttons; rearrange or replace them independently of the normal navigation.
The deferred More menu uses the button itself as its popover anchor.
The same row contains a filename island for every media type, including presented
video. Buttons are square (`actionsHeight` wide/high), while the filename uses
the remaining width: a circular 32-point AppIcon avatar, an 8-point gap and a
leading-aligned filename on one line, truncated at the end. `ViewerAppIcon` in
`Brand/Custom.xcassets` copies the AppIcon image into a regular image asset for
the controls and Canvas previews. Image: Close, Name, Info, More. Audio:
Close, Repeat, Name, Auto-advance, More. Video: Close, Name, More. The row height
and the lower thumbnail/navigation positions are unchanged.
`NCMediaAdaptiveActionsView.preferredHeight` supplies the shared button height for
paged media and fullscreen video. Buttons and thumbnails have priority over the
flexible middle content when the lower panel shrinks; check very small windows
manually because fixed controls cannot fit every possible region.
Edit `mediaControls` to add or change media-specific lower content. Keep the
thumbnail strip outside that content and the information panel: with multiple
pages it remains visible in adaptive mode, even when the user hides normal
chrome or opens information. Its height matches the normal thumbnail lane;
the area remains reserved even with a single page, when no selection strip is
needed. The lane retains its preferred height with 7 points of additional bottom clearance,
configured by `NCMediaAdaptiveControlsLayout.thumbnailBottomInset`.
`ncAdaptiveThumbnailIsland()` in `NCMediaViewerThumbnail.swift` supplies the shared
rounded preview island, with the adaptive button background and a small horizontal
inset. Both adaptive containers use it; normal thumbnails keep their existing
appearance. The island adds no vertical height or new tap action. Adaptive sections and
buttons use 5-point gaps; standalone actions are separate equally sized buttons
with 60-point height, configured by `NCMediaAdaptiveControlsLayout.actionsHeight`. The middle content is clipped and scrolls independently. This shared
area covers paged images, audio and video covers. Presented adaptive video uses
`NCMediaAdaptivePagingFooterView` for the same fixed thumbnail lane and previous/next
position. Normal fullscreen video does not create this footer.

Page swipes remain available on the upper media surface. In the folded layout,
horizontal swipes in the middle controls area also select the previous/next page,
using the same selection flow as the thumbnail strip. This excludes the action
row and thumbnail strip. When information is open, lower page swipes are ignored
to preserve vertical scrolling and map gestures. Page swipes are also ignored
while another page transition is in progress. Audio handles lower swipes locally
on the playback island's free background, button/time rows and previous/next row.
The seek slider is excluded so its horizontal drags only seek within the current
audio. Local swipes call the same previous/next actions, with the same page-boundary
and transition guards; upper swipes and thumbnails remain available.

`NCMediaViewerThumbnailStrip` holds the same metadata, loading and selection
bindings for both layouts. The normal overlay retains its existing visibility,
bottom spacing and gestures. Cover presentation holds playback/download state
and actions; it does not own or create a player.

The UIKit paging bridge remains in the same file under `Stable paging bridge`.
Do not rebuild its media host to rearrange lower controls. Fullscreen AVPlayer/VLC
controls retain their separate implementations. Both presenters receive the same
viewer model for their adaptive footer. Selecting a thumbnail or previous/next
stops and dismisses the current player before selecting the target page, using
the existing paging flow without auto-starting another video. Selecting the current
thumbnail leaves playback running. Repeated selections are gated during dismissal.
`selectPageFromPlayback` owns the common guards/reset/selection sequence; the
engine extensions only choose which presenter to dismiss. Close forwards the
existing `onClose` callback directly.
Footer selection does not invoke the viewer's Close action. Folding retains the
player and footer host; resizing only updates the footer geometry. The video content
view receives no navigation bar: each player controller owns its navigation.
The visible-page callback carries metadata only; background rendering stays
in the appearance/paging layers rather than being passed into title updates. Player gestures
exclude the footer as well as the existing control hit frames.

Audio keeps its `@StateObject` and playback lifecycle modifiers above the visual
layout switch in `NCAudioViewerContentView`. The upper folded region shows only
artwork (or the waveform fallback) on the standard viewer background. The lower panel obtains the same
model from `NCAudioViewerPlaybackRegistry`, without loading or creating a player.
Folding changes the composition, preserving playback position and repeat/advance
options. Normal audio geometry and playback lifecycle remain unchanged.

Audio and video do not reserve an inline information island in adaptive mode.
Audio uses the middle area for playback and previous/next controls.
Its top action row is Close, Repeat, Auto-advance and More. Only audio shows
these two options there; the middle playback row is −10 seconds, Play/Pause and
+10 seconds, each in its own button island directly below the header. These three
buttons fill the remaining middle area and absorb changes in available height.
A separate 60-point island above Previous/Next contains the seek slider and a
remaining-time countdown on its right. Normal mode retains its elapsed/duration
labels. There is no empty spacer between the
rows. The slider island shrinks only when the region cannot accommodate it. The header observes the existing playback options for icon updates. Video covers
keep their playback/download controls visible. The adaptive Info button is shown
only for images; audio/video show Close and More without an empty button slot.
Normal mode also shows Info only for images. Its navigation items update when
paging between media types, keeping More available for audio/video. Image
information sheets retain their existing behavior.

## Layout and compatibility

With the switch `false`, images use the normal SwiftUI pager and thumbnail overlay.
Video containers retain the original eight edge constraints. Adaptive controls
and image hosting support are not created, and fold regions are not queried.

When enabled, the shared container reads `reservedRegions(kind: .division)` in
`layoutSubviews`, guarded by `#available(iOS 27.1, *)`. It accepts an active,
horizontal region spanning the viewer width, with usable space above and below.
It does not measure the hinge angle or enforce an exact 90-degree position.
Without a suitable region, the normal layout remains visible.

The API requires the Xcode 27.1 SDK, matching the CI configuration. These changes
do not raise the deployment target and retain compatibility with iOS 18; older
systems use the normal layout.

When paged media enters or leaves the folded layout, its open information panel is
closed. In the folded layout, reopening information displays the existing
`NCMediaViewerDetailView` below the image, using the existing download/EXIF flow.
Live Photo badges and image-analysis interactions still belong to the image
content; they have not been relocated into the lower controls.
The LIVE badge uses the owning viewer's actual safe area in normal mode, including
side bars after rotation, with 8-point top and 12-point leading clearance. In
folded mode it keeps 12-point upper/leading margins without navbar clearance.
The legacy inset remains only a fallback when no owning viewer is attached,
such as an isolated canvas preview. Verify both rotations and tap-to-hide chrome.

## Verification

Preview selection resolves and caches the destination metadata before publishing
the new selected index. This prevents an uncached image from temporarily losing
its adaptive controls or switching to normal layout while its type is unknown.
A metadata lookup superseded by another selection cannot commit a stale page.
Check previous/next and thumbnail selection with uncached images and delayed
metadata responses; missing metadata still follows the existing fallback.

Shared viewer optimizations keep the existing loading and playback policies:
the viewer model normalizes its source identifiers once during initialization,
and updates cached pages without searching the full identifier list. Thumbnail
loading stays explicitly on the main actor for UI/cache updates; only image
decoding runs in the background. Missing previews and failed image decoding use
the same placeholder path. Recheck duplicate/missing initial identifiers,
thumbnail failures, audio artwork and page deletion while previews are loading.

[NCMediaAdaptiveLayoutViewTests.swift](../../../Tests/NextcloudUnitTests/NCMediaAdaptiveLayoutViewTests.swift)
covers disabled mode, retained image hosting, independent controls, standalone action callbacks, video-cover
action ownership, fold geometry,
unfolding, initial adaptive constraints, deferred creation of lower controls and
recovery when lower controls are unavailable. These tests do not establish runtime
zoom or playback continuity on a folded device.
The no-fold resizing case covers portrait, landscape, tablet-sized and narrow
window bounds while preserving hidden normal controls and avoiding lower-host
creation. It does not simulate a particular device or system reserved regions.

[NCImageZoomViewTests.swift](../../../Tests/NextcloudUnitTests/NCImageZoomViewTests.swift)
also covers centering of horizontal, vertical and square images through a full /
upper-region / full resize, and zoom/focal-point preservation through the same
transition. Image rendering has not been changed for the video-cover correction.

Static review compares the normal thumbnail composition and media source files
with the previous implementation. SwiftLint and project-reference checks cover
source consistency, not runtime behavior.
Local builds and tests have not been run, following the repository instructions.

Verify the experiment in Xcode:

- With `false`: image zoom, paging, thumbnails, information sheets and AVPlayer/VLC playback.
- With `true`: folding/unfolding, retained zoom, playback continuity, lower buttons and information, video-cover Play/loading/Cancel actions, and selection of other media types.
- On iOS 18: normal layout without access to the newer fold API.

The lower layout and relocation of content-specific image controls remain
experimental work.

### Incremental regression checks

Start with the normal layout before testing the fold:

1. With the switch `false`, verify image zoom/paging, thumbnail selection, audio
   playback, video-cover Play/loading/Cancel, information and AVPlayer/VLC playback.
2. With `true` and no active fold, repeat the same flows, especially the transparent
   navigation bar, tap-to-hide controls and the thumbnail selection gestures.
3. With an active fold, verify images and video covers: upper media only, lower
   actions and thumbnails, information without losing the strip, and selecting
   pages by swiping both the upper surface and the middle controls area. Check
   that vertical drags do not change pages and map gestures in information do
   not select another page. Also check selecting
   neighboring pages during a download. Verify Close, Info and More buttons,
   including share popovers on iPad. Check horizontal and vertical video covers
   for centering in the upper region before/after loading and unfolding. The
   `Video Playback Cover - Folded Upper Region` canvas preview isolates that area.
   For audio, verify artwork above, playback controls below without an information island, and
   the same fixed thumbnail lane. Check seeking, ±10-second jumps, repeat, auto-advance and
   previous/next; dragging the seek bar must not change pages. Fold/unfold during
   playback and check that sound and position continue without restarting.
   In folded mode, compare a local original with a preview-only image: local EXIF
   should appear without tapping Info; preview-only images should not download
   automatically. After Info downloads the original, check that its button is
   disabled and page changes cannot apply EXIF from the previous image.
4. Fold/unfold repeatedly while loading or playing; check position and playback
   continuity with each engine. In folded playback, check that previous/next and
   thumbnails keep the same bottom position as images/audio, including a single
   page's reserved lane. Select image, audio and video thumbnails and verify the
   player stops before the target page appears. Tapping the current thumbnail must
   leave playback running. Check rapid selections, dragging thumbnails, seeking,
   subtitle/audio-track menus, pause, close and folding/unfolding. Normal playback
   must not show the footer.
5. Repeat on iOS 18 to verify the normal fallback.
6. With the switch `true`, repeat normal flows on iPhone and iPad without a fold.
   Rotate the device and resize iPad windows, with controls both visible and
   hidden. Verify thumbnail selection, zoom, navigation, information sheets,
   playback and iPad menu/share popover anchors. On Duo, also check the outer
   display, fully open inner display and a vertical book-like fold: these use
   the normal composition. Only a suitable active horizontal division enables
   the upper-media/lower-controls composition.

A successful build and these checks do not establish readiness on a physical
foldable device. Validate actual reserved regions, window resizing and transitions
on supported hardware when available. Keep the experiment out of release claims
until those behaviors and the remaining media integrations have been verified.
