import SwiftUI

enum AuraColor {
    static let midnight = Color(red: 13 / 255, green: 27 / 255, blue: 42 / 255)
    static let ocean = Color(red: 27 / 255, green: 38 / 255, blue: 59 / 255)
    static let slate = Color(red: 44 / 255, green: 62 / 255, blue: 80 / 255)
    static let mist = Color(red: 234 / 255, green: 242 / 255, blue: 248 / 255)
    static let fog = Color(red: 184 / 255, green: 197 / 255, blue: 208 / 255)
    static let steel = Color(red: 115 / 255, green: 132 / 255, blue: 150 / 255)
    static let interactive = Color(red: 58 / 255, green: 134 / 255, blue: 255 / 255)
    static let cyan = Color(red: 76 / 255, green: 201 / 255, blue: 240 / 255)
    static let success = Color(red: 82 / 255, green: 183 / 255, blue: 136 / 255)
    static let warning = Color(red: 244 / 255, green: 162 / 255, blue: 97 / 255)
    static let error = Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255)
}

enum AuraTypography {
    static let display = Font.largeTitle.bold()
    static let largeTitle = Font.largeTitle.bold()
    static let title = Font.title2.weight(.semibold)
    static let headline = Font.headline
    static let body = Font.body
    static let callout = Font.callout
    static let subheadline = Font.subheadline
    static let footnote = Font.footnote
    static let caption = Font.caption
}

enum AuraSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let section: CGFloat = 32
    static let xxl: CGFloat = 40
    static let screen: CGFloat = 24
}

enum AuraRadius {
    static let extraSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
    static let pill: CGFloat = 999
}

enum AuraSize {
    static let iconSmall: CGFloat = 16
    static let iconMedium: CGFloat = 20
    static let iconStandard: CGFloat = 24
    static let iconLarge: CGFloat = 32
    static let iconExtraLarge: CGFloat = 48
    static let buttonMedium: CGFloat = 44
    static let buttonLarge: CGFloat = 52
    static let minimumTouchTarget: CGFloat = 44
    static let cardMinimumWidth: CGFloat = 145
    static let cardMinimumHeight: CGFloat = 140
    static let heroMinimumHeight: CGFloat = 220
    static let bannerIconFrame: CGFloat = 36
    static let statusDot: CGFloat = 8
    static let border: CGFloat = 1
    static let loadingLineLarge: CGFloat = 120
    static let loadingLineSmall: CGFloat = 72
    static let loadingLineHeight: CGFloat = 12
}

enum AuraOpacity {
    static let disabled = 0.4
    static let secondary = 0.7
    static let loading = 0.6
    static let pressed = 0.85
    static let subtle = 0.2
    static let faint = 0.12
    static let shadow = 0.12
}

enum AuraScale {
    static let pressed = 0.97
}

enum AuraMotion {
    static let instant = Animation.easeInOut(duration: 0.10)
    static let fast = Animation.easeInOut(duration: 0.18)
    static let standard = Animation.easeInOut(duration: 0.28)
    static let slow = Animation.easeInOut(duration: 0.40)
    static let success = Animation.spring(response: 0.40, dampingFraction: 0.82)
}
