import SwiftUI
import UIKit

// MARK: - Scheme-aware colour

/// A colour that resolves differently in light and dark.
///
/// Every token below is built through this, which is the whole reason the app
/// stopped being a light-mode app wearing a dark navigation bar. The rule is
/// that no view ever names a literal colour: it names a token, and the token
/// decides. `UIColor(dynamicProvider:)` is what makes the decision late enough
/// that it also holds inside `UIKit`-backed surfaces (nav bars, share sheets,
/// `Form` rows) that SwiftUI's `@Environment(\.colorScheme)` never reaches.
private func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
    Color(uiColor: UIColor { traits in
        let c = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    })
}

/// The app's colour system, in one place.
///
/// Eight structural roles (canvas, surface, surfaceAlt, surfaceSunk, hairline,
/// ink, inkSecondary, inkTertiary) plus one brand pair (deep, sunrise) and the
/// three status colours. Nothing else. If a screen needs a colour that is not
/// on this list, the answer is a token, not a hex.
enum TriPalette {

    // MARK: Structure

    static let canvas       = adaptive(light: (0.949, 0.953, 0.961), dark: (0.043, 0.059, 0.078))
    static let surface      = adaptive(light: (1.000, 1.000, 1.000), dark: (0.086, 0.110, 0.141))
    static let surfaceAlt   = adaptive(light: (0.965, 0.968, 0.976), dark: (0.110, 0.137, 0.176))
    static let surfaceSunk  = adaptive(light: (0.906, 0.918, 0.933), dark: (0.055, 0.075, 0.098))
    static let hairline     = adaptive(light: (0.827, 0.839, 0.859), dark: (0.169, 0.204, 0.251))
    static let divider      = adaptive(light: (0.886, 0.898, 0.914), dark: (0.133, 0.165, 0.204))

    static let ink          = adaptive(light: (0.075, 0.098, 0.129), dark: (0.949, 0.961, 0.973))
    static let inkSecondary = adaptive(light: (0.259, 0.290, 0.333), dark: (0.678, 0.722, 0.769))
    static let inkTertiary  = adaptive(light: (0.439, 0.471, 0.522), dark: (0.482, 0.529, 0.588))
    /// Type that sits on `deep`, which is dark in both schemes.
    static let inkOnDark    = Color.white

    // MARK: Brand

    /// Deep open water. The app's structural colour: nav bars, the finish-time
    /// hero, selected chips. It lifts slightly in dark mode so a navy hero does
    /// not dissolve into a near-black canvas.
    static let deep    = adaptive(light: (0.051, 0.149, 0.271), dark: (0.071, 0.161, 0.259))
    /// Sunrise. The single accent, reserved for "your best" and for the one
    /// primary action on a screen.
    static let sunrise = adaptive(light: (0.910, 0.400, 0.086), dark: (1.000, 0.545, 0.239))

    // MARK: Status

    static let positive = adaptive(light: (0.129, 0.518, 0.290), dark: (0.302, 0.769, 0.475))
    static let negative = adaptive(light: (0.741, 0.161, 0.161), dark: (1.000, 0.412, 0.380))

    // MARK: Ramps

    /// One colour per leg, used consistently in the split bar, the leaderboards
    /// and the race detail. Transitions are grey on purpose: they are the part
    /// of the race nobody trains, and the chart should read that way.
    static func color(for discipline: Discipline) -> Color {
        switch discipline {
        case .swim:
            return adaptive(light: (0.110, 0.510, 0.720), dark: (0.278, 0.651, 0.867))
        case .bike:
            return adaptive(light: (0.169, 0.471, 0.310), dark: (0.322, 0.706, 0.471))
        case .run:
            return adaptive(light: (0.851, 0.341, 0.129), dark: (0.976, 0.510, 0.282))
        case .t1, .t2, .transitions:
            return adaptive(light: (0.549, 0.573, 0.612), dark: (0.478, 0.518, 0.573))
        case .finish:
            return deep
        }
    }

    private static let fastFill: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.851, 0.290, 0.098), (0.976, 0.451, 0.220))
    private static let midFill: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.741, 0.753, 0.780), (0.267, 0.310, 0.365))
    private static let slowFill: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.169, 0.380, 0.659), (0.325, 0.545, 0.847))

    private static let fastText: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.722, 0.239, 0.071), (0.988, 0.545, 0.322))
    private static let midText: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.267, 0.290, 0.333), (0.729, 0.769, 0.812))
    private static let slowText: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.118, 0.302, 0.600), (0.451, 0.651, 0.925))

    /// Fill colour for a percentile bar, 0 (slow) to 100 (fast).
    static func color(forPercentile p: Int) -> Color {
        ramp(p, fastFill, midFill, slowFill)
    }

    /// Percentile colour for *text*.
    ///
    /// The fill ramp passes through a mid neutral at the 50th percentile, which
    /// is right for a bar and unreadable as type: a mid-of-the-pack number would
    /// come out the same value as the surface behind it. The endpoints stay
    /// recognisably the same orange and blue; only the middle is pulled to a
    /// neutral with enough contrast against the current scheme.
    static func textColor(forPercentile p: Int) -> Color {
        ramp(p, fastText, midText, slowText)
    }

    /// Interpolates inside `UIColor`'s resolver so the ramp itself is
    /// scheme-aware rather than being mixed once at the light-mode endpoints.
    private static func ramp(_ p: Int,
                             _ fast: ((Double, Double, Double), (Double, Double, Double)),
                             _ mid: ((Double, Double, Double), (Double, Double, Double)),
                             _ slow: ((Double, Double, Double), (Double, Double, Double))) -> Color {
        let t = max(0.0, min(1.0, Double(p) / 100.0))
        return Color(uiColor: UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            let f = dark ? fast.1 : fast.0
            let m = dark ? mid.1 : mid.0
            let s = dark ? slow.1 : slow.0
            let c = t < 0.5 ? lerp(s, m, t * 2.0) : lerp(m, f, (t - 0.5) * 2.0)
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }

    private static func lerp(_ a: (Double, Double, Double),
                             _ b: (Double, Double, Double),
                             _ t: Double) -> (CGFloat, CGFloat, CGFloat) {
        (CGFloat(a.0 + (b.0 - a.0) * t),
         CGFloat(a.1 + (b.1 - a.1) * t),
         CGFloat(a.2 + (b.2 - a.2) * t))
    }
}

// MARK: - Type

/// The type scale: SF Pro, three weights, and every number tabular.
///
/// SF is the highest-trust face on iOS because it is the one the rest of the
/// phone is set in, so nothing here is bundled. The weights are `.regular` for
/// prose, `.semibold` for emphasis, and `.bold` for hero numbers only. Sizes
/// come off the same 4pt rhythm as the spacing scale.
///
/// Every numeric style is `.monospacedDigit()`. A finish time that reflows its
/// own columns as the seconds change is the cheapest possible tell, and this
/// screen is nothing but numeric columns.
enum TriType {
    static let athleteName   = Font.system(size: 28, weight: .bold)
    static let pageTitle     = Font.system(size: 22, weight: .bold)
    static let sectionTitle  = Font.system(size: 13, weight: .semibold)
    static let cardTitle     = Font.system(size: 17, weight: .semibold)
    static let body          = Font.system(size: 16, weight: .regular)
    static let bodyBold      = Font.system(size: 16, weight: .semibold)
    /// Text fields only. 17pt is what every native field on the phone uses, and
    /// anything smaller reads as a web form in a wrapper.
    static let field         = Font.system(size: 17, weight: .regular)
    static let small         = Font.system(size: 13, weight: .regular)
    static let smallBold     = Font.system(size: 13, weight: .semibold)
    static let micro         = Font.system(size: 11, weight: .semibold)

    static let statHero      = Font.system(size: 40, weight: .bold).monospacedDigit()
    static let statLarge     = Font.system(size: 22, weight: .bold).monospacedDigit()
    static let statMed       = Font.system(size: 16, weight: .semibold).monospacedDigit()
    static let statSmall     = Font.system(size: 13, weight: .semibold).monospacedDigit()
}

// MARK: - Space

/// One 4pt scale. Nothing in the app takes an arbitrary padding.
enum TriSpace {
    static let x1: CGFloat = 4
    static let x2: CGFloat = 8
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24
    static let x8: CGFloat = 32
    static let x10: CGFloat = 40
}

enum TriGeo {
    /// One radius for every surface, and one for the small things that sit
    /// inside a surface. Everything else is a capsule. Mixing sharp and round
    /// on one screen is the fastest cheap tell there is.
    static let radiusCard: CGFloat = 12
    static let radiusInner: CGFloat = 8
    static let radiusBadge: CGFloat = 8
    static let hairline: CGFloat = 0.5
    static let barTrack: CGFloat = 6

    static let padInline: CGFloat = TriSpace.x3
    static let padCard: CGFloat = TriSpace.x4
    static let padPage: CGFloat = TriSpace.x4
    static let padSection: CGFloat = TriSpace.x6

    /// Apple's floor for anything a thumb has to hit.
    static let tapTarget: CGFloat = 44
    static let rowHeight: CGFloat = 44
}

/// Two elevations: one for a card sitting on the canvas, one for something
/// floating over the whole screen. Shadows say how high a thing is, they are
/// not decoration, so there is no third.
enum TriShadow {
    static func card(_ scheme: ColorScheme) -> (Color, CGFloat, CGFloat) {
        scheme == .dark ? (.black.opacity(0.5), 10, 3) : (.black.opacity(0.07), 10, 3)
    }

    static func floating(_ scheme: ColorScheme) -> (Color, CGFloat, CGFloat) {
        scheme == .dark ? (.black.opacity(0.7), 28, 12) : (.black.opacity(0.22), 28, 12)
    }
}

// MARK: - Haptics

/// Feedback on actions that mean something.
///
/// A polished-looking interface that does not answer the thumb reads as broken,
/// and the fix costs one line at each call site. The rule is: `selection` for
/// changing a filter or a tab, `impact` for committing to something, `notify`
/// for an outcome the app is telling you about.
enum Haptics {
    private static let enabledKey = "settings.haptics.enabled"

    @MainActor private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false
    }

    @MainActor static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @MainActor static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    @MainActor static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// MARK: - Interaction

/// The app's one button style: everything interactive dips and dims on press.
struct TriPressStyle: ButtonStyle {
    var haptic: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && haptic { Haptics.tap() }
            }
    }
}

extension ButtonStyle where Self == TriPressStyle {
    static var triPress: TriPressStyle { TriPressStyle() }
    static var triPressSilent: TriPressStyle { TriPressStyle(haptic: false) }
}

// MARK: - Modifiers

/// Dark nav bar with white title, applied to every stack in the app.
struct TriNavBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(TriPalette.deep, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct TriCard: ViewModifier {
    let padding: CGFloat
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shadow = TriShadow.card(scheme)
        return content
            .padding(padding)
            .background(TriPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                    .stroke(TriPalette.hairline, lineWidth: TriGeo.hairline)
            )
            .shadow(color: shadow.0, radius: shadow.1, y: shadow.2)
    }
}

extension View {
    func triNavBar() -> some View { modifier(TriNavBar()) }

    /// The standard card: surface, hairline, one radius, one elevation.
    func triCard(padding: CGFloat = TriGeo.padCard) -> some View {
        modifier(TriCard(padding: padding))
    }

    /// Guarantees a thumb-sized hit area without changing how the thing looks.
    func triTapTarget(_ minimum: CGFloat = TriGeo.tapTarget) -> some View {
        frame(minWidth: minimum, minHeight: minimum)
            .contentShape(Rectangle())
    }
}

// MARK: - Primitives

/// Small uppercase label that heads a section.
struct TriSectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(TriType.sectionTitle)
                .kerning(0.8)
                .foregroundStyle(TriPalette.inkSecondary)
            Spacer(minLength: TriSpace.x2)
            if let trailing {
                Text(trailing)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
            }
        }
    }
}

/// Pill used for age group, race kind, PR, and DNF markers.
struct TriBadge: View {
    let text: String
    var color: Color = TriPalette.inkSecondary
    var filled: Bool = false

    var body: some View {
        Text(text.uppercased())
            .font(TriType.micro)
            .kerning(0.5)
            .foregroundStyle(filled ? Color.white : color)
            .padding(.horizontal, TriSpace.x2)
            .padding(.vertical, TriSpace.x1)
            .background(filled ? color : color.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusBadge, style: .continuous))
    }
}

/// The one filter pill shape, shared by every horizontal picker in the app.
///
/// It was three near-identical copies with three different heights before, none
/// of which cleared 44pt.
struct TriChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(TriType.smallBold)
                .foregroundStyle(isSelected ? Color.white : TriPalette.inkSecondary)
                .padding(.horizontal, TriSpace.x4)
                .frame(minHeight: TriGeo.tapTarget - TriSpace.x2)
                .background(isSelected ? TriPalette.deep : TriPalette.surface, in: Capsule())
                .overlay(
                    Capsule().stroke(TriPalette.hairline,
                                     lineWidth: isSelected ? 0 : TriGeo.hairline)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.triPressSilent)
    }
}

/// The single primary action shape, used on the one thing a screen wants you
/// to do.
struct TriPrimaryButton: View {
    let title: String
    var systemImage: String?
    var isBusy: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap(.medium)
            action()
        } label: {
            HStack(spacing: TriSpace.x2) {
                if isBusy {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(TriType.bodyBold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: TriGeo.tapTarget + TriSpace.x1)
            .background(TriPalette.sunrise)
            .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
        }
        .buttonStyle(.triPressSilent)
        .disabled(isBusy)
    }
}
