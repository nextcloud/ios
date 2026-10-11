<!--
  SPDX-FileCopyrightText: Nextcloud GmbH
  SPDX-FileCopyrightText: 2026 Marino Faggiana
  SPDX-License-Identifier: GPL-3.0-or-later
-->

# Experimental adaptive media layout

The viewer has independent normal and adaptive controls. In adaptive mode, the
media occupies the area above an active horizontal fold, while navigation and
controls occupy the area below it. Unfolding restores the normal layout.

## One experimental switch

The only feature switch is in [Views/NCMediaAdaptiveLayoutView.swift](Views/NCMediaAdaptiveLayoutView.swift):

```swift
enum NCMediaAdaptiveLayoutConfiguration {
    static let isAdaptiveLayoutEnabled = true
}
```

The switch is currently `true` for experimental verification. This enables
the image integration and both fullscreen video engines
(AVPlayer and VLC). Set it to `false` to use the normal layout. There is no
user-facing setting. Audio does not yet have an
adaptive controls view.

`NCMediaAdaptiveLayoutView.isLayoutEnabled` is the container's operating state,
not another feature switch. Video containers inherit the central value. The
image bridge combines that value with the selected media type, returning to the
normal layout when an audio or video page is selected in the image pager.

## Components

| Component | Responsibility |
| --- | --- |
| `Views/NCMediaAdaptiveLayoutView.swift` | Shared UIKit geometry, normal/adaptive visibility and layout change callback. Keeps the media view in place. |
| `Content/Image/Controls/NCImageControlsView.swift` | Normal thumbnail overlay, with the existing visibility, spacing and selection actions. Normal navigation and the information sheet remain in the hosting controller. |
| `Content/Image/Controls/NCImageAdaptiveControlsView.swift` | Separate lower composition: navigation, inline information and thumbnails. Also contains the SwiftUI/UIKit bridge and its hosting support types. |
| `NCMediaViewerHostingController.swift` | Owns image navigation actions, title updates and information loading. Hides the upper navigation bar when folded and routes information into the lower controls. |
| `Core/NCMediaViewerView.swift` | Selects the normal composition or experimental image bridge using the central switch. |
| `Content/Video/Controls/NCVideoControlsView.swift` | Normal video controls and shared playback state. |
| `Content/Video/Controls/NCVideoAdaptiveControlsView.swift` | Independent adaptive video controls and lower navigation, observing the same playback state. |

The image bridge retains its paging host across fold changes. The normal controls
host passes image gestures through outside the thumbnail strip. The video
controllers retain their existing AVPlayer/VLC instances and rendering surfaces;
layout changes do not recreate a player.

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

When an image enters or leaves the folded layout, its open information panel is
closed. In the folded layout, reopening information displays the existing
`NCMediaViewerDetailView` below the image, using the existing download/EXIF flow.
Live Photo badges and image-analysis interactions still belong to the image
content; they have not been relocated into the lower controls.

## Verification

[NCMediaAdaptiveLayoutViewTests.swift](../../../Tests/NextcloudUnitTests/NCMediaAdaptiveLayoutViewTests.swift)
covers disabled mode, retained image hosting, independent controls, fold geometry,
unfolding and initial adaptive constraints. These tests do not establish runtime
zoom or playback continuity on a folded device.

Static review compared the normal thumbnail composition and media source files
with the previous implementation. SwiftLint and project-reference checks passed.
Local builds and tests have not been run, following the repository instructions.

Verify the experiment in Xcode:

- With `false`: image zoom, paging, thumbnails, information sheets and AVPlayer/VLC playback.
- With `true`: folding/unfolding, retained zoom, playback continuity, lower navigation and information, and selection of other media types.
- On iOS 18: normal layout without access to the newer fold API.

The lower layout and relocation of content-specific image controls remain
experimental work.
