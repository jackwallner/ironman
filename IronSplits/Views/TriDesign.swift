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
    static let inkTertiary  = adaptive(light: (0.380, 0.410, 0.460), dark: (0.482, 0.529, 0.588))
    static let shadow       = adaptive(light: (0.000, 0.000, 0.000), dark: (0.000, 0.000, 0.000))
    /// Type that sits on `deep`, which is dark in both schemes.
    static let inkOnDark    = adaptive(light: (1.000, 1.000, 1.000), dark: (1.000, 1.000, 1.000))
    /// Foreground for the accent fill: white in light mode, dark ink on the
    /// brighter accent used in dark mode.
    static let inkOnSunrise = adaptive(light: (1.000, 1.000, 1.000), dark: (0.075, 0.098, 0.129))
    /// Deliberately black media stage, resolved through the same token path as
    /// every other full-screen surface.
    static let mediaCanvas  = adaptive(light: (0.000, 0.000, 0.000), dark: (0.000, 0.000, 0.000))
    /// The fill behind every control on the navy navigation bar. Fixed, not
    /// glass, so the white label on it reads the same on every device.
    static let chromeFill   = inkOnDark.opacity(0.18)

    /// A selected chip or segment. Navy in light mode; in dark mode navy sits
    /// too close to the dark surfaces around it, so selection flips to a light
    /// fill the way the system's own segmented controls do.
    static let selectedFill = adaptive(light: (0.020, 0.094, 0.208), dark: (0.902, 0.925, 0.949))
    static let inkOnSelected = adaptive(light: (1.000, 1.000, 1.000), dark: (0.043, 0.059, 0.078))

    // MARK: Brand

    /// Deep open water. The app's structural colour: nav bars, the finish-time
    /// hero, selected chips. It lifts slightly in dark mode so a navy hero does
    /// not dissolve into a near-black canvas.
    static let deep    = adaptive(light: (0.020, 0.094, 0.208), dark: (0.028, 0.125, 0.278))
    /// Finish markers need a lighter dark-mode blue than the structural navy
    /// so the checkered flag remains legible on a dark card.
    static let finish  = adaptive(light: (0.122, 0.396, 0.729), dark: (0.278, 0.627, 0.969))
    /// The single accent, reserved for "your best" and for the one primary
    /// action on a screen. It carries the runner red from the app icon.
    static let sunrise = adaptive(light: (0.780, 0.200, 0.165), dark: (0.965, 0.365, 0.310))

    // MARK: Status

    static let positive = adaptive(light: (0.160, 0.440, 0.170), dark: (0.467, 0.820, 0.235))
    static let negative = adaptive(light: (0.741, 0.161, 0.161), dark: (1.000, 0.412, 0.380))

    // MARK: Ramps

    /// One colour per leg, used consistently in the split bar, the leaderboards
    /// and the race detail. Transitions are grey on purpose: they are the part
    /// of the race nobody trains, and the chart should read that way.
    static func color(for discipline: Discipline) -> Color {
        switch discipline {
        case .swim:
            return adaptive(light: (0.122, 0.396, 0.729), dark: (0.278, 0.627, 0.969))
        case .bike:
            return adaptive(light: (0.361, 0.706, 0.145), dark: (0.510, 0.839, 0.235))
        case .run:
            return adaptive(light: (0.780, 0.200, 0.165), dark: (0.965, 0.365, 0.310))
        case .t1, .t2, .transitions:
            return adaptive(light: (0.549, 0.573, 0.612), dark: (0.478, 0.518, 0.573))
        case .finish:
            return finish
        }
    }

    private static let fastFill: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.780, 0.200, 0.165), (0.965, 0.365, 0.310))
    private static let midFill: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.741, 0.753, 0.780), (0.267, 0.310, 0.365))
    private static let slowFill: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.122, 0.396, 0.729), (0.278, 0.627, 0.969))

    private static let fastText: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.620, 0.122, 0.098), (0.965, 0.365, 0.310))
    private static let midText: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.267, 0.290, 0.333), (0.729, 0.769, 0.812))
    private static let slowText: ((Double, Double, Double), (Double, Double, Double)) =
        ((0.086, 0.282, 0.600), (0.451, 0.651, 0.925))

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
    static let athleteName   = Font.system(.title, design: .default).weight(.bold)
    static let pageTitle     = Font.system(.title2, design: .default).weight(.bold)
    static let sectionTitle  = Font.system(.footnote, design: .default).weight(.semibold)
    static let cardTitle     = Font.system(.headline, design: .default).weight(.semibold)
    static let body          = Font.system(.body, design: .default)
    static let bodyBold      = Font.system(.body, design: .default).weight(.semibold)
    /// Text fields only. 17pt is what every native field on the phone uses, and
    /// anything smaller reads as a web form in a wrapper.
    static let field         = Font.system(.body, design: .default)
    static let small         = Font.system(.footnote, design: .default)
    static let smallBold     = Font.system(.footnote, design: .default).weight(.semibold)
    static let micro         = Font.system(.caption2, design: .default).weight(.semibold)

    static let statHero      = Font.system(.largeTitle, design: .default).weight(.bold).monospacedDigit()
    static let statLarge     = Font.system(.title2, design: .default).weight(.bold).monospacedDigit()
    static let statMed       = Font.system(.body, design: .default).weight(.semibold).monospacedDigit()
    static let statSmall     = Font.system(.footnote, design: .default).weight(.semibold).monospacedDigit()
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
        scheme == .dark ? (TriPalette.shadow.opacity(0.5), 10, 3) : (TriPalette.shadow.opacity(0.07), 10, 3)
    }

    static func floating(_ scheme: ColorScheme) -> (Color, CGFloat, CGFloat) {
        scheme == .dark ? (TriPalette.shadow.opacity(0.7), 28, 12) : (TriPalette.shadow.opacity(0.22), 28, 12)
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
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
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
///
/// A pushed screen passes `pushed: true` and gets `TriBackButton` in place of
/// the system one, whose glass circle has the same light-or-dark lottery as
/// every other toolbar item (white chevron on pale glass in light mode). The
/// edge swipe survives because `UINavigationController` keeps its pop gesture
/// below.
struct TriNavBar: ViewModifier {
    var pushed = false

    func body(content: Content) -> some View {
        let bar = content
            .toolbarBackground(TriPalette.deep, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        if pushed {
            bar
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    TriBarItem(placement: .topBarLeading) { TriBackButton() }
                }
        } else {
            bar
        }
    }
}

/// Hiding the system back button also disables the edge swipe to go back. This
/// keeps it for any stack deeper than its root, so `TriNavBar(pushed:)` screens
/// still swipe back like every other iOS screen.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer !== interactivePopGestureRecognizer || viewControllers.count > 1
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
    func triNavBar(pushed: Bool = false) -> some View { modifier(TriNavBar(pushed: pushed)) }

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

struct TriBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            TriBarLabel(systemImage: "chevron.left")
        }
        .buttonStyle(.triPressSilent)
        .accessibilityLabel("Back")
    }
}

// MARK: - Navigation bar chrome

/// The label for any action on the navy navigation bar: white type or symbol on
/// a fixed `chromeFill` capsule (a circle when it is icon-only).
///
/// iOS 26 wraps toolbar items in Liquid Glass, and whether that glass comes out
/// light or dark depends on what the system samples under it, not on the bar's
/// colour scheme. It rendered light on the simulator and dark on Pattie's
/// iPhone, so the old Change button, which guessed "light glass, navy text",
/// was navy on navy on a real phone. Every bar control now opts out of the
/// system glass through `TriBarItem` and draws this instead, so nothing on the
/// bar depends on a guess. `ChromeLegibilityUITests` measures the result.
struct TriBarLabel: View {
    var title: String?
    var systemImage: String?
    var emphasized = false

    var body: some View {
        HStack(spacing: TriSpace.x1) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
            }
            if let title {
                Text(title)
                    .font(emphasized ? TriType.bodyBold : TriType.body)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .foregroundStyle(TriPalette.inkOnDark)
        .padding(.horizontal, title == nil ? 0 : TriSpace.x4)
        .frame(minWidth: TriGeo.tapTarget, minHeight: TriGeo.tapTarget)
        // Sheet bars propose a 44pt slot to cancel/confirm items, which
        // squeezed "Cancel" out past its own capsule.
        .fixedSize()
        .background(TriPalette.chromeFill, in: Capsule())
        .contentShape(Capsule())
    }
}

/// A toolbar item with the system glass switched off on iOS 26, for content
/// that draws its own `TriBarLabel`.
struct TriBarItem<Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement
    @ViewBuilder let content: () -> Content

    init(placement: ToolbarItemPlacement, @ViewBuilder content: @escaping () -> Content) {
        self.placement = placement
        self.content = content
    }

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: placement, content: content)
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement, content: content)
        }
    }
}

/// A two-or-more option switch for the navigation bar, used where a system
/// segmented control would otherwise pick up the unpredictable glass.
struct TriBarSegments<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(TriType.smallBold)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(isSelected ? TriPalette.deep : TriPalette.inkOnDark)
                        .padding(.horizontal, TriSpace.x4)
                        .frame(minHeight: TriGeo.tapTarget - TriSpace.x2)
                        .background(isSelected ? TriPalette.inkOnDark : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.triPressSilent)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(TriSpace.x1)
        .background(TriPalette.chromeFill, in: Capsule())
        .animation(.easeOut(duration: 0.18), value: selection)
    }
}

// MARK: - Primitives

/// Small uppercase label that heads a section.
struct TriSectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: TriSpace.x2) {
                heading
                Spacer(minLength: TriSpace.x2)
                trailingLabel
            }
            VStack(alignment: .leading, spacing: TriSpace.x1) {
                heading
                trailingLabel
            }
        }
    }

    private var heading: some View {
        Text(title.uppercased())
            .font(TriType.sectionTitle)
            .kerning(0.8)
            .foregroundStyle(TriPalette.inkSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .allowsTightening(true)
    }

    @ViewBuilder
    private var trailingLabel: some View {
        if let trailing {
            Text(trailing)
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
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
            .foregroundStyle(filled ? TriPalette.inkOnSunrise : color)
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
                .foregroundStyle(isSelected ? TriPalette.inkOnSelected : TriPalette.inkSecondary)
                .padding(.horizontal, TriSpace.x4)
                .frame(minHeight: TriGeo.tapTarget)
                .background(isSelected ? TriPalette.selectedFill : TriPalette.surface, in: Capsule())
                .overlay(
                    Capsule().stroke(TriPalette.hairline,
                                     lineWidth: isSelected ? 0 : TriGeo.hairline)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.triPressSilent)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "")
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
                    ProgressView().tint(TriPalette.inkOnDark)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(TriType.bodyBold)
            }
            .foregroundStyle(TriPalette.inkOnSunrise)
            .frame(maxWidth: .infinity, minHeight: TriGeo.tapTarget + TriSpace.x1)
            .padding(.vertical, TriSpace.x2)
            .background(TriPalette.sunrise)
            .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
        }
        .buttonStyle(.triPressSilent)
        .disabled(isBusy)
    }
}
