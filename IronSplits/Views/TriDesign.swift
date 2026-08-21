import SwiftUI

/// The app's colour system, in one place.
///
/// Ported from StatScout's Savant palette and re-keyed to open water, asphalt,
/// and sunrise. The structure is deliberately identical — canvas / surface /
/// ink / a percentile ramp — because the leaderboard and percentile views are
/// ports too, and a matching palette API is what let them come across without
/// being rewritten.
enum TriPalette {
    static let canvas       = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let surface      = Color.white
    static let surfaceAlt   = Color(red: 0.965, green: 0.968, blue: 0.975)
    static let surfaceSunk  = Color(red: 0.91, green: 0.92, blue: 0.93)
    static let hairline     = Color(red: 0.80, green: 0.81, blue: 0.83)
    static let divider      = Color(red: 0.87, green: 0.88, blue: 0.90)
    static let ink          = Color(red: 0.08, green: 0.10, blue: 0.13)
    static let inkSecondary = Color(red: 0.26, green: 0.29, blue: 0.33)
    static let inkTertiary  = Color(red: 0.44, green: 0.47, blue: 0.52)
    static let inkOnDark    = Color.white

    /// Deep open water. The app's structural colour: headers, nav bars, the
    /// finish-time hero.
    static let deep         = Color(red: 0.05, green: 0.15, blue: 0.27)
    /// Sunrise. Reserved for the accent that means "your best".
    static let sunrise      = Color(red: 0.93, green: 0.42, blue: 0.11)
    static let linkBlue     = Color(red: 0.00, green: 0.36, blue: 0.69)

    /// One colour per leg, used consistently in the split bar, the leaderboard
    /// tabs, and the race detail. Transitions are grey on purpose: they are the
    /// part of the race nobody trains, and the chart should read that way.
    static func color(for discipline: Discipline) -> Color {
        switch discipline {
        case .swim: return Color(red: 0.11, green: 0.51, blue: 0.72)
        case .bike: return Color(red: 0.17, green: 0.47, blue: 0.31)
        case .run: return Color(red: 0.85, green: 0.34, blue: 0.13)
        case .t1, .t2, .transitions: return Color(red: 0.55, green: 0.57, blue: 0.61)
        case .finish: return deep
        }
    }

    static let fast = Color(red: 0.85, green: 0.29, blue: 0.10)
    static let mid  = Color(red: 0.74, green: 0.75, blue: 0.78)
    static let slow = Color(red: 0.17, green: 0.38, blue: 0.66)
    static let positive = Color(red: 0.13, green: 0.52, blue: 0.29)
    static let negative = Color(red: 0.74, green: 0.16, blue: 0.16)

    /// Fill colour for a percentile bar, 0 (slow) to 100 (fast).
    static func color(forPercentile p: Int) -> Color {
        let t = max(0.0, min(1.0, Double(p) / 100.0))
        return t < 0.5 ? lerp(slowRGB, midRGB, t * 2.0) : lerp(midRGB, fastRGB, (t - 0.5) * 2.0)
    }

    /// Percentile colour for *text* on a light surface.
    ///
    /// The fill ramp passes through a pale grey at the 50th percentile, which
    /// is right for a bar sitting on white and unreadable as type: a
    /// mid-of-the-pack number would come out the same value as the background.
    /// The endpoints stay recognisably the same orange and blue; only the
    /// middle is pulled down to a dark neutral.
    static func textColor(forPercentile p: Int) -> Color {
        let t = max(0.0, min(1.0, Double(p) / 100.0))
        return t < 0.5 ? lerp(slowTextRGB, midTextRGB, t * 2.0) : lerp(midTextRGB, fastTextRGB, (t - 0.5) * 2.0)
    }

    private static let fastRGB: (Double, Double, Double) = (0.85, 0.29, 0.10)
    private static let midRGB: (Double, Double, Double) = (0.74, 0.75, 0.78)
    private static let slowRGB: (Double, Double, Double) = (0.17, 0.38, 0.66)

    private static let fastTextRGB: (Double, Double, Double) = (0.72, 0.24, 0.07)
    private static let midTextRGB: (Double, Double, Double) = (0.27, 0.29, 0.33)
    private static let slowTextRGB: (Double, Double, Double) = (0.12, 0.30, 0.60)

    private static func lerp(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
        Color(red: a.0 + (b.0 - a.0) * t,
              green: a.1 + (b.1 - a.1) * t,
              blue: a.2 + (b.2 - a.2) * t)
    }
}

/// Type scale.
///
/// StatScout ships a bundled RobotoCondensed family; this app uses the system
/// face instead, because every screen here is a table of times and
/// `.monospacedDigit()` on SF is what keeps those columns aligned. Nothing else
/// in the layout needed the condensed width.
enum TriType {
    static let athleteName   = Font.system(size: 28, weight: .bold, design: .default)
    static let pageTitle     = Font.system(size: 22, weight: .bold)
    static let sectionTitle  = Font.system(size: 13, weight: .heavy)
    static let cardTitle     = Font.system(size: 16, weight: .semibold)
    static let body          = Font.system(size: 15, weight: .regular)
    static let bodyBold      = Font.system(size: 15, weight: .medium)
    static let small         = Font.system(size: 13, weight: .regular)
    static let smallBold     = Font.system(size: 13, weight: .medium)
    static let micro         = Font.system(size: 11, weight: .heavy)
    static let statHero      = Font.system(size: 40, weight: .bold).monospacedDigit()
    static let statLarge     = Font.system(size: 22, weight: .bold).monospacedDigit()
    static let statMed       = Font.system(size: 16, weight: .semibold).monospacedDigit()
    static let statSmall     = Font.system(size: 13, weight: .medium).monospacedDigit()
}

enum TriGeo {
    static let radiusCard: CGFloat = 12
    static let radiusBadge: CGFloat = 4
    static let hairline: CGFloat = 0.5
    static let barTrack: CGFloat = 6
    static let padInline: CGFloat = 12
    static let padCard: CGFloat = 16
    static let padPage: CGFloat = 16
    static let padSection: CGFloat = 24
    static let rowHeight: CGFloat = 44
}

/// Dark nav bar with white title, applied to every stack in the app.
struct TriNavBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(TriPalette.deep, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func triNavBar() -> some View { modifier(TriNavBar()) }

    /// The standard card: white surface, hairline border, soft radius.
    func triCard(padding: CGFloat = TriGeo.padCard) -> some View {
        self
            .padding(padding)
            .background(TriPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                    .stroke(TriPalette.hairline, lineWidth: TriGeo.hairline)
            )
    }
}

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
            Spacer()
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
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(filled ? color : color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusBadge, style: .continuous))
    }
}
