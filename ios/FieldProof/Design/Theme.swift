import SwiftUI

/// Park-poster design tokens (docs/STYLE-GUIDE.md).
enum Theme {

    // MARK: - Palette

    enum Palette {
        static let paper = Color(hex: 0xF3E9D2)
        static let paperDeep = Color(hex: 0xE6D8B8)
        static let pine = Color(hex: 0x1F3D2B)
        static let pineLight = Color(hex: 0x3E6B4E)
        static let sienna = Color(hex: 0xC4552D)
        static let mustard = Color(hex: 0xD9A441)
        static let sky = Color(hex: 0x7A9EAB)
        static let charcoal = Color(hex: 0x2B2B2B)
        static let chalk = Color(hex: 0xFBF7EE)
    }

    // MARK: - Typography

    enum Typeface {
        /// Bebas Neue: poster titles and big numbers.
        static func display(_ size: CGFloat = 34) -> Font { .custom("BebasNeue-Regular", size: size, relativeTo: .largeTitle) }
        /// Oswald: headings, labels, buttons.
        static func heading(_ size: CGFloat = 18) -> Font { .custom("Oswald-SemiBold", size: size, relativeTo: .headline) }
        static func label(_ size: CGFloat = 15) -> Font { .custom("Oswald-Medium", size: size, relativeTo: .subheadline) }
        /// Source Serif 4: notes, OCR text, descriptions.
        static func body(_ size: CGFloat = 16) -> Font { .custom("SourceSerif4-Regular", size: size, relativeTo: .body) }
        static func bodyBold(_ size: CGFloat = 16) -> Font { .custom("SourceSerif4-Semibold", size: size, relativeTo: .body) }
        /// JetBrains Mono: hashes and document ids.
        static func mono(_ size: CGFloat = 13) -> Font { .custom("JetBrainsMono-Regular", size: size, relativeTo: .caption) }
    }

    // MARK: - Spacing and shape

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let chip: CGFloat = 6
        static let card: CGFloat = 10
    }
}
