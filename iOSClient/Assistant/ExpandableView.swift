//
//  ExpandableView.swift
//  Nextcloud
//
//  Created by Milen on 10.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI

public struct ExpandableView<Content: View>: View {

    @State private var isExpanded: Bool = false
    @State private var isTruncated: Bool = false

    @State private var intrinsicSize: CGSize = .zero
    @State private var truncatedSize: CGSize = .zero
    @State private var moreTextSize: CGSize = .zero

    var content: () -> Content

//    private let text: String
    internal var font: Font = .body
    internal var color: Color = .primary
    internal var lineLimit: Int = 3
    internal var moreButtonText: String = "more"
    internal var moreButtonFont: Font?
    internal var moreButtonColor: Color = .accentColor
    internal var expandAnimation: Animation = .default
    internal var trimMultipleNewlinesWhenTruncated: Bool = true

    /**
     Initializes a new `ExpandableText` instance with the specified text string, trimmed of any leading or trailing whitespace and newline characters.
     - Parameter text: The initial text string to display in the `ExpandableText` view.
     - Returns: A new `ExpandableText` instance with the specified text string and trimming applied.
     */
//    public init(_ content: Content) {
////        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
//    }

    public var body: some View {
        content()
            .lineLimit(isExpanded ? nil : lineLimit)
            .applyingTruncationMask(moreTextSize: moreTextSize, enabled: !isExpanded && isTruncated)
            .readSize { size in
                truncatedSize = size
                isTruncated = truncatedSize != intrinsicSize
            }
            .background(
                Text("More")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .readSize { size in
                        intrinsicSize = size
                        isTruncated = truncatedSize != intrinsicSize
                    }
            )
            .background(
                Text(moreButtonText)
                    .font(moreButtonFont ?? font)
                    .hidden()
                    .readSize { moreTextSize = $0 }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !isExpanded, isTruncated {
                    withAnimation { isExpanded.toggle() }
                }
            }
            .modifier(OverlayAdapter(alignment: .trailingLastTextBaseline, view: {
                if isTruncated {
                    Button {
                        withAnimation(expandAnimation) { isExpanded.toggle() }
                    } label: {
                        Text(moreButtonText)
                            .font(moreButtonFont ?? font)
                            .foregroundColor(moreButtonColor)
                    }
                }
            }))
    }

//    private var content: some View {
//        Text(.init(
//            trimMultipleNewlinesWhenTruncated
//                ? (!isExpanded && isTruncated ? textTrimmingDoubleNewlines : text)
//                : text
//        ))
//        .font(font)
//        .foregroundColor(color)
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }

//    private var textTrimmingDoubleNewlines: String {
//        text.replacingOccurrences(of: #"\n\s*\n"#, with: "\n", options: .regularExpression)
//    }
}

public extension ExpandableView {

    /**
     Sets the font for the text in the `ExpandableText` instance.
     - Parameter font: The font to use for the text. Defaults to `body`
     - Returns: A new `ExpandableText` instance with the specified font applied.
     */
    func font(_ font: Font) -> Self {
        var copy = self
        copy.font = font
        return copy
    }

    /**
     Sets the foreground color for the text in the `ExpandableText` instance.
     - Parameter color: The foreground color to use for the text. Defaults to `primary`
     - Returns: A new `ExpandableText` instance with the specified foreground color applied.
     */
    func foregroundColor(_ color: Color) -> Self {
        var copy = self
        copy.color = color
        return copy
    }

    /**
     Sets the maximum number of lines to use for rendering the text in the `ExpandableText` instance.
     - Parameter limit: The maximum number of lines to use for rendering the text. Defaults to `3`
     - Returns: A new `ExpandableText` instance with the specified line limit applied.
     */
    func lineLimit(_ limit: Int) -> Self {
        var copy = self
        copy.lineLimit = limit
        return copy
    }

    /**
     Sets the text to use for the "show more" button in the `ExpandableText` instance.
     - Parameter moreText: The text to use for the "show more" button. Defaults to `more`
     - Returns: A new `ExpandableText` instance with the specified "show more" button text applied.
     */
    func moreButtonText(_ moreText: String) -> Self {
        var copy = self
        copy.moreButtonText = moreText
        return copy
    }

    /**
     Sets the font to use for the "show more" button in the `ExpandableText` instance.
     - Parameter font: The font to use for the "show more" button. Defaults to the same font as the text
     - Returns: A new `ExpandableText` instance with the specified "show more" button font applied.
     */
    func moreButtonFont(_ font: Font) -> Self {
        var copy = self
        copy.moreButtonFont = font
        return copy
    }

    /**
     Sets the color to use for the "show more" button in the `ExpandableText` instance.
     - Parameter color: The color to use for the "show more" button. Defaults to `accentColor`
     - Returns: A new `ExpandableText` instance with the specified "show more" button color applied.
     */
    func moreButtonColor(_ color: Color) -> Self {
        var copy = self
        copy.moreButtonColor = color
        return copy
    }

    /**
     Sets the animation to use when expanding the `ExpandableText` instance.
     - Parameter animation: The animation to use for the expansion. Defaults to `default`
     - Returns: A new `ExpandableText` instance with the specified expansion animation applied.
     */
    func expandAnimation(_ animation: Animation) -> Self {
        var copy = self
        copy.expandAnimation = animation
        return copy
    }

    /**
     Sets whether multiple consecutive newline characters should be trimmed when truncating the text in the `ExpandableText` instance.
     - Parameter value: A boolean value indicating whether to trim multiple consecutive newline characters. Defaults to `true`
     - Returns: A new `ExpandableText` instance with the specified trimming behavior applied.
     */
    func trimMultipleNewlinesWhenTruncated(_ value: Bool) -> Self {
        var copy = self
        copy.trimMultipleNewlinesWhenTruncated = value
        return copy
    }
}

#Preview {
//    let loremIpsum = """
//    Lorem ipsum dolor sit amet, consectetur adipiscing
//    elit, sed do eiusmod tempor incididunt ut labore et
//    dolore magna aliqua. Ut enim ad minim veniam, quis
//    nostrud exercitation ullamco laboris nisi ut aliquip
//    ex ea commodo consequat. Duis aute irure dolor in
//    reprehenderit in voluptate velit esse cillum dolore
//    eu fugiat nulla pariatur.
//    """

    //                    Text(task.input ?? "")
    ExpandableView {
        Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.")
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

internal struct OverlayAdapter<V: View>: ViewModifier {
    let alignment: Alignment
    let view: () -> V

    init(alignment: Alignment, @ViewBuilder view: @escaping () -> V) {
        self.alignment = alignment
        self.view = view
    }

    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.overlay(alignment: alignment, content: view)
        } else {
            content.overlay(view(), alignment: alignment)
        }
    }
}

private struct TruncationTextMask: ViewModifier {

    let size: CGSize
    let enabled: Bool

    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        if enabled {
            content
                .mask(
                    VStack(spacing: 0) {
                        Rectangle()
                        HStack(spacing: 0){
                            Rectangle()
                            HStack(spacing: 0) {
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        Gradient.Stop(color: .black, location: 0),
                                        Gradient.Stop(color: .clear, location: 0.9)
                                    ]),
                                    startPoint: layoutDirection == .rightToLeft ? .trailing : .leading,
                                    endPoint: layoutDirection == .rightToLeft ? .leading : .trailing
                                )
                                .frame(width: size.width, height: size.height)

                                Rectangle()
                                    .foregroundColor(.clear)
                                    .frame(width: size.width)
                            }
                        }.frame(height: size.height)
                    }
                )
        } else {
            content
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

internal extension View {
    func applyingTruncationMask(moreTextSize: CGSize, enabled: Bool) -> some View {
        modifier(TruncationTextMask(size: moreTextSize, enabled: enabled))
    }
}

// https://www.fivestars.blog/articles/swiftui-share-layout-information/
private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

internal extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}
