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

## Components

| Component | Responsibility |
| --- | --- |
| `Views/NCMediaAdaptiveLayoutView.swift` | Shared UIKit geometry, normal/adaptive visibility and layout change callback. Keeps the media view in place. |
| `Content/Image/Controls/NCImageControlsView.swift` | Normal thumbnail overlay, with the existing visibility, spacing and selection actions. Normal navigation and the information sheet remain in the hosting controller. |
| `Content/Image/Controls/NCImageAdaptiveControlsView.swift` | Always hosts the shared information view inside its fixed island, plus previous/next buttons; the shared panel owns actions and thumbnails. |
| `Views/Controls/NCMediaAdaptiveControlsView.swift` | Lower composition for paged images, audio and video covers: standalone buttons, inline information, cover actions and thumbnails. Also contains the SwiftUI/UIKit bridge and its hosting support types. |
| `Content/Audio/Controls/NCAudioAdaptiveControlsView.swift` | Independent lower audio controls: available information, repeat/restart/play/pause/auto-advance, seeking and previous/next. Observes the existing playback model. |
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
the lower edge with the explicit 5-point margin; top and side safe areas remain
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
default remains false for normal sheets. The selectable filename appears at
the top in both modes, wrapping long names instead of truncating them.
The file date is used when an EXIF date is unavailable. Previous/next buttons
remain outside the fixed island and work while information is open. Map taps
retain the existing Maps action.
The two `Adaptive Image` canvas previews isolate these visual states. The adaptive
image panel uses a black background, subtly shaded graphite controls and bold
white text and symbols. Previous/next buttons use a compact icon/text row and
occupy 18% of the middle area's height (70% less than the initial 60%), with a
44-point minimum when space permits; the
remaining space is a bounded information island. Both sizes depend only on the
available region, not Info visibility or metadata length. Details scroll inside
the island without moving the buttons or thumbnails. Dark appearance is scoped to the adaptive lower host and its controls;
normal controls retain their existing appearance. Folded upper media is always
black, independently of appearance and tap-to-hide chrome. Each retained page
host observes fold changes and passes that state to its content; the image zoom
surface and UIKit paging backgrounds use the same resolution rule. Unfolding
restores the normal appearance/chrome rule without replacing the page host.

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
`NCMediaAdaptiveActionsView.preferredHeight` supplies the shared button height for
paged media and fullscreen video. Buttons and thumbnails have priority over the
flexible middle content when the lower panel shrinks; check very small windows
manually because fixed controls cannot fit every possible region.
Edit `mediaControls` to add or change media-specific lower content. Keep the
thumbnail strip outside that content and the information panel: with multiple
pages it remains visible in adaptive mode, even when the user hides normal
chrome or opens information. Its height matches the normal thumbnail lane;
the area remains reserved even with a single page, when no selection strip is
needed. Extra vertical thumbnail padding is removed. Adaptive sections and
buttons use 5-point gaps; standalone actions are separate equally sized buttons
with 44-point height. The middle content is clipped and scrolls independently. This shared
area currently covers paged images, audio and video covers; fullscreen video
still needs its own thumbnail integration.

Page swipes remain available on the upper media surface. In the folded layout,
horizontal swipes in the middle controls area also select the previous/next page,
using the same selection flow as the thumbnail strip. This excludes the action
row and thumbnail strip. When information is open, lower page swipes are ignored
to preserve vertical scrolling and map gestures. Page swipes are also ignored
while another page transition is in progress. Lower audio controls also exclude
page swipes so seeking cannot accidentally change pages; use previous/next,
thumbnails or the upper surface instead.

`NCMediaViewerThumbnailStrip` holds the same metadata, loading and selection
bindings for both layouts. The normal overlay retains its existing visibility,
bottom spacing and gestures. Cover presentation holds playback/download state
and actions; it does not own or create a player.

The UIKit paging bridge remains in the same file under `Stable paging bridge`.
Do not rebuild its media host to rearrange lower controls. Fullscreen AVPlayer/VLC
controls still have their existing separate implementations. Connecting their
thumbnail strip is follow-up integration work.

Audio keeps its `@StateObject` and playback lifecycle modifiers above the visual
layout switch in `NCAudioViewerContentView`. The upper folded region shows only
artwork (or the waveform fallback) on black. The lower panel obtains the same
model from `NCAudioViewerPlaybackRegistry`, without loading or creating a player.
Folding changes the composition, preserving playback position and repeat/advance
options. Normal audio geometry and playback lifecycle remain unchanged.

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
   For audio, verify artwork above, information and playback controls below, and
   the same fixed thumbnail lane. Check seeking, restart, repeat, auto-advance and
   previous/next; dragging the seek bar must not change pages. Fold/unfold during
   playback and check that sound and position continue without restarting.
   In folded mode, compare a local original with a preview-only image: local EXIF
   should appear without tapping Info; preview-only images should not download
   automatically. After Info downloads the original, check that its button is
   disabled and page changes cannot apply EXIF from the previous image.
4. Fold/unfold repeatedly while loading or playing; check position and playback
   continuity with each engine. Fullscreen video thumbnails are still pending.
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
