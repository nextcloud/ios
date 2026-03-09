//
//  View+Extension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 29/12/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

import SwiftUI

extension View {
    func complexModifier<V: View>(@ViewBuilder _ closure: (Self) -> V) -> some View {
        closure(self)
    }

    /// Use this on preview views that are used in snapshot testing. It prevents the snapashot library from complaining that the view has a size of 0
    /// Check: https://github.com/pointfreeco/swift-snapshot-testing/issues/738
    func frameForPreview() -> some View {
        return frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    }

    func hiddenConditionally(isHidden: Bool) -> some View {
        isHidden ? AnyView(self.hidden()) : AnyView(self)
    }

    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func onFirstAppear(perform action: @escaping () -> Void) -> some View {
        modifier(ViewFirstAppearModifier(perform: action))
    }

    /// Applies a font and caps Dynamic Type to the specified range.
    ///
    /// iOS Typography Reference (SwiftUI)
    ///
    /// Font Style     Base Size   Typical Usage                     Suggested Dynamic Type Cap
    /// -----------------------------------------------------------------------------------------
    /// largeTitle      ~34 pt      Large screen titles                      .accessibility3
    /// title               ~28 pt      Primary titles                              .accessibility3
    /// title2             ~22 pt      Important subtitles                     .accessibility2
    /// title3            ~20 pt       Small titles / list icons                .accessibility2
    /// headline       ~17 pt      Section headers (semibold)        .accessibility2
    /// body            ~17 pt      Main readable text                      .accessibility2
    /// callout          ~16 pt      Highlighted secondary text        .accessibility2
    /// subheadline ~15 pt      Secondary information               .accessibility1
    /// footnote       ~13 pt      Metadata / notes                        .xxxLarge
    /// caption         ~12 pt      Captions / small descriptions    .xxLarge
    /// caption2       ~11 pt      Very small labels                        .xLarge
    ///
    /// Practical guideline:
    ///
    /// title*          → cap around .accessibility2 / .accessibility3
    /// body          → cap around .accessibility2
    /// metadata   → cap around .xxxLarge
    /// caption      → cap around .xxLarge
    ///
    /// Example:
    ///
    /// Text("Privacy and Legal Policy")
    ///     .cappedFont(.body, maxDynamicType: .accessibility2)
    ///
    /// - Parameters:
    ///   - font: The SwiftUI font to apply (e.g. .body, .title3).
    ///   - maxDynamicType: The maximum Dynamic Type size allowed for this view.
    /// - Returns: A view configured with the given font and Dynamic Type cap.
    /// 
    func cappedFont(_ font: Font, maxDynamicType: DynamicTypeSize = .accessibility2) -> some View {
        self
            .font(font)
            .dynamicTypeSize(.xSmall ... maxDynamicType)
    }
}

struct ViewFirstAppearModifier: ViewModifier {
    @State private var didAppearBefore = false
    private let action: () -> Void

    init(perform action: @escaping () -> Void) {
        self.action = action
    }

    func body(content: Content) -> some View {
        content.onAppear {
            guard !didAppearBefore else { return }
            didAppearBefore = true
            action()
        }
    }
}
